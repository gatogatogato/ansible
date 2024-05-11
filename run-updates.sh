#!/bin/bash
RUNDIR=~transport/ansible/
INVENTORY=inventory.yaml
PARMS=""

ACTIONS="update_all_apt update_all_gem update_all_micro update_webservers_snap"

for ACTION in ${ACTIONS}; do
	ansible-playbook ${RUNDIR}/${ACTION}.yaml ${PARMS} -i ${RUNDIR}/${INVENTORY}
done
