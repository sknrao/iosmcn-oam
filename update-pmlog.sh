#!/bin/bash

#  ============LICENSE_START===============================================
#  Copyright (C) 2023 Nordix Foundation. All rights reserved.
#  ========================================================================
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#  ============LICENSE_END=================================================
#

# Function to display usage
usage() {
   echo "Usage: $0 [--deployment-type=<docker/kind/kubernetes>] [--ics-port=<port>] [--kubernetes-host=<host>]"
   exit 1
}

KUBERNETES_HOST_SPECIFIED=""
# Parse parameters
while [[ "$#" -gt 0 ]]; do
   case $1 in
      --help)
          usage
          shift
          ;;
      --ics-port)
          ICS_PORT="${1#*=}"
          echo "ICS port is $ICS_PORT."
          shift
          ;;
      --deployment-type)
          DEPLOYMENT_TYPE="${1#*=}"
          echo "Deployment optiontype is $DEPLOYMENT_TYPE."
          shift
          ;;
      --kubernetes-host=*)
          KUBERNETES_HOST_SPECIFIED="${1#*=}"
          echo "Kubernetes HOST specified: $KUBERNETES_HOST_SPECIFIED"
          shift
          ;;
      *)
          usage
          ;;
   esac
done

if [ $DEPLOYMENT_TYPE == "kubernetes" ]; then
    echo "Deployment type is type kubernetes, retriving kubernetes host IP automatically, ignoring --kubernetes-host"
    export KUBERNETES_HOST=$(kube_get_controlplane_host)
    ICS_ADDRESS="${KUBERNETES_HOST}:31823"
else if [ $DEPLOYMENT_TYPE == "kind" ]; then
    if [ -z "$KUBERNETES_HOST_SPECIFIED" ]; then
      # The variable is empty
      echo "Input param --kubernetes-host is missing and is required."
      exit 1
    fi
    export KUBERNETES_HOST=$KUBERNETES_HOST_SPECIFIED
    ICS_ADDRESS="${KUBERNETES_HOST}:31823"
else if [ $DEPLOYMENT_TYPE == "docker" ]; then
    ICS_ADDRESS=""
fi

. scripts/update_ics_job.sh

echo "Installation of pm to influx job"
export KUBERNETES_HOST="172.18.0.3"

. scripts/populate_keycloak.sh

cid="console-setup"

TOKEN=$(get_client_token nonrtric-realm $cid)

JOB='{
       "info_type_id": "PmData",
       "job_owner": "console",
       "job_definition": {
          "filter": {
             "sourceNames": [],
             "measObjInstIds": [],
             "measTypeSpecs": [],
             "measuredEntityDns": []
          },
          "deliveryInfo": {
             "topic": "pmreports",
             "bootStrapServers": "kafka:9097"
          }
       }
    }'
echo $JOB > .job.json
update_ics_job $ICS_ADDRESS pmlog $TOKEN

echo "done"

