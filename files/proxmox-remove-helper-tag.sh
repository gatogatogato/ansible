#!/bin/bash
# Remove the tag "proxmox-helper-scripts" from all VMs and containers of this Proxmox node.
# Installed by ansible (proxmox_helper_tag.yaml), run weekly by /etc/cron.d. Only touches
# guests that carry the tag; other tags stay.

set -uo pipefail

readonly TAG="proxmox-helper-scripts"
failed=0

for tool in qm pct; do
    for id in $("${tool}" list | awk 'NR>1 {print $1}'); do
        tags=$("${tool}" config "${id}" | awk -F': ' '$1=="tags" {print $2}')
        [[ ";${tags};" == *";${TAG};"* ]] || continue
        newtags=$(echo "${tags}" | tr ';' '\n' | grep -vx "${TAG}" | paste -sd ';' -)
        if [[ -n "${newtags}" ]]; then
            "${tool}" set "${id}" --tags "${newtags}" || failed=1
        else
            "${tool}" set "${id}" --delete tags || failed=1
        fi
        echo "${tool} ${id}: removed tag ${TAG}"
    done
done

exit ${failed}
