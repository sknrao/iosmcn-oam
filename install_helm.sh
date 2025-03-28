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

  if [ "$cid" == "pm-rapp" ]; then
    export PMRAPP_CLIENT_SECRET=$(< .sec_nonrtric-realm_$cid)
  elif [ "$cid" == "es-rapp" ]; then
    export ESRAPP_CLIENT_SECRET=$(< .sec_nonrtric-realm_$cid)
  else
    export APP_CLIENT_SECRET=$(< .sec_nonrtric-realm_$cid)
  fi

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

# Function to display usage information
usage() {
   echo "Usage: $0 --kubernetes-host <host> [--kind <kind>]"
   echo
   echo "Options:"
   echo "  --kubernetes-host <host>  Required. Specify the Kubernetes host IP (for me, localhost did not work. In case of Kind, it is IP of kind-worker container)."
   echo "  --kind                    Optional. If used, script assumes Kind kubernetes is used. If not used, assumes normal kubernetes is used."
   echo
   echo "Example:"
   echo "  $0 --kubernetes-host 192.168.1.120 --kind"
   exit 1
}

manage_directories() {
   local directories=("$@")  # Accepts multiple directory names as arguments

   for dir in "${directories[@]}"; do
       # Check if the directory exists
       if [ -d "$dir" ]; then
           # Remove the directory if it exists
           sudo rm -rf "$dir"
       fi
       # Create the directory
       mkdir "$dir"
       # Set permissions
       chmod 777 "$dir"
   done
}

# Initialize variables
KIND=false
kubernetes_host_specified=false

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
	   kubernetes_host_specified=true
           shift
           ;;
       *)
           usage
           ;;
   esac
done

# Check if the argument was not passed
if [ "$kubernetes_host_specified" = false ]; then
   echo "Error: --kubernetes-host argument is required."
   exit 1
fi

# set kubectl context to correct namespace
kubectl config set-context --current --namespace=nonrtric
if [ $KIND == "true" ]; then
  # in case of Kind
  docker exec -it kind-worker rm -rf shared-volume
  docker exec -it kind-worker mkdir shared-volume
  docker exec -it kind-worker chmod 777 shared-volume
  kind load docker-image localhost:5000/vescollector:1.12.3-configured
  kind load docker-image pm-file-converter:latest
  kind load docker-image pm-rapp:iosmcn
else
  # in case of pure Kubernetes
  docker image push localhost:5000/vescollector:1.12.3-configured || { echo "Docker image vescollector push failed. Exiting script."; exit 1; }
  docker image push localhost:5000/pm-rapp:iosmcn || { echo "Docker image pm-rapp push failed. Exiting script."; exit 1; }
  docker image push localhost:5000/es-rapp:latest || { echo "Docker image es-rapp push failed. Exiting script."; exit 1; }
  # since Postgres always creates DB with different password stored in it, we need to delete PV each time
  kubectl delete pvc data-keycloak-postgresql-0
  kubectl delete pv local-pv
  # delete and recreate directories: shared-volume (used for Volume Mount) and data (used for PV)
  manage_directories "/tmp/shared-volume" "/tmp/data"
  # delete and clone sim-o1 repo to path
  sudo rm -rf /tmp/sim-o1-ofhmp-interfaces/
  git clone https://github.com/o-ran-sc/sim-o1-ofhmp-interfaces.git /tmp/sim-o1-ofhmp-interfaces/
  
  kubectl apply -f helm/kubernetes_storage_class.yaml
  kubectl apply -f helm/kubernetes_storage_pv.yaml
fi

helm install --wait keycloak oci://registry-1.docker.io/bitnamicharts/keycloak -f helm/keyloak_values.yaml --version 24.4.13
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
__topics_list="file-ready collected-file json-file-ready-kp json-file-ready-kpadp pmreports es-rapp-topic"
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
process_client "es-rapp" "nrt-rapps"
helm install --wait  -n nonrtric pm-rapp helm/charts/nrt-rapps/
