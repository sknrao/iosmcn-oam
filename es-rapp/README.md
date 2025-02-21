## Energy Savings rAPP for SMaRT-5G demo

### Manual build, tag and push to image repo

Build for docker or local kubernetes\
`./build.sh no-push [<--tag image-tag>]`

Build for remote kubernetes - an externally accessible image repo (e.g. docker hub) is needed  \
`./build.sh <external-image-repo> [<--tag image-tag>]`


## Function

There are two functionalities, and you can switch between them:

1. The rApp reads PM reports created by PM rApp, stored in a common volume. Depending on input data it can:
- Create or delete TS-xApp's traffic policies
- Send request to SDN-Controller to update cell administrative state

2. The rApp reads PM reports created by PM rAPP via Kafka. Then, it performs a dummy logic. It does not touch policies, nor SDN-Controller yet. This is work in progress

### Configuration

For the first functionality, the container expects the following environment variables:

- SDN_CONTROLLER_ADDRESS and SDN_CONTROLLER_PORT: Host and port of the SDN Controller

- SDN_CONTROLLER_USERNAME and SDN_CONTROLLER_PASSWORD : Credentials needed to update info stored in SDN-C

- A1T_ADDRESS and A1T_PORT: Host and port of the Near-RT RIC's A1 Termination

- RANSIM_DATA_PATH : Path where input PM reports are stored

- LOAD_PREDICTOR : Address of the Load Predictor model

- LOAD_PREDICTOR_PORT : Port number of the Load Predictor model

- LOAD_PREDICTOR_API : API dedicated for inference.


The rApp tries to connect to SDN-C and A1T in init phase and exits if its not possible.

For the second functionality:
- CREDS_CLIENT_ID - client ID used in Keycloak. The same value must be then also be used in install/install-rapps.sh. Default value is: es-rapp
- AUTH_SERVICE_URL - URI to Keycloak. Default value is: http://keycloak.nonrtric:8080/realms/nonrtric-realm/protocol/openid-connect/token
- TOPIC - Kafka topic for PM-Rapp -> ES-Rapp communication. Default value is: es-rapp-topic
- KAFKA_SERVER - URI to Kafka. Default value is: kafka-1-kafka-bootstrap.nonrtric:9097.
- FUNC - switch between functionalities. Default value is f2 (second functionality). Other option is f1 (first functionality)

## License

Copyright (C) 2023 Rimedo Labs and Tietoevry. All rights reserved.
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
