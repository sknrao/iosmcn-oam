#!/bin/bash

# Recreate a topic
# args:  <kafka-bootstrap-pod.namespace:<port> <topic-name> [<num-partitions>]
recreate_topic() {
    kafka=$1
    topic=$2
    partitions=$3

    if [ -z "$partitions" ]; then
        partitions=1
    fi

    echo "Recreating topic: $topic with $partitions partition(s) in $kafka"
    kubectl exec -it kafka-client -n nonrtric -- bash -c 'kafka-topics --delete --topic '$topic' --bootstrap-server kafka-1-kafka-bootstrap.nonrtric:9092'
    sleep 5
    kubectl exec -it kafka-client -n nonrtric -- bash -c 'kafka-topics --create --topic '$topic' --partitions 10 --bootstrap-server kafka-1-kafka-bootstrap.nonrtric:9092'

    return $?
}

echo "Uninstalling Rapps..."
helm uninstall --wait pm-rapp
echo "Rapps uninstalled."

echo "Proceeding with recreating Rapp Kafka topics..."
recreate_topic kafka-1-kafka-bootstrap.nonrtric:9092 forward-rapp-topic 10
echo "Recreation of Rapp Kafka Topics succeeded."

echo "Proceeding with installation of Rapps..."
helm install --wait  -n nonrtric pm-rapp helm/charts/nrt-rapps/
echo "Rapps successfully installed."