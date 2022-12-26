CONTEXT=commerce
basepath=/tmp/port-forward




portforward() {

    service=$1
    namespace=$2
    portorigin=$3
    portdestination=$4
    
    pidFile=$basepath-$service.pid



    if [ -f "$pidFile" ]
    then

        pid=$(cat $pidFile)
        
        if [ $? -eq 0 ]
        then
            kill $pid   > /dev/null
        fi

        rm $pidFile
   
    fi

    kubectl --context=$CONTEXT  \
            -n $namespace       \
            port-forward svc/$service \
            $portorigin:$portdestination>>$basepath-$service.log > /dev/null &
            
    echo  $!>>$pidFile

    echo $service - $portorigin

}

kubectl --context=$CONTEXT wait pods -n kuma-system -l app=kuma-control-plane --for condition=Ready --timeout=90s
kubectl --context=$CONTEXT wait pods -n kong -l app=ingress-kong --for condition=Ready --timeout=90s
kubectl --context=$CONTEXT wait pods -n mesh-observability -l app=grafana --for condition=Ready --timeout=90s
kubectl --context=$CONTEXT wait pods -n mesh-observability -l app=jaeger --for condition=Ready --timeout=90s
kubectl --context=$CONTEXT wait pods -n vault -l app.kubernetes.io/name=vault --for condition=Ready --timeout=10s

echo


portforward kuma-control-plane kuma-system 5681 5681
portforward kong-proxy kong 8443 443
portforward jaeger-query mesh-observability 8080 80
portforward grafana mesh-observability 3000 80
portforward vault vault 8200 8200

exit 0