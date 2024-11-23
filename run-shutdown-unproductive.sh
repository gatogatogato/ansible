#!/bin/bash
RUNDIR=~transport/ansible/
INVENTORY=inventory.yaml
PARMS=""

ACTIONS="shutdown_unproductive"

for ACTION in ${ACTIONS}; do
	ansible-playbook ${RUNDIR}/${ACTION}.yaml ${PARMS} -i ${RUNDIR}/${INVENTORY}
done
