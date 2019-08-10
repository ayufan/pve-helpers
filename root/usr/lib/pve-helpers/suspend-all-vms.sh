#!/bin/bash

suspend_vm_action() {
	local VMID="$1"
	local ACTION="$2"

	if ! qm guest cmd "$VMID" ping; then
		return 1
	fi

	echo "$VMID: Suspending ($ACTION)..."
	qm guest cmd "$VMID" "$ACTION"

	for i in $(seq 1 30); do
		local VMSTATUS=$(qm status "$VMID")
		if [[ "$VMSTATUS" == "status: suspended" ]] || [[ "$VMSTATUS" == "status: stopped" ]]; then
			echo "$VMID: Suspended."
			touch "/var/run/qemu-server/$VMID.suspended"
			return 0
		fi

		echo "$VMID: Waiting for suspend: $VMSTATUS..."
		sleep 1s
	done

	echo "$VMID: Failed to suspend: $VMSTATUS."
	return 1
}

suspend_vm() {
	local VMID="$1"

	local VMSTATUS=$(qm status "$VMID")
	local VMCONFIG=$(qm config "$VMID")

	if [[ "$VMSTATUS" != "status: running" ]]; then
		echo "$VMID: Nothing to due, due to: $VMSTATUS."
		return 0
	fi

	if ! grep -q ^hostpci <(echo "$VMCONFIG"); then
		echo "$VMID: VM does not use PCI-passthrough"
		return 0
	fi

	# if suspend_vm_action "$VMID" suspend-disk; then
	# 	return 0
	# fi

	# echo "$VMID: VM does not support suspend-disk via Guest Agent, using shutdown."

	if qm shutdown "$VMID"; then
		touch "/var/run/qemu-server/$VMID.suspended"
		return 0
	fi

	echo "$VMID: Failed to suspend or shutdown."
	return 1
}

for i in /etc/pve/nodes/$(hostname)/qemu-server/*.conf; do
	VMID=$(basename "$i" .conf)
	suspend_vm "$VMID" &
done

wait
