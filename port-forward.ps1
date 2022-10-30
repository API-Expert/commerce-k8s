$env:CONTEXT="commerce"

kubectl --context=$env:CONTEXT wait pods -n kuma-system -l app=kuma-control-plane --for condition=Ready --timeout=90s
kubectl --context=$env:CONTEXT wait pods -n kong -l app=ingress-kong --for condition=Ready --timeout=90s
kubectl --context=$env:CONTEXT wait pods -n mesh-observability -l app=grafana --for condition=Ready --timeout=90s
kubectl --context=$env:CONTEXT wait pods -n mesh-observability -l app=jaeger --for condition=Ready --timeout=90s


Write-Host kuma: 5681
kubectl --context=$env:CONTEXT port-forward -n kuma-system svc/kuma-control-plane 5681:5681 &
Write-Host kong: 8443
kubectl --context=$env:CONTEXT port-forward -n kong svc/kong-proxy 8443:443  &
Write-Host jaeger: 8080
kubectl --context=$env:CONTEXT port-forward -n mesh-observability svc/jaeger-query 8080:80  &
Write-Host grafana: 3000
kubectl --context=$env:CONTEXT port-forward -n mesh-observability svc/grafana 3000:80 &
Write-Host vault: 8200
kubectl --context=$env:CONTEXT port-forward -n vault svc/vault 8200:8200 &