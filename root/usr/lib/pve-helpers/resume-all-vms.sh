#!/bin/bash

set -x

resume_vm() {
	VMID="$1"

	if [[ "$(qm status $VMID)" == "status: running" ]]; then
		# We need to reset only when hostpci.*:
		if qm config $VMID | grep -q ^hostpci; then
			qm reset "$VMID"
			return 1
		fi

		return 0
	fi

	if [[ "$(qm status $VMID)" != "status: suspended" ]]; then
		return 0
	fi

	qm resume "$VMID"

	for i in $(seq 1 10); do
		if [[ "$(qm status $VMID)" == "status: running" ]]; then
			return 0
		fi
		sleep 3s
	done

	echo "Failed to resume $VMID"
	qm reset "$VMID"
	return 1
}

for i in /etc/pve/nodes/$(hostname)/qemu-server/*.conf; do
	VMID=$(basename "$i" .conf)
	resume_vm "$VMID" &
done

wait
