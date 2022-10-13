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
        kill $(cat $pidFile) 
        rm $pidFile
    fi

    kubectl --context=$CONTEXT  \
            -n $namespace       \
            port-forward svc/$service \
            $portorigin:$portdestination>>$basepath-$service.log > /dev/null &
            
    echo  $!>>$pidFile

    echo $service - $portorigin

}



portforward kuma-control-plane kuma-system 5681 5681
portforward kong-proxy kong 8443 443
portforward jaeger-query mesh-observability 8080 80
portforward grafana mesh-observability 3000 80
