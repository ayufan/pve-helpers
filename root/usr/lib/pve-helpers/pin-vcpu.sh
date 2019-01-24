#!/bin/bash

set -eo pipefail

if [[ $# -ne 1 ]]; then
	echo "usage: $0 <VMID>"
	exit 1
fi

VMID="$1"

if ! grep -q "CPUPIN" "/etc/pve/nodes/$(hostname)/qemu-server/$VMID.conf"; then
	echo "/etc/pve/nodes/$(hostname)/qemu-server/$VMID.conf: does not have CPUPIN"
	exit 1
fi

vm_cpu_tasks() {
	expect <<EOF | sed -n 's/^.* CPU .*thread_id=\(.*\)$/\1/p' | tr -d '\r' || true
spawn qm monitor $VMID
expect ">"
send "info cpus\r"
expect ">"
EOF
}

cores() {
	# tail -n+2: ignore header
	# sort -n -k4: sort by core-index
	# ignore core-0: assuming that it is assigned to host with isolcpus
	while read CPU NODE SOCKET CORE REST; do
		if [[ "$CORE" == "0" ]]; then
			continue
		fi

		echo "$CPU"
	done < <(lscpu -e | tail -n+2 | sort -n -k4)
}

echo Checking $VMID...

for i in $(seq 1 10); do
	if [[ "$(qm status $VMID)" != "status: running" ]]; then
		echo "* VM $VMID is not running"
		exit 1
	fi

	VCPUS=($(vm_cpu_tasks))
	VCPU_COUNT="${#VCPUS[@]}"

	if [[ $VCPU_COUNT -gt 0 ]]; then
		break
	fi

	echo "* No VCPUS for $VMID"
	sleep 3s
done

if [[ $VCPU_COUNT -eq 0 ]]; then
	exit 1
fi

echo "* Detected ${#VCPUS[@]} assigned to VM$VMID..."

for CPU_INDEX in "${!VCPUS[@]}"; do
	CPU_TASK="${VCPUS[$CPU_INDEX]}"
	if read CPU_INDEX; then
		echo "* Assigning $CPU_INDEX to $CPU_TASK..."
		taskset -pc "$CPU_INDEX" "$CPU_TASK"
	else
		echo "* No CPU to assign to $CPU_TASK"
	fi
done < <(cores)
