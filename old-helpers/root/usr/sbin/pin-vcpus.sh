#!/bin/bash

set -eo pipefail

if [[ $# -ne 1 ]]; then
	echo "Usage: $0 <VMID>"
	exit 1
fi

VMID="$1"

if ! VMCONFIG=$(qm config "$VMID"); then
	echo "$VMID: Does not exist."
	exit 1
fi

if ! grep -q CPUPIN <(echo "$VMCONFIG"); then
	echo "$VMID: Does not have CPUPIN defined."
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

# this functions returns a list of CPU cores
# in order as they have HT threads
# mapping Intel cpus to Qemu emulated cpus
cores() {
	# tail -n+2: ignore header
	# sort -n -k4: sort by core-index vs threads
	# ignore core-0: assuming that it is assigned to host with isolcpus
	while read CPU NODE SOCKET CORE REST; do
		if [[ "$CORE" == "0" ]]; then
			# We assume that $CORE is assigned to host (always)
			continue
		fi

		echo "$CPU"
	done < <(lscpu -e | tail -n+2 | sort -n -k4)
}

echo "$VMID: Checking..."

for i in $(seq 1 10); do
	VMSTATUS=$(qm status $VMID)
	if [[ "$VMSTATUS" != "status: running" ]]; then
		echo "$VMID: VM is not running: $VMSTATUS"
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

echo "$VMID: Detected VCPU ${#VCPUS[@]} threads..."

for CPU_INDEX in "${!VCPUS[@]}"; do
	CPU_TASK="${VCPUS[$CPU_INDEX]}"
	if read CPU_INDEX; then
		echo "$VMID: Assigning $CPU_INDEX to $CPU_TASK..."
		taskset -pc "$CPU_INDEX" "$CPU_TASK"
	else
		echo "$VMID: No CPU to assign to $CPU_TASK"
	fi
done < <(cores)
