#!/bin/bash

IFS='
'

if [ -z $1 ]; then
	echo "ONAP component name missing"
	echo "Usage: ./cleanup.sh onap_component_name"
	exit 1
fi

COMPONENT=$1

if [ $COMPONENT == "dcae" ] || [ $COMPONENT == "DCAE" ]; then
	kubectl delete service consul -n onap
fi

if [ $COMPONENT == "sdc" ] || [ $COMPONENT == "SDC" ]; then
        for keyspace in sdctitan sdcrepository sdcartifact sdccomponent sdcaudit; do
	        kubectl exec -it dev-cassandra-cassandra-0 -- cqlsh -u cassandra -p cassandra -e "drop keyspace ${keyspace}"
        done
fi

for op in secrets configmaps pvc pv services deployments statefulsets clusterrolebinding; do
	ARRAY=(`kubectl get $op -n onap | grep dev-$COMPONENT | awk '{print $1}'`)
	for i in ${ARRAY[*]}; do
		kubectl delete $op -n onap $i
	done
done
