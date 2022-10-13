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

## Configurando o API Gateway

### Configuração do TLS
```sh
kubectl apply -f k8s/kong/global-plugins/security/tls.yaml
```

### Criação das rotas

```sh
kubectl apply -f k8s/kong/traffic/routes.yaml 
```

### Ativação de API Key

```sh
kubectl apply -f k8s/kong/global-plugins/security/key-auth.yaml
```

## Applications

Application|Url
-|-
Kong Proxy|:lock: https://localhost:8443
Kuma GUI|http://localhost:5681
Jaeger|http://localhost:8080
Grafana|http://localhost:3000

## Prerequisites
- Install localhost-ca.key on your machine to works on tls


## Defaults
- **Catalog service** has caching on API Gateway.
- **Markting consumer** has rate limiting

## Grafana Dashboards 
Name|URL
-|-
Kong Official Dashboard (7424)|https://grafana.com/grafana/dashboards/7424 
Logs/Apps (13639)|https://grafana.com/grafana/dashboards/13639 


## Testing 
```sh
./test-catalog-through-kong.sh | grep -e version -e x-cache-status


dotnet nuget add source ./nuget --name local
