#!/bin/bash

set -x

resume_vm() {
	VMID="$1"

	VMSTATUS=$(qm status "$VMID")
	VMCONFIG=$(qm config "$VMID")

	# We need to reset only when hostpci.*:
	if grep -q ^hostpci <(echo "$VMCONFIG"); then
		if [[ "$VMSTATUS" == "status: running" ]]; then
			echo "$VMID: Resetting as it has 'hostpci*:' devices..."
			qm reset "$VMID"
			return 1
		fi
	fi

	if [[ "$VMSTATUS" != "status: suspended" ]]; then
		echo "$VMID: Nothing to due, due to: $VMSTATUS."
		return 0
	fi

	echo "$VMID: Resuming..."
	qm resume "$VMID"

	for i in $(seq 1 30); do
		VMSTATUS=$(qm status "$VMID")
		if [[ "$VMSTATUS" == "status: running" ]]; then
			echo "$VMID: Resumed."
			return 0
		fi

		echo "$VMID: Waiting for resume: $VMSTATUS..."
		sleep 1s
	done

	echo "$VMID: Failed to resume: $VMSTATUS."
	qm reset "$VMID"
	return 1
}

for i in /etc/pve/nodes/$(hostname)/qemu-server/*.conf; do
	VMID=$(basename "$i" .conf)
	resume_vm "$VMID" &
done

wait
