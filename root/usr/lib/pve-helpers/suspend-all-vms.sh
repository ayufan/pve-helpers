#!/bin/bash

set -x

suspend_vm() {
	VMID="$1"

	if [[ "$(qm status $VMID)" != "status: running" ]]; then
		return 0
	fi

	qm suspend "$VMID"

	for i in $(seq 1 20); do
		if [[ "$(qm status $VMID)" == "status: suspended" ]]; then
			return 0
		fi
		sleep 3s
	done

	echo "$VMID: Failed to suspend"
	return 1
}

for i in /etc/pve/nodes/$(hostname)/qemu-server/*.conf; do
	VMID=$(basename "$i" .conf)
	suspend_vm "$VMID" &
done

wait
