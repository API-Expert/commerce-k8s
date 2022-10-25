$env:CONTEXT="commerce"



function Start-k8s () {

  

    minikube start `
        -p $env:CONTEXT `
        --cpus=4 `
        --memory=4096 `
        --embed-certs=true
}

function Install-Service-Mesh() {
    kubectl --context=$env:CONTEXT apply -f k8s/infrastructure/kuma/kuma-control-plane.yaml
    kubectl --context=$env:CONTEXT wait pods -n kuma-system -l app=kuma-control-plane --for condition=Ready --timeout=90s
    kubectl --context=$env:CONTEXT apply -f k8s/infrastructure/kuma/kuma-observability.yaml
    
}

function Install-Apps(){

    kubectl --context=$env:CONTEXT apply -f k8s/apps.yaml
 
}

function Install-Infrastructure() {
    kubectl --context=$env:CONTEXT apply -f k8s/infrastructure
}

function Install-Gateway() {
    kubectl --context=$env:CONTEXT wait pods -n kong -l app=ingress-kong --for condition=Ready --timeout=90s 
}


function Configure-Gateway() {
    kubectl --context $env:CONTEXT rollout restart deploy -n kong
}

function Configure-Service-Mesh() {
   
    kubectl --context=$env:CONTEXT apply -f k8s/kuma/mesh.yaml
    kubectl --context=$env:CONTEXT apply -f k8s/kuma/external-service.yaml
    kubectl --context=$env:CONTEXT apply -f k8s/kuma/observability-traffic-permissions.yaml
    
    kubectl --context=$env:CONTEXT delete circuitbreaker circuit-breaker-all-default
    kubectl --context=$env:CONTEXT delete retry retry-all-default
    kubectl --context=$env:CONTEXT delete timeout timeout-all-default

    

    
}

function Upload-Images() {

    
    docker pull docker.io/patrickreinan/commerce-productsapi:latest
    docker pull docker.io/patrickreinan/commerce-pricingapi:latest
    docker pull docker.io/patrickreinan/commerce-catalogapi:latest

    minikube -p $env:CONTEXT image load docker.io/patrickreinan/commerce-productsapi:latest
    minikube -p $env:CONTEXT image load docker.io/patrickreinan/commerce-pricingapi:latest
    minikube -p $env:CONTEXT image load docker.io/patrickreinan/commerce-catalogapi:latest
}

Start-k8s
Upload-Images
Install-Infrastructure
Install-Service-Mesh
Install-Gateway
Install-Apps
Configure-Gateway
Configure-Service-Mesh



