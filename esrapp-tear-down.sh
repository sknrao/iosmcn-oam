#!/bin/bash

#  ============LICENSE_START===============================================
#  Copyright (C) 2023 Nordix Foundation and Tietoevry. All rights reserved.
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

echo "Stop and remove all es-rapp containers in the project"

docker stop $(docker ps -qa  --filter "label=ranesrapp")  2> /dev/null
docker stop $(docker ps -qa  --filter "label=ranesrapp")  2> /dev/null
docker rm -f $(docker ps -qa  --filter "label=ranesrapp")  2> /dev/null

docker compose -f docker-compose-esrapp_gen.yaml -p esrapp down
