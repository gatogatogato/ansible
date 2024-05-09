#!/bin/bash
RUNDIR=~transport/ansible/
INVENTORY=inventory.yaml
PARMS=""

# TEST CHANGE

ACTIONS="cronjobs_webservers"

for ACTION in ${ACTIONS}; do
	ansible-playbook ${RUNDIR}/${ACTION}.yaml ${PARMS} -i ${RUNDIR}/${INVENTORY}
done
