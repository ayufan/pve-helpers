#!/bin/bash

suspend_vm() {
	VMID="$1"

	VMSTATUS=$(qm status "$VMID")
	if [[ "$VMSTATUS" != "status: running" ]]; then
		echo "$VMID: Nothing to due, due to: $VMSTATUS."
		return 0
	fi

	VMCONFIG=$(qm config "$VMID")
	if ! qm guest cmd "$VMID" ping; then
		echo "$VMID: VM does not have Guest Agent enabled, unable to suspend."
		return 0
	fi

	echo "$VMID: Suspending..."
	qm guest cmd "$VMID" suspend-ram

	for i in $(seq 1 30); do
		VMSTATUS=$(qm status "$VMID")
		if [[ "$VMSTATUS" == "status: suspended" ]]; then
			echo "$VMID: Suspended."
			return 0
		fi

		echo "$VMID: Waiting for suspend: $VMSTATUS..."
		sleep 1s
	done

	echo "$VMID: Failed to suspend: $VMSTATUS."
	return 1
}

for i in /etc/pve/nodes/$(hostname)/qemu-server/*.conf; do
	VMID=$(basename "$i" .conf)
	suspend_vm "$VMID" &
done

wait
