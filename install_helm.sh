#!/bin/bash

# Generic error printout function
# args: <numeric-response-code> <descriptive-string>
check_error() {
    if [ $1 -ne 0 ]; then
        echo "Failed: $2"
        echo "Exiting..."
        exit 1
    fi
}


export KUBERNETES_HOST="172.18.0.3"
helm install -n nonrtric keycloak helm/charts/keycloak/
# Create realm in keycloak

. scripts/populate_keycloak.sh

create_realms nonrtric-realm
while [ $? -ne 0 ]; do
    create_realms nonrtric-realm
done

# Create client for admin calls
cid="console-setup"
create_clients nonrtric-realm $cid
check_error $?
generate_client_secrets nonrtric-realm $cid
check_error $?

helm repo add strimzi https://strimzi.io/charts/

helm install --wait strimzi-kafka-crds -n nonrtric strimzi/strimzi-kafka-operator --version 0.39.0

cp config/bundle-server/bundle.tar.gz helm/charts/opa-rule-db/data

helm install -n nonrtric databases helm/charts/databases/

echo "Waiting for influx db - there may be error messages while trying..."
retcode=1
while [ $retcode -eq 1 ]; do
    retcode=0
    CONFIG=$(kubectl exec -n nonrtric influxdb2-0 -- influx config ls --json)
    if [ $? -ne 0 ]; then
        retcode=1
        sleep 1
    elif [ "$CONFIG" == "{}" ]; then
        echo "Configuring dbBBBBBBBBBBBBBBBBBB"
        retcode=1
        sleep 1
        #kubectl exec -n nonrtric influxdb2-0 -- influx setup -u admin -p mySuP3rS3cr3tT0keN -o est -b pm-bucket -f
        ##if [ $? -ne 0 ]; then
         #   retcode=1
         #   sleep 1
        #fi
    else
        echo "Db user configured, skipping"
    fi
done

# Save influx user api-token to secret
B64FLAG="-w 0"
case "$OSTYPE" in
  darwin*)  B64FLAG="" ;;
esac
INFLUXDB2_TOKEN=$(get_influxdb2_token influxdb2-0 nonrtric | base64 $B64FLAG)
echo "INFLUX TOKEN IS $INFLUXDB2_TOKEN"

helm install -n nonrtric kafka helm/charts/kafka/

helm install -n nonrtric onap-parts helm/charts/onap-parts/