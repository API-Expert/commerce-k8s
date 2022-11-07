# Commerce 

Commerce é um ambiente para estudar ferramentas de infraestrutura como API Gateway e Service Mesh

## Preparando o ambiente

1. Instale as ferramentas

    Ferramenta|URL
    -|-
    Postman|https://www.postman.com/
    kubectl|https://kubernetes.io/docs/tasks/tools/
    minikube|https://minikube.sigs.k8s.io/docs/start/
    Docker|https://docs.docker.com/engine/install/


2. Instale o certificado ```tls/localhost-ca.pem``` no Postman ou ```tls/localhost-ca.key``` no computador local.

3. Execute o script ```create-environment.sh``` para criar o ambiente.
```sh
./create-environment.sh
```

Para Windows:
```powershell
./create-environment.ps1
```

> A instalação leva aproximadamente 5 minutos

4. Execute o script ```port-forward.sh``` para criar uma ligação entre a porta local e a porta do serviço no _cluster_ ```kubernetes```.

    Saída:
    ```sh
    kuma-control-plane - 5681
    kong-proxy - 8443
    jaeger-query - 8080
    grafana - 3000
    ```
    Para Windows:
    ```powershell
    ./port-forward.ps1
    ```

5. Selecione o contexto ```commerce``` para o ```kubectl```:

    ``` sh
    kubectl config use-context commerce
    ```

    ```
    Switched to context "commerce".
    ```

# API Gateway

## Observabilidade
Com a observabilidade configurada será possível verificar o resultado das requisições feitas e analisar o comportamento do API Gateway. O comando abaixo irá configurar os plugins de _tracing, logging_ e _metrics_.
```sh
kubectl apply -f k8s/kong/global-plugins/observability
```

## Configuração do TLS e das rotas
A criação das rotas irá permitir que as requisições sejam roteadas para os serviços de acordo com o ```path```. A configura do TLS fará com que a conexão com o ```gateway``` esteja segura por um certificado.

```sh
kubectl apply -f k8s/kong/global-plugins/security/tls.yaml
kubectl apply -f k8s/kong/traffic/routes.yaml 
```

> Utilizando a coleção do Postman faça alguns testes e veja se os serviços estão retornando resultado.

## Ativação de API Key
A ativação do ```plugin``` global KeyAuth fará com que todas as requisições necessitem de uma API Key como fator de autenticação

```sh
kubectl apply -f k8s/kong/global-plugins/security/key-auth.yaml
```

```json
{
    "message": "Invalid authentication credentials"
}
```

> Faça algumas chamadas e veja que agora o acesso está sendo negado pelo API Gateway.

## Crie os consumidores e as chaves

Para acessar o API Gateway será necessário criar ```consumers```e chaves (API Key) que servirão para autenticar as chamadas ao API Gateway. Crie os consumidores e suas chaves executando o comando abaixo:

```sh
kubectl apply -f k8s/kong/security/consumers-key-auth.yaml
```

> Utilizando a coleção do Postman será possível notar que as chamadas agora são permitidas. Observe também que independente da chave, todas as rotas estão acessíveis, gerando problemas de segurança. Isso será corrigido com o controle de acesso. No Postman, utilize a requisição ```commerce/products/products incorrect apikey``` e veja que ela funcionará. 

## Crie o controle de acesso (autorização)

O controle de acesso vai garantir que somente ```consumers``` que tem permissão a tais recursos possam fazer a requisição. O comando abaixo criará o controle de acesso.

```sh
kubectl apply -f k8s/kong/security/consumers-acl.yaml
```

### Atribua o controle de acesso aos consumidores e as rotas
Com o controle de acesso criado, é necessário atribuí-lo aos consumidores:

```sh
kubectl patch KongConsumer pricing -n commerce --type=json -p="[{'op': 'add', 'path': '/credentials/-', 'value':'pricing-credential-acl'}]"
kubectl patch KongConsumer marketing -n commerce --type=json -p="[{'op': 'add', 'path': '/credentials/-', 'value':'marketing-credential-acl'}]"
kubectl patch KongConsumer external -n commerce --type=json -p="[{'op': 'add', 'path': '/credentials/-', 'value':'external-credential-acl'}]"
kubectl patch KongConsumer external-canary -n commerce --type=json -p="[{'op': 'add', 'path': '/credentials/-', 'value':'external-credential-canary-acl'}]"
```
Em seguida é necessário configurar as rotas quais os grupos estão autorizados a utilizá-las:
```sh
kubectl -n commerce annotate ingress catalog-default-route  konghq.com/plugins=external-acl
kubectl -n commerce annotate ingress products-default-route  konghq.com/plugins=marketing-acl
kubectl -n commerce annotate ingress pricing-default-route  konghq.com/plugins=pricing-acl
```

> Tente fazer chamadas invertendo os usuário e veja que o API Gateway irá negar a chamada.


> Tente usar utilizar novamente a requisição ```commerce/products/products incorrect apikey``` e veja que não será mais possível.

```json
{
    "message": "You cannot consume this service"
}
```

## Bot Detection
O controle de detecção de _bot_ irá bloquear chamadas de acordo com o User Agent informado no ```header``` da requisição. 

```sh
kubectl apply -f k8s/kong/global-plugins/security/bot-detection.yaml
```
Faça alguns testes e veja que a detecção de _bot_ está bloqueando o Postman.

```json
{
    "message": "Forbidden"
}
```

Remova a detecção de _bot_ para não atrapalhar os próximos testes.

```sh
kubectl delete -f k8s/kong/global-plugins/security/bot-detection.yaml
```

> Veja as regras da detecção de bot em https://docs.konghq.com/hub/kong-inc/bot-detection/#:~:text=https%3A//github.com/Kong/kong/blob/master/kong/plugins/bot%2Ddetection/rules.lua


## IP Restriction

A restrição por IP pode ser usado para permitir ou bloquear IPs válidos para as requisições:
```sh
kubectl apply -f k8s/kong/global-plugins/security/ip-restriction.yml
```

Faça alguns testes e sua requisição será bloqueada:
```json
{
    "message": "Your IP address is not allowed"
}
```
Desabilite para não atrapalhar os próximos testes

```sh
kubectl delete -f k8s/kong/global-plugins/security/ip-restriction.yml
```

## Throttling (Rate Limiting)
O _throttling_ irá controlar a quantidade máxima de requisições por período de tempo.
Configure o rate limiting para o consumidor ```marketing```.
```sh
kubectl apply -f k8s/kong/traffic/throttling.yaml
kubectl -n commerce annotate KongConsumer marketing konghq.com/plugins=rate-limiting-plugin  --overwrite=true
```
Faça alguns testes com as requisições da pasta ```products``` e verifique os ```headers``` de retorno, eles mostrarão as informações referente ao _throttiling_.

Headers
```
RateLimit-Remaining 
RateLimit-Reset
X-RateLimit-Limit-Minute
X-RateLimit-Remaining-Minute
RateLimit-Limit
```

Desabilite se achar necessário:

```sh
kubectl -n commerce annotate KongConsumer marketing konghq.com/plugins=  --overwrite=true
kubectl delete -f k8s/kong/traffic/throttling.yaml
```


## Cache
O cache vai permitir que as respostas as requisições sejam armazenadas no API Gateway por um período de tempo. Habilte o cache para o ```catalog```.

```sh
kubectl apply -f k8s/kong/traffic/caching.yaml
kubectl -n commerce annotate svc/catalog-api konghq.com/plugins=catalog-cache-plugin --overwrite=true
```

Faça alguns testes com as requisições da pasta ```catalog``` e verifique os ```headers``` de _cache_.

Headers
```
X-Cache-Key
X-Cache-Status
```
Desabilite se achar necessário.

```
kubectl -n commerce annotate svc/catalog-api konghq.com/plugins= --overwrite=true
kubectl delete -f k8s/kong/traffic/caching.yaml
```


## Gerando massa de requisições
Utilize o _script_ ```test-catalog-through-kong.sh``` para executar diversas chamadas para massa de dados.
```sh
./test-catalog-through-kong.sh 
```

## Observabilidade - Análise
Adicione o _dashboards_ de análise do Kong ao Grafana:

**Kong Official Dashboard (7424)** - https://grafana.com/grafana/dashboards/7424

Adicione o ```data source``` do ElasticSearch para o endereço
```
http://elasticsearch.elasticsearch.svc:9200
```

Importe o _dashboard_ ```grafana/kong-logs.json``` ao Grafana.

Visualize os dados nos _dashboards_ importados.

Visualize os dados de _tracing_ no Jaeger.

# Service Mesh

## Configuração rápida do API Gateway

Caso você tenha perdido o ambiente, você poderá utilizar os comandos abaixo para ter o básico do API Gateway para executar o Service Mesh

```sh
kubectl apply -f k8s/kong/global-plugins/observability
kubectl apply -f k8s/kong/global-plugins/security/tls.yaml
kubectl apply -f k8s/kong/traffic/routes.yaml 
kubectl apply -f k8s/kong/global-plugins/security/key-auth.yaml
kubectl apply -f k8s/kong/security/consumers-key-auth.yaml
kubectl apply -f k8s/kong/security/consumers-acl.yaml
```

## Ativando o service mesh no namespace
Para que o _service mesh_ seja instalado na aplicação é necessário que o namespace receba uma  ```annotation``` para identificar que os ```pods``` farão parte do _service mesh_, assim como uma ```annotation``` nos serviços.

```sh
kubectl annotate namespace commerce kuma.io/sidecar-injection=enabled --overwrite=true
kubectl annotate service catalog-api -n commerce ingress.kubernetes.io/service-upstream=true --overwrite=true
kubectl annotate service products-api -n commerce ingress.kubernetes.io/service-upstream=true --overwrite=true
kubectl annotate service pricing-api -n commerce ingress.kubernetes.io/service-upstream=true --overwrite=true

    
```

E para completar a ativação os ```pods``` precisam ser recriados.
```sh
kubectl rollout restart deploy -n commerce
```

Observe que agora os ```pods``` possuem 2 ```containers```:

```
kubectl get pods -n commerce
```

```sh
NAME                            READY   STATUS    RESTARTS   AGE
catalogapi-v1-75b586795-rhbjn   2/2     Running   0          46s
pricingapi-6d9d45d84b-kmm7r     2/2     Running   0          46s
productsapi-76f487bf4d-56gz2    2/2     Running   0          46s
```

> Acesse a interface do _service mesh_ para visualizar as configurações: http://localhost:5681/gui/

## Ativando as rotas 

Antes de trabalhar com o roteamento é necessário ativar a versão 2 e 3 do ```catalog```.

```sh
kubectl scale deploy catalogapi-v2 --replicas=1 -n commerce 
kubectl scale deploy catalogapi-v3 --replicas=1 -n commerce 
```

Além disso, desabilite o cache do API Gateway para não atrapalhar a visualização dos resultados:

```sh
kubectl -n commerce annotate svc/catalog-api konghq.com/plugins= --overwrite=true
kubectl delete -f k8s/kong/traffic/caching.yaml
```

Para ativar as rotas no ```service mesh``` execute o comando abaixo:
```sh
kubectl apply -f k8s/kuma/routing/basic-traffic-route.yaml
```

Com as rotas ativadas no ```service mesh``` agora é possível acessar os serviços, faça algumas requisições utilizando o Postman.

## Roteando pelo header
Se o usuário passar o header ```version```  automaticamente o _service mesh_ irá redirecionar para versão v1 ou v2 do ```catalog```.

```sh
kubectl apply -f k8s/kuma/routing/catalog-route-to-specific-version.yaml
```

Utilize a requisição ```items (specific version)``` da pasta ```catalog``` do Postman e execute as chamadas para v1, v2 e sem header. Observe os resultados

## Retry

Ative novamente o roteamento básico e repare que 1 a cada 3 requisições falha.

```sh
kubectl apply -f k8s/kuma/routing/basic-traffic-route.yaml
```

Erro de status 500 e mensagem 

```
version has not been configured
```

Ative a política de ```retry``` e teste novamente:

```sh
kubectl apply -f k8s/kuma/resilience/retry.yaml
```

Desabilite para visualizar melhor os resultados da próxima configuração:

```sh
kubectl delete -f k8s/kuma/resilience/retry.yaml
```


## Circuit Breaker

Ative o circuit breaker:

```sh
kubectl apply -f k8s/kuma/resilience/circuit-breaker.yaml
```

Execute algumas chamadas e observe que após o primeiro erro, a versão v3 é retirada do ar por 10 segundos e depois este tempo vai aumentando.


## Timeout

Antes de continuar remova o ```rate-limit``` do Kong para visualizar melhor os resultados:

```sh
kubectl -n commerce annotate KongConsumer marketing konghq.com/plugins=  --overwrite=true
kubectl delete -f k8s/kong/traffic/throttling.yaml
```


O timeout é responsável por encerrar a conexão caso o tempo configurado seja antigido:

```sh
kubectl apply -f k8s/kuma/catalog-timeout.yaml
```

Faça algumas requisições a ```catalog``` e veja que agora está ocorrendo erro de código de status 504.


Remova o ```timeout```para não prejudicar os próximos testes

```sh
kubectl delete -f k8s/kuma/catalog-timeout.yaml
```

## Fault Injection
Antes de ativar a injeção de falhas, remova os ```pods``` da versão v3 para que as únicas falhas que ocorram sejam por injeção. Além disso, remova o ```timeout``` e o ```circuitbreaker```:

```sh
kubectl scale deploy catalogapi-v3 --replicas=0 -n commerce 
kubectl delete -f k8s/kuma/catalog-timeout.yaml
kubectl delete -f k8s/kuma/resilience/circuit-breaker.yaml
```

> Certifique-se de que o ```timeout``` tenha sido removido para não dificultar a visualização dos resultados.

Ative a injeção de falhas:
```sh
kubectl apply -f k8s/kuma/fault-injection/fault-injection.yaml
```

Faça algumas requisições em ```catalog```, ou ```POST``` em ```products``` ou ```pricing``` e repare que alguns não são concluídos com sucesso e outros demoram até 5 segundos para completar a requisição.

Remova a injeção de falhas para não prejudicar os próximos passos:

```sh
kubectl delete -f k8s/kuma/fault-injection/fault-injection.yaml
```

# Throttling

Ative o ```rate-limit``` para o serviço ```pricing```.

```sh
kubectl apply -f k8s/kuma/pricing-ratelimit.yaml 
```

Faça algumas requisições  ao serviço ```pricing```e repare que após 3 requisições dentro de 1 minuto, o _service mesh_ retorna o status 429.


Remova para não atrapalhar os próximos exemplos:

```sh
kubectl delete -f k8s/kuma/pricing-ratelimit.yaml 
```

## Load Balance
Faça um balanceamento de carga das requisições entre a versão v1 e v2:

```sh
kubectl apply -f k8s/kuma/routing/load-balance.yaml
```

Usando a requisição ```items (balancing)``` da coleção ```catalog``` do Postman, faça requisições:
* Sem o ```header stable:yes``` e sem o ```header canary:yes``` e observe o ```header version```no _response_.
* Somente com um dos _headers_.
* Com os dois _headers_.

## Observabilidade e segurança
Visite a página do _dashboard_ do _service mesh_ e veja as configurações já aplicadas através do arquivo ```k8s/kuma/mesh.yaml```.

http://localhost:5681/gui/#/meshes/all

## TLS Mútuo
Cria um certificado de comunicação entre o serviços. (Ativado no passo anterior)

## Autorização
O _service mesh_ foi instalado de forma permissiva, ou seja, todo o tráfego é permitido a todos os serviços. 

Remova a autorização padrão:

```sh
kubectl delete  trafficpermission allow-all-default    
```

Tente fazer as requisições e veja que não é mais possível o retorno agora é 503 e o corpo da requisição: 

```
upstream connect error or disconnect/reset before headers. reset reason: connection termination
```

Ative as permissões de comunicação aos serviços:

```sh
kubectl apply -f k8s/kuma/traffic-permissions.yaml
```

Tente novamente fazer as requisições.

## Logging

Os _logs_ são ativados em duas etapas: No ```mesh``` ficam as configurações de destino dos logs (veja [mesh.yaml](k8s/kuma/mesh.yaml))

Para ativar o _log_ por tráfego, execute:

```sh
kubectl apply -f k8s/kuma/traffic-log.yaml 
```

Execute algumas requisições e visualizar o _dashboard_ no ```Grafana``` (http://localhost:3000)

## Tracing
O _tracing_ é ativado em duas etapas: No ```mesh``` ficam as configurações de destino do tracing (veja [mesh.yaml](k8s/kuma/mesh.yaml))

Para ativar o _tracing_ por tráfego, execute:

```sh
kubectl apply -f k8s/kuma/traffic-trace.yaml 
```

Execute algumas requisições e visualizar o _tracing_ no ```Jaeger``` (http://localhost:8080)