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

### ETC Host (DNS function)

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

### Bring Up Solution

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
### Bring Down Solution
```
./docker-tear-down.sh
```
