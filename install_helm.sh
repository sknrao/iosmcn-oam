#!/bin/bash

. scripts/kube_get_controlplane_host.sh

# Generic error printout function
# args: <numeric-response-code> <descriptive-string>
check_error() {
    if [ $1 -ne 0 ]; then
        echo "Failed: $2"
        echo "Exiting..."
        exit 1
    fi
}

process_client() {
  local cid="$1"
  local path="$2"
  create_clients nonrtric-realm "$cid"
  check_error $?
 
  generate_client_secrets nonrtric-realm "$cid"
  check_error $?

  export APP_CLIENT_SECRET=$(< .sec_nonrtric-realm_$cid)

  envsubst < helm/charts/$path/values-template.yaml > helm/charts/$path/values.yaml
}

# Create a topic
# args:  <kafka-bootstrap-pod.namespace:<port> <topic-name> [<num-partitions>]
create_topic() {

    if [ $# -lt 2 ] && [ $# -gt 3 ]; then
        echo "Usage: create-topic.sh <kafka-bootstrap-svc.namespace> <topic-name> [<num-partitions>]"
        exit 1
    fi
    kafka=$1
    topic=$2
    partitions=$3

    if [ -z "$partitions" ]; then
        partitions=1
    fi

    echo "Creating topic: $topic with $partitions partition(s) in $kafka"

    kubectl exec -it kafka-client -n nonrtric -- bash -c 'kafka-topics --create --topic '$topic'  --partitions '$partitions' --bootstrap-server '$kafka

    return $?
}

# Function to display usage
usage() {
   echo "Usage: $0 [--kind] [--kubernetes-host=<host>]"
   exit 1
}

# Initialize variables
KIND=false
export KUBERNETES_HOST=$(kube_get_controlplane_host)

# Parse parameters
while [[ "$#" -gt 0 ]]; do
   case $1 in
       --help)
           usage
           shift
           ;;
       --kind)
           KIND=true
           echo "Kind deployment option was chosen."
           shift
           ;;
       --kubernetes-host=*)
           export KUBERNETES_HOST="${1#*=}"
           echo "Kubernetes HOST is: $KUBERNETES_HOST"
           shift
           ;;
       *)
           usage
           ;;
   esac
done

if [ $KIND == "true" ]; then
  # in case of Kind
  docker exec -it kind-worker rm -rf shared-volume
  docker exec -it kind-worker mkdir shared-volume
  docker exec -it kind-worker chmod 777 shared-volume
  #kind load docker-image sknrao/dfc:2.0
  #kind load docker-image nexus3.onap.org:10002/onap/org.onap.dcaegen2.collectors.ves.vescollector:1.12.3-configured
  #kind load docker-image pm-file-converter:latest
  # kind load docker-image pm-rapp:iosmcn
  # kind load docker-image pynts-o-du-o1:0.9.1
else
  scripts/clean-shared-volume.sh
fi

helm install --wait keycloak oci://registry-1.docker.io/bitnamicharts/keycloak -f helm/keyloak_values.yaml
. scripts/populate_keycloak.sh

# Create realm in keycloak
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

cid="console-setup"
__get_admin_token
TOKEN=$(get_client_token nonrtric-realm $cid)
echo "Client token is: $TOKEN"

helm repo add strimzi https://strimzi.io/charts/

helm install --wait strimzi-kafka-crds -n nonrtric strimzi/strimzi-kafka-operator --version 0.39.0

cp config/bundle-server/bundle.tar.gz helm/charts/databases/charts/opa-rule-db/data

helm install --wait  -n nonrtric databases helm/charts/databases/

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

INFLUXDB2_TOKEN="abcdesf"

helm install --wait  -n nonrtric kafka helm/charts/kafka/

helm install --wait  -n nonrtric onap-parts helm/charts/onap-parts/

echo "Wait for kafka"
_ts=$SECONDS
until $(kubectl exec -n nonrtric kafka-client -- kafka-topics --list --bootstrap-server kafka-1-kafka-bootstrap.nonrtric:9092 1> /dev/null 2> /dev/null); do
    echo -ne "  $(($SECONDS-$_ts)) sec, retrying at $(($SECONDS-$_ts+5)) sec                        $SAMELINE"
    sleep 5
done

# Pre-create known topic to avoid losing data when autocreated by apps
__topics_list="file-ready collected-file json-file-ready-kp json-file-ready-kpadp pmreports"
for __topic in $__topics_list; do
    create_topic kafka-1-kafka-bootstrap.nonrtric:9092 $__topic 10
done

# Need to update DFC truststore?
# Need to use keytool for CA for RAN?

process_client "dfc" "nonrtric-pm/charts/dfc"
process_client "kafka-producer-pm-xml2json" "nonrtric-pm/charts/kafka-producer-pm-xml2json"
process_client "pm-producer-json2kafka" "nonrtric-pm/charts/pm-producer-json2kafka"
process_client "pm-log" "pm-log"

helm install --wait  -n nonrtric nonrtric-pm helm/charts/nonrtric-pm/

helm install --wait  -n nonrtric pm-log helm/charts/pm-log/

sleep 10

process_client "pm-rapp" "nrt-rapps"
helm install --wait  -n nonrtric pm-rapp helm/charts/nrt-rapps/