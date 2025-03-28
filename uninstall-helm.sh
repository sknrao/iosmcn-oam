#!/bin/bash

helm uninstall pm-rapp
helm uninstall pm-log
helm uninstall nonrtric-pm
helm uninstall onap-parts
helm uninstall kafka
helm uninstall databases
helm uninstall keycloak
kubectl delete pvc data-keycloak-postgresql-0
kubectl delete pv local-pv
