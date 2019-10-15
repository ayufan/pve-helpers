#!/bin/bash

resume_vm() {
	local VMID="$1"

	local VMSTATUS=$(qm status "$VMID")
	local VMCONFIG=$(qm config "$VMID")

	# We need to reset only when hostpci.*:
	if grep -q ^hostpci <(echo "$VMCONFIG"); then
		if [[ "$VMSTATUS" == "status: running" ]]; then
			echo "$VMID: Resetting as it has 'hostpci*:' devices..."
			qm reset "$VMID"
			return 1
		fi
	fi

	if [[ ! -e "/var/run/qemu-server/$VMID.suspended" ]]; then
		echo "$VMID: Nothing to due, due to missing: $VMID.suspended."
		return 0
	fi

	rm -f "/var/run/qemu-server/$VMID.suspended"

	if [[ "$VMSTATUS" == "status: stopped" ]]; then
		echo "$VMID: Starting (stopped)..."
		qm start "$VMID"
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
