#!/bin/bash
RUNDIR=~transport/ansible/
INVENTORY=inventory.yaml
PARMS=""

echo "* * * * * * * * * * * * * * * * * * * * * * * *"
echo "*                                             *"
echo "*    Shutting down non-productive servers!    *"
echo "*                                             *"
echo "* * * * * * * * * * * * * * * * * * * * * * * *"

ACTIONS="shutdown_unproductive"

for ACTION in ${ACTIONS}; do
	ansible-playbook ${RUNDIR}/${ACTION}.yaml ${PARMS} -i ${RUNDIR}/${INVENTORY}
done
