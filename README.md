# IOSMCN-OAM

This project focus on a docker-compose deployment solution for SMO/OAM Components.

## Introduction

With respect to OAM the SMO implements the O1-interface consumers.
According to the O-RAN OAM Architecture and the O-RAN OAM Interface Specification,
the SMO implements a NETCONF Client for configuration and a HTTP/REST/VES server
for receiving all kind of events in VES format.

The setup contains an OpenDaylight based NETCONF client, ONAP VES Collector, Strimzi Message bus and O-RAN-SC RANPM.

## Prerequisites

### Resources

The solution was tested on a VM with

- 4x Core
- 16 GBit RAM 
- 50 Gbit Storage

### Operating (HOST) System

```
$ cat /etc/os-release | grep PRETTY_NAME
PRETTY_NAME="Ubuntu 22.04.2 LTS"
```

### Docker

```
$ docker --version
Docker version 23.0.1, build a5ee5b1
```
Please follow the required docker daemon configuration as documented in the following README.md:
- [./smo/common/docker/README.md](./smo/common/docker/README.md)

### Docker Compose

```
$ docker compose version
Docker Compose version v2.17.2
```

### GIT

```
$ git --version
git version 2.34.1
```

### Python

```
$ python3 --version
Python 3.10.6
```

A python parser package is required.
```
sudo apt install python3-pip
pip install jproperties
```

It is beneficial (but not mandatory) adding the following line add the
end of your ~/.bashrc file. I will suppress warnings when python script
do not verify self signed certificates for HTTPS communication.

```
export PYTHONWARNINGS="ignore:Unverified HTTPS request"
```

### ETC Host (DNS function - not needed in K8S)

Please change in the different .env files the environment variable 'HOST_IP'
to the IP address of the system where you deploy the solution - search for 
'aaa.bbb.ccc.ddd' and replace it. 

Please modify the /etc/hosts of your system.

* \<your-system>: is the hostname of the system, where the browser is started

* \<deployment-system-ipv4>: is the IP address of the system where the solution will be deployed

For development purposes <your-system> and <deployment-system> may reference the same system.

```
$ cat /etc/hosts
127.0.0.1	               localhost
127.0.1.1	               <your-system-name>

# SMO OAM development system
<deployment-system-ipv4>                   <domain-name>
<deployment-system-ipv4>           gateway.<domain-name> 
<deployment-system-ipv4>          identity.<domain-name>
<deployment-system-ipv4>          messages.<domain-name>
<deployment-system-ipv4>         odlux.oam.<domain-name>
<deployment-system-ipv4>    controller.dcn.<domain-name>
<deployment-system-ipv4> ves-collector.dcn.<domain-name>
<deployment-system-ipv4>             minio.<domain-name> 
<deployment-system-ipv4>          redpanda.<domain-name>
<deployment-system-ipv4>             nrtcp.<domain-name>


```

## Usage
First, you need to build required Docker images, in this case, PM/TS/ES rApp images and/or VES-collector (config/ves-collector/Dockerfile). Pay attention on docker image names - they depend on the deployment type (docker vs k8s, local vs remote docker artifactory,...).
NOTE: Since in RMI deployment, we had proprietary implementation of ES and TS rApp, I was able to push only supporting stuff for both rApps. The implementation itself needs to be provided separately.

### Bring Up Solution in Docker

1. First modify 2 environment variables by running the scripts
```
python3 adapt-to-environment.py -i <deployment-system-ipv4> -d <domain-name>
``` 
2. Run the following command - starts the SMO and Non-RT RIC framework
```
./docker-setup.sh
```

3. Run the following command - creates a PM Job
```
./update-pmlog.sh
```

4. Run the following command - start the dummy PM rApp
```
./pmrapp-setup.sh
```

In order to bring down the solution:
```
./docker-tear-down.sh
```

### Bring Up Solution in Kubernetes
There are two supported deployments - in standard Kubernetes and in Kind. In the current state of the installing script (install_helm.sh), Kind deployment is the newest and recently used in RMI deployment (kind_cluster.yaml). Deployment for standard Kubernetes was used a couple of months prior that, and was used mainly with O1 IF simulator (helm/o1-ofhmp-interface.yaml - [repo link](https://github.com/o-ran-sc/sim-o1-ofhmp-interfaces)). There should not be many differencies, but, one needs to be aware of that.

In order to prepare for deployment, run prepare_for_k8s.sh. Next, in case of Kind deployment, I uploaded docker images to Kind beforehand, since I experienced it to be very slow - load_images_to_kind.sh

Install script has takes two inputs: "--kubernetes-host=<ip>" - which is IP address of where the K8S cluster is running (in case of Kind, it is IP of Docker container called "<kind-name>-control-plane"); and "--kind" - which is optional and used if Kind deployment is used. For example:
```
./install_helm.sh  --kubernetes-host=172.21.0.3 --kind
```

Install script for Kubernetes deploys same things in the same order as install script for Docker. But, there are small differencies:
1. In case of Kind deployment, all file handling (config files, PVs, etc...) must be taken care of inside Kind docker containers. Also, docker images need to be pushed to Kind
2. Helm charts are used instead of docker-compose. I used Smart5G charts (https://github.com/opennetworkinglab/smart5g-nonrtric-plt-ranpm/tree/master/install/helm) as an inspiration/template, with a couple of changes. The major one is using Bitnami's Keycloak helm chart, which uses Postgres. For that, I needed to add PVs.

In order to bring down the solution, there is uninstall-helm.sh script. But, more often I was using restart_pm_rapps.sh script - because that is something you usually want to have updated.