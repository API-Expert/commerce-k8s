# Commerce 

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

4. Execute o script ```port-forward.sh``` para criar uma ligação entre a porta local e a porta do serviço no _cluster_ ```kubernetes```.

    Saída:
    ```sh
    kuma-control-plane - 5681
    kong-proxy - 8443
    jaeger-query - 8080
    grafana - 3000
    ```

5. Selecione o contexto ```commerce``` para o ```kubectl```:

    ``` sh
    kubectl config use-context commerce
    ```


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

> Faça algumas chamadas e veja que agora o acesso está sendo negado pelo API Gateway.

## Crie os consumidores e as chaves

Para acessar o API Gateway será necessário criar ```consumers```e chaves (API Key) que servirão para autenticar as chamadas ao API Gateway. Crie os consumidores e suas chaves executando o comando abaixo:

```sh
kubectl apply -f k8s/kong/security/consumers-key-auth.yaml
```

> Utilizando a coleção do Postman será possível notar que as chamadas agora são permitidas

## Crie o controle de acesso (autorização)

O controle de acesso vai garantir que somente ```consumers``` que tem permissão a tais recursos possam fazer a requisição. O comando abaixo criará o controle de acesso.

```sh
kubectl apply -f k8s/kong/security/consumers-acl.yaml
```

### Atribua o controle de acesso aos consumidores e as rotas
Com o controle de acesso criado, é necessário atribuí-lo aos consumidores:

```sh
kubectl patch KongConsumer pricing -n commerce --type=json -p='[{"op": "add", "path": "/credentials/-", "value":"pricing-credential-acl"}]'
kubectl patch KongConsumer marketing -n commerce --type=json -p='[{"op": "add", "path": "/credentials/-", "value":"marketing-credential-acl"}]'
kubectl patch KongConsumer external -n commerce --type=json -p='[{"op": "add", "path": "/credentials/-", "value":"external-credential-acl"}]'
kubectl patch KongConsumer external-canary -n commerce --type=json -p='[{"op": "add", "path": "/credentials/-", "value":"external-credential-canary-acl"}]'
```
Em seguida é necessário configurar as rotas quais os grupos estão autorizados a utilizá-las:
```sh
kubectl -n commerce annotate ingress catalog-default-route  konghq.com/plugins=external-acl
kubectl -n commerce annotate ingress products-default-route  konghq.com/plugins=marketing-acl
kubectl -n commerce annotate ingress pricing-default-route  konghq.com/plugins=pricing-acl
```

> Tente fazer chamadas invertendo os usuário e veja que o API Gateway irá negar a chamada.

## Bot Detection
O controle de detecção de _bot_ irá bloquear chamadas de acordo com o User Agent informado no header da requisição. 

```sh
kubectl apply -f k8s/kong/global-plugins/security/bot-detection.yaml
```
> Faça alguns testes e veja que a detecção de _bot_ está bloqueando o Postman.

```sh
kubectl delete -f k8s/kong/global-plugins/security/bot-detection.yaml
```

> Remova a detecção de _bot_ para não atrapalhar os próximos testes.

## IP Restriction

A restrição por IP pode ser usado para permitir ou bloquear IPs válidos para as requisições:
```sh
kubectl apply -f k8s/kong/global-plugins/security/ip-restriction.yml
```

> Faça alguns testes e sua requisição será bloqueada

```sh
kubectl delete -f k8s/kong/global-plugins/security/ip-restriction.yml
```
> Desabilite para não atrapalhar os próximos testes

## Throttling (Rate Limiting)
O _throttling_ irá controlar a quantidade máxima de requisições por período de tempo.
Configure o rate limiting para o consumidor ```marketing```.
```sh
kubectl apply -f k8s/kong/traffic/throttling.yaml
kubectl -n commerce annotate KongConsumer marketing konghq.com/plugins=rate-limiting-plugin  --overwrite=true
```
> Faça alguns testes e verifique os _headers_ de retorno, eles mostrarão a quantidade restante de chamadas.

```sh
kubectl -n commerce annotate KongConsumer marketing konghq.com/plugins=  --overwrite=true
kubectl delete -f k8s/kong/traffic/throttling.yaml
```

> Desabilite para não atrapalhar os próximos testes

## Cache
O cache vai permitir que as respostas as requisições sejam armazenadas no API Gateway por um período de tempo. Habilte o cache para o ```catalog```.

```sh
kubectl apply -f k8s/kong/traffic/caching.yaml
kubectl -n commerce annotate svc/catalog-api konghq.com/plugins=catalog-cache-plugin --overwrite=true
```

> Faça alguns testes e verifique os _headers_ de _cache_.

```
kubectl -n commerce annotate svc/catalog-api konghq.com/plugins= --overwrite=true
kubectl delete -f k8s/kong/traffic/caching.yaml
```

> Desabilite se achar necessário.

## Gerando massa de requisições
Utilize o _script_ ```test-catalog-through-kong.sh``` para executar diversas chamadas para massa de dados.
```sh
./test-catalog-through-kong.sh 
```

## Observabilidade - Análise
Adicione os _dashboards_ ao Grafana.

Name|URL
-|-
Kong Official Dashboard (7424)|https://grafana.com/grafana/dashboards/7424 

Adicione o ```data source``` do ElasticSearch para o endereço
```
http://elasticsearch.elasticsearch.svc:9200
```

Importe o _dashboard_ ```grafana/kong-logs.json``` ao Grafana.


