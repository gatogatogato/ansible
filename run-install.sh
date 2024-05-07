#!/bin/bash
RUNDIR=~transport/ansible/
INVENTORY=inventory.yaml
PARMS=""

# TEST CHANGE

ACTIONS="install_all_packages install_webservers_packages install_flickrservers_packages"

for ACTION in ${ACTIONS}; do
	ansible-playbook ${RUNDIR}/${ACTION}.yaml ${PARMS} -i ${RUNDIR}/${INVENTORY}
done
