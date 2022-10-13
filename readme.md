# Commerce 

## Description
Commerce is a solution which demonstrates API Gateway and Service Mesh.

# Guide
- Gateway
    - TLS
    - API Key
    - Throttling (Product API)
    - Caching (Catalog API)
- Service Mesh
    - Mutual TLS
    - Balancing
        - Stable
        - Try using header canary:yes
    - Canary (with user)
- Observability (both)
    - Kong
    - Kuma
    - Logging


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
