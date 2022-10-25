CONTEXT=commerce



start_k8s () {

    #minikube delete -p $CONTEXT

    minikube start \
        -p $CONTEXT \
        --cpus=4 \
        --memory=4096 \
        --embed-certs=true
}

install_service_mesh() {
    kumactl install control-plane | kubectl apply --context $CONTEXT -f -
    kubectl --context=$CONTEXT wait pods -n kuma-system -l app=kuma-control-plane --for condition=Ready --timeout=90s
    kumactl install observability --components grafana,prometheus,jaeger | kubectl apply --context $CONTEXT -f -

}

install_apps(){

    kubectl --context=$CONTEXT apply -f k8s/apps.yaml
 
}

install_infrastructure() {
    kubectl --context=$CONTEXT apply -f k8s/infrastructure
}

install_gateway() {
    kubectl --context=$CONTEXT wait pods -n kong -l app=ingress-kong --for condition=Ready --timeout=90s 
}


configure_gateway() {
    kubectl --context $CONTEXT rollout restart deploy -n kong
}

configure_service_mesh() {
   
    kubectl --context=$CONTEXT apply -f k8s/kuma/mesh.yaml
    kubectl --context=$CONTEXT apply -f k8s/kuma/external-service.yaml
    kubectl --context=$CONTEXT apply -f k8s/kuma/observability-traffic-permissions.yaml
    
    kubectl --context=$CONTEXT delete circuitbreaker circuit-breaker-all-default
    kubectl --context=$CONTEXT delete retry retry-all-default
    kubectl --context=$CONTEXT delete timeout timeout-all-default

    

    
}

upload_images() {

    
    docker pull docker.io/patrickreinan/commerce-productsapi:latest
    docker pull docker.io/patrickreinan/commerce-pricingapi:latest
    docker pull docker.io/patrickreinan/commerce-catalogapi:latest

    minikube -p $CONTEXT image load docker.io/patrickreinan/commerce-productsapi:latest
    minikube -p $CONTEXT image load docker.io/patrickreinan/commerce-pricingapi:latest
    minikube -p $CONTEXT image load docker.io/patrickreinan/commerce-catalogapi:latest
}

start_k8s
upload_images
install_infrastructure
install_service_mesh
install_gateway
install_apps
configure_gateway
configure_service_mesh



