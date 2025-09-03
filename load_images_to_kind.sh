#!/bin/bash


images=("quay.io/strimzi/kafka:0.39.0-kafka-3.5.0" "quay.io/strimzi/operator:0.39.0" "docker.io/bitnami/keycloak:26.1.4-debian-12-r0" "docker.io/bitnami/postgresql:17.4.0-debian-12-r4" "docker.elastic.co/elasticsearch/elasticsearch:7.17.24" "nginx:1.21" "openpolicyagent/opa:latest-envoy" "alpine:latest" "minio/minio:RELEASE.2022-10-21T22-37-48Z" "minio/mc" "influxdb:2.6.1" "nexus3.onap.org:10002/onap/dmaap/dmaap-mr:1.4.4" "nexus3.onap.org:10001/onap/sdnc-image:2.6.1" "nexus3.onap.org:10001/onap/sdnc-web-image:2.6.1" "nexus3.o-ran-sc.org:10001/o-ran-sc/nonrtric-plt-auth-token-fetch:1.1.1" "nexus3.o-ran-sc.org:10001/o-ran-sc/nonrtric-plt-pmlog:1.0.0" "nexus3.o-ran-sc.org:10001/o-ran-sc/nonrtric-plt-auth-token-fetch:1.1.1" "nexus3.o-ran-sc.org:10001/o-ran-sc/nonrtric-plt-pmproducer:1.0.1" "nexus3.o-ran-sc.org:10001/o-ran-sc/nonrtric-plt-auth-token-fetch:1.1.1" "nexus3.o-ran-sc.org:10004/o-ran-sc/nonrtric-plt-ranpm-pm-file-converter:1.2.0" "nexus3.o-ran-sc.org:10001/o-ran-sc/nonrtric-gateway:1.2.0" "nexus3.o-ran-sc.org:10001/o-ran-sc/nonrtric-controlpanel:2.5.0" "nexus3.o-ran-sc.org:10001/o-ran-sc/nonrtric-plt-informationcoordinatorservice:1.5.0" "redpandadata/console:v2.2.3" "confluentinc/cp-kafka:7.2.2" "ghcr.io/scholzj/zoo-entrance:latest")

for image in "${images[@]}"; do
    echo "Pulling Docker image: $image"
    docker image pull "$image"

    echo "Loading Docker image into Kind: $image"
    kind load docker-image "$image"

    echo "Finished processing image: $image"
done