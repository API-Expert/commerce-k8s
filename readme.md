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
Adicione o ```data source``` do ElasticSearch para o endereço
```
http://elasticsearch.elasticsearch.svc:9200
```

Importe os _dashboards_ ```grafana/kong-logs.json``` e ```grafana/kong-metrics.json``` ao Grafana.

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

Faça algumas requisições a ```catalog``` e veja que agora está ocorrendo erro de código de status 504. Verifique os ```headers X-Kong-Upstream-Latency``` e ```X-Kong-Proxy-Latency```, veja que é possível identificar o tempo em que a requisição levou do lado do _upstream_.


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

## Throttling

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

Ative as versões ```v2``` e ```v3```, 
```sh
kubectl scale deploy catalogapi-v2 --replicas=1 -n commerce 
kubectl scale deploy catalogapi-v3 --replicas=1 -n commerce 
```

```sh
kubectl apply -f k8s/kuma/routing/load-balance.yaml
```



Usando a requisição ```items (balancing)``` da coleção ```catalog``` do Postman, faça requisições:
* Sem o ```header stable:yes``` e sem o ```header canary:yes``` e observe o ```header version```no _response_.
* Somente com um dos _headers_.
* Com os dois _headers_.

## Virtual Outbound
É possível criar _hostnames_ customizados para os serviços através do _service mesh_

Ative as rotas básicas
```sh
kubectl apply -f k8s/kuma/routing/basic-traffic-route.yaml 
```

Execute o comando abaixo para criar um _hostname_ ```catalogapi-version``` e alterar o endereço de chamada do ```catalog``` do serviço ```pricing```:


```sh
kubectl apply -f k8s/kuma/virtual-outbound-catalog.yaml
```

Faça o _rollout_ dos ```pods``` para aplicar a nova configuração:

```sh
kubectl rollout restart deploy pricingapi -n commerce
```

Faça chamadas de ```POST``` a API de ```pricing``` e veja que funciona normalmente.

### Alguns testes
- Ative as versões ```v2``` e ```v3```, 
  ```sh
  kubectl scale deploy catalogapi-v2 --replicas=1 -n commerce 
  kubectl scale deploy catalogapi-v3 --replicas=1 -n commerce 
  ```

- Troque a versão de chamada de ```pricing```:
  ```sh
  kubectl edit configmap pricing-api -n commerce  
  ```
- Faça o _rollout_ de ```pricing``` 
  ```sh
  kubectl rollout restart deploy pricingapi -n commerce
  ```
- Faça chamadas e observe o comportamento

## Healthcheck

O _health check_ verifica se a aplicação está respondendo em um intervalo predefinido:

```sh
 kubectl apply -f k8s/kuma/health-check-catalog.yaml
```

É possível verificar os _logs_ de _health check_ com o comando:

```sh
kubectl logs -l app=catalogapi -n commerce -c kuma-sidecar -f
```

Caso o _health check_ identifique que a aplicação está ```unhealthy``` ele automaticamente pára de enviar enviar requisições.

Nos dashboards, verifique a disponibilidade do ```catalog```.

## External Services
Permite identificar os serviços acessados fora do _mesh_

```sh
kubectl apply -f k8s/kuma/external-service.yaml
```

## Observabilidade e segurança
Visite a página do _dashboard_ do _service mesh_ e veja as configurações já aplicadas através do arquivo ```k8s/kuma/mesh.yaml```.

http://localhost:5681/gui/#/meshes/all



## TLS Mútuo
Cria um certificado de comunicação entre o serviços. (Ativado no passo anterior)

## Passthrough
O modo passthrough quando ativado, bloqueia por padrão todas as saídas do mesh. Desta forma, todo o tráfego precisa ser identificado por ```trafficpermission``` e ```trafficroute```.

> Veja configuração do _mesh_.

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

# Configuration Manager

## Preparando o ambiente

Utilize os comandos abaixo para configurar o _service mesh_ e o _api gateway_.

```sh
kubectl apply -f k8s/kong/global-plugins/observability
kubectl apply -f k8s/kong/global-plugins/security/tls.yaml
kubectl apply -f k8s/kong/traffic/routes.yaml 
kubectl apply -f k8s/kong/global-plugins/security/key-auth.yaml
kubectl apply -f k8s/kong/security/consumers-key-auth.yaml
kubectl apply -f k8s/kong/security/consumers-acl.yaml
kubectl annotate namespace commerce kuma.io/sidecar-injection=enabled --overwrite=true
kubectl annotate service catalog-api -n commerce ingress.kubernetes.io/service-upstream=true --overwrite=true
kubectl annotate service products-api -n commerce ingress.kubernetes.io/service-upstream=true --overwrite=true
kubectl annotate service pricing-api -n commerce ingress.kubernetes.io/service-upstream=true --overwrite=true
    
```

Deixe somente a versão ```v1``` do ```catalog``` em funcionamento:

```sh
kubectl scale deploy catalogapi-v1 --replicas=1 -n commerce 
kubectl scale deploy catalogapi-v2 --replicas=0 -n commerce 
kubectl scale deploy catalogapi-v3 --replicas=0 -n commerce 
```

Faça o ```port-forward```
```
./port-forward.sh
```

Liste os ```pods``` do ```Vault``` e veja que estão em ```Running``` porém não estão ```Ready```

```sh
kubectl get pods -n vault
```
```
NAME                                   READY   STATUS      RESTARTS   AGE
vault-0                                0/1     Running     0          7m24s
vault-agent-injector-56567df48-cc8gv   1/1     Running     0          7m24s
vault-server-test                      0/1     Completed   0          7m23s
```

Tente acessar a interface gráfica através do endereço http://localhost:8200 e veja que de fato o ```Vault``` está fechado.

Será necessário inicializar o ```Vault```.

Abra um sessão com o ```pod``` do Vault:
```bash
kubectl exec -it vault-0 -n vault -- sh
```

Após isso, todos comandos referente a configuração serão executados dentro do ```pod``` do Vault.

## Inicializar

Inicializa o Vault com 3 chaves compartilhadas e pelo menos duas necessárias, salvando as chaves em formato json na pasta de configurações

```sh
vault operator init -key-shares=3 -key-threshold=2 -format=json > /vault/data/cluster-keys.json
```

Verifique as chaves e o token inicial usando o comando:
```sh
cat /vault/data/cluster-keys.json
```

O resultado deve ser parecido com este:
```
{
  "unseal_keys_b64": [
    "NKkkR7JS11K8W+xnHS1I432YmVAzwCl35el9cEXdidcx",
    "Nb/PZEigX6XSBz5ie7VnCenH6T4WKoVrPgpWMLp7Xwry",
    "/yFYCQHj9SkqTFWtiQsFVFjJhcbxdwJwlZcxYDx5MStH"
  ],
  "unseal_keys_hex": [
    "34a92447b252d752bc5bec671d2d48e37d98995033c02977e5e97d7045dd89d731",
    "35bfcf6448a05fa5d2073e627bb56709e9c7e93e162a856b3e0a5630ba7b5f0af2",
    "ff21580901e3f5292a4c55ad890b055458c985c6f1770270959731603c79312b47"
  ],
  "unseal_shares": 3,
  "unseal_threshold": 2,
  "recovery_keys_b64": [],
  "recovery_keys_hex": [],
  "recovery_keys_shares": 5,
  "recovery_keys_threshold": 3,
  "root_token": "hvs.KqEKr5W6qchg1HMDcFaOtz3A"
}

```
## Desbloquear
O vault está bloqueado para utilização, desbloqueio-o usando 2 das 3 chaves distintas presentes no arquivo cluster-keys.json (unseal_keys_b64):
```sh
KEY1=[chave aqui]
KEY2=[chave aqui]
````

Após atribuir os valores, execute os comandos para desbloquear o vault
```sh
vault operator unseal $KEY1
vault operator unseal $KEY2
```
A saída deve mostrar que o Vault está inicializado e desbloqueado:
```
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
```

## Acessar
Faça o login no Vault usando o root token presente no arquivo ``cluster-keys.json``

```sh
TOKEN=<root-token>
vault login $TOKEN
```

A mensagem de saída deve ser parecida com esta:
```
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

```

## Ativar mecanismo KV
Ative o mecanismo KV (Key Value) para armamzenar seus segredos.

```sh
vault secrets enable -path=catalog kv-v2
```

## Criar as secrets
Com o mecanismo KV habilitado, crie suas secrets

```sh
vault kv put catalog/settings/mongo connectionString="mongodb://mongo.mongo.svc.cluster.local:27017" databaseName="catalog" collectionName="catalog"
```

Verifique se os valores foram gravados corretamente executando o comando:

```sh
vault kv get catalog/settings/mongo
```

Os valores podem ser recuperados via API também.

> Importante: Execute este comando fora do container. 
```sh
TOKEN=<token>
curl -i http://127.0.0.1:8200/v1/catalog/data/settings/mongo -H "Authorization: Bearer $TOKEN"
```

## Gerenciando políticas

Crie uma policy que permita somente leitura das secrets:

```sh
vault policy write readers - <<EOF
path "catalog/data/settings/mongo" {
  capabilities = ["read"]
}
EOF
```

Crie um novo token para esta policy:

```sh
vault token create -policy=readers -format=json > /vault/data/reader-token.json
```

Recupere o novo token fazendo a leitura do arquivo:

```sh
cat /vault/data/reader-token.json
```

Faça o login com este novo token:

```sh
CLIENT_TOKEN=<token>
vault login $CLIENT_TOKEN
```

Tente excluir as chaves:
```sh
vault kv delete catalog/settings/mongo
```

A saída deve ser:
```
Error deleting catalog/data/settings/mongo: Error making API request.

URL: DELETE http://127.0.0.1:8200/v1/catalog/data/settings/mongo
Code: 403. Errors:

* 1 error occurred:
	* permission denied
```


## Configurando o Agent
Efetue o logon novamente com o ```root_token```
```sh
vault login $TOKEN
```

Habilite a autenticação pelo Kubernetes

```sh
vault auth enable kubernetes
```

Crie uma ```policy``` e uma ```role``` para utlização do Kubernetes

```sh
vault write auth/kubernetes/config kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"

vault policy write vault-agent - <<EOF
path "catalog/data/settings/mongo" {
  capabilities = ["read"]
}
EOF
```

Habilite o mecanismo de autorização de AppRole

```sh
vault auth enable approle
```

Configure uma AppRole para ser usada pelo ```agent```.


```sh
vault write auth/kubernetes/role/vault-agent \
    bound_service_account_names=vault-agent \
    bound_service_account_namespaces=commerce \
    policies=vault-agent \
    ttl=24h
```

Fora do container do Vault, crie uma uma conta de serviço do Kubernetes para utilização pelo ```Agent```. Utilize uma outra janela.
```sh
kubectl create sa vault-agent -n commerce
```

Faça um ```patch``` no ```deployment``` das aplicações ```catalog``` para injetar as ```secrets```
```sh
kubectl patch deployment -n commerce catalogapi-v1 --patch-file k8s/vault/catalog-app-patch.yaml
```

Verifique que os ```pods``` de ```catalog``` foram reiniciados e agora possuem 2 ```containers```. Execute o comando abaixo e veja que foi criado um arquivo dentro do ```pod``` de ```catalog``` com as secrets.

```sh
kubectl exec -n commerce $(kubectl get pods -l app=catalogapi -n commerce -o jsonpath="{.items[0].metadata.name}") -c catalogapi-api -- cat /vault/secrets/catalogapi.txt
```

Para utilizar estas variáveis é necessário fazer uma alteração no comando de inicialização do ```pod```. 

```sh
kubectl patch deployment -n commerce catalogapi-v1 --patch-file k8s/vault/catalog-container-patch.yaml
```

Remova o ```configMap``` do ```deployment```, ele não será mais necessário

```sh
kubectl patch -n commerce deploy catalogapi-v1 --type=json -p='[{"op": "remove", "path": "/spec/template/spec/containers/0/envFrom"}]'
kubectl delete -n commerce configmap catalog-api-v1
```

Faça algumas chamadas a aplicação e veja que a aplicação continua funcionando, mas as configurações agora são gerenciadas pelo ```Vault```.
