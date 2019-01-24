#!/bin/bash

set -eo pipefail

sleep 3s

VMID="$1"

if ! grep -q "/etc/pve/qemu-server/$VMID.conf" "CPUPIN"; then
	echo "/etc/pve/qemu-server/$VMID.conf: does not have CPUPIN"
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
VCPUS=($(vm_cpu_tasks))
VCPU_COUNT="${#VCPUS[@]}"

if [[ $VCPU_COUNT -eq 0 ]]; then
	echo "* No VCPUS for $VMID"
	exit 1
fi

echo "* Detected ${#VCPUS[@]} assigned to VM$VMID..."

for CPU_INDEX in "${!VCPUS[@]}"
do
	CPU_TASK="${VCPUS[$CPU_INDEX]}"
	if read CPU_INDEX
		echo "* Assigning $CPU_INDEX to $CPU_TASK..."
		taskset -pc "$CPU_INDEX" "$CPU_TASK"
	else
		echo "* No CPU to assign to $CPU_TASK"
	fi
done < $(cores)
