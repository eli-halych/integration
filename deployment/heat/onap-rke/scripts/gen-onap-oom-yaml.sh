#!/bin/bash
#
# Copyright 2018 Huawei Technologies Co., Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#

if [ "$#" -ne 1 ]; then
    echo This script generates the HEAT template for X number of k8s VMs
    echo "$0 <num k8s vms>"
    exit 1
fi
NUM_K8S_VMS=$1

if [ -z "$WORKSPACE" ]; then
    export WORKSPACE=`git rev-parse --show-toplevel`
fi
PARTS_DIR=$WORKSPACE/deployment/heat/onap-rke/parts

cat <<EOF
#
# Generated by scripts/gen-onap-oom-yaml.sh; MANUAL CHANGES WILL BE LOST
#
EOF

cat $PARTS_DIR/onap-oom-1.yaml

cat <<EOF
  rancher_vm:
    type: OS::Nova::Server
    properties:
      name:
        list_join: ['-', [{ get_param: 'OS::stack_name' }, 'rancher']]
      image: { get_param: ubuntu_1804_image }
      flavor: { get_param: rancher_vm_flavor }
      key_name: { get_param: key_name }
      networks:
      - port: { get_resource: rancher_private_port }
      user_data_format: RAW
      user_data:
        str_replace:
          template:
            get_file: rancher_vm_entrypoint.sh
          params:
            __docker_proxy__: { get_param: docker_proxy }
            __apt_proxy__: { get_param: apt_proxy }
            __rancher_ip_addr__: { get_attr: [rancher_floating_ip, floating_ip_address] }
            __rancher_private_ip_addr__: { get_attr: [rancher_floating_ip, fixed_ip_address] }
            __integration_override_yaml__: { get_param: integration_override_yaml }
            __integration_gerrit_branch__: { get_param: integration_gerrit_branch }
            __integration_gerrit_refspec__: { get_param: integration_gerrit_refspec }
            __oom_gerrit_branch__: { get_param: oom_gerrit_branch }
            __oom_gerrit_refspec__: { get_param: oom_gerrit_refspec }
            __docker_manifest__: { get_param: docker_manifest }
            __docker_version__: { get_param: docker_version }
            __kubectl_version__: { get_param: kubectl_version }
            __helm_version__: { get_param: helm_version }
            __helm_deploy_delay__: { get_param: helm_deploy_delay }
            __use_ramdisk__: { get_param: use_ramdisk }
            __mtu__: { get_param: mtu }
            __portal_hostname__: { get_param: portal_hostname }
            __public_net_id__: { get_param: public_net_id }
            __oam_network_cidr__: { get_param: oam_network_cidr }
            __oam_network_id__: { get_resource: oam_network }
            __oam_subnet_id__: { get_resource: oam_subnet }
            __sec_group__: { get_resource: onap_sg }
            __k8s_01_vm_ip__: { get_attr: [k8s_01_floating_ip, floating_ip_address] }
            __k8s_vm_ips__: [
EOF

for VM_NUM in $(seq -f %02g $NUM_K8S_VMS); do
    K8S_VM_NAME=k8s_$VM_NUM
    cat <<EOF
              get_attr: [${K8S_VM_NAME}_floating_ip, floating_ip_address],
EOF
done

cat <<EOF
            ]
            __k8s_private_ips__: [
EOF

for VM_NUM in $(seq -f %02g $NUM_K8S_VMS); do
    K8S_VM_NAME=k8s_$VM_NUM
    cat <<EOF
              get_attr: [${K8S_VM_NAME}_floating_ip, fixed_ip_address],
EOF
done

cat <<EOF
            ]
EOF

for VM_NUM in $(seq -f %02g $NUM_K8S_VMS); do
    VM_TYPE=k8s HOST_LABEL=compute VM_NUM=$VM_NUM envsubst < $PARTS_DIR/onap-oom-2.yaml
done

for VM_NUM in $(seq 3); do
    VM_TYPE=orch HOST_LABEL=orchestration VM_NUM=$VM_NUM envsubst < $PARTS_DIR/onap-oom-2.yaml
done


cat $PARTS_DIR/onap-oom-3.yaml

for VM_NUM in $(seq -f %02g $NUM_K8S_VMS); do
    K8S_VM_NAME=k8s_$VM_NUM
    cat <<EOF
  ${K8S_VM_NAME}_vm_ip:
    description: The IP address of the ${K8S_VM_NAME} instance
    value: { get_attr: [${K8S_VM_NAME}_floating_ip, floating_ip_address] }

  ${K8S_VM_NAME}_vm_private_ip:
    description: The private IP address of the ${K8S_VM_NAME} instance
    value: { get_attr: [${K8S_VM_NAME}_floating_ip, fixed_ip_address] }

EOF
done

for VM_NUM in $(seq 3); do
    K8S_VM_NAME=orch_$VM_NUM
    cat <<EOF
  ${K8S_VM_NAME}_vm_ip:
    description: The IP address of the ${K8S_VM_NAME} instance
    value: { get_attr: [${K8S_VM_NAME}_floating_ip, floating_ip_address] }

  ${K8S_VM_NAME}_vm_private_ip:
    description: The private IP address of the ${K8S_VM_NAME} instance
    value: { get_attr: [${K8S_VM_NAME}_floating_ip, fixed_ip_address] }

EOF
done