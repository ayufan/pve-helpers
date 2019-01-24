#!/bin/bash

set -x

hooks=/etc/qemu-server-hooks
watch=/var/run/qemu-server

mkdir -p "$hooks" "$watch"

while read pid; do
  VMID=$(basename "$pid" .pid)
  if [[ -e "$watch/$pid" ]]; then
    [[ -f "$hooks/$VMID.up" ]] && "$hooks/$VMID.up"
  else
    [[ -f "$hooks/$VMID.down" ]] && "$hooks/$VMID.down"
  fi
done < <(/usr/bin/inotifywait -mq -e create,delete --format "%f" "$watch")
