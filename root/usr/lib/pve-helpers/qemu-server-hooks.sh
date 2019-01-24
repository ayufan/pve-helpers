#!/bin/bash

hooks=/etc/qemu-server-hooks
watch=/var/run/qemu-server

mkdir -p "$hooks" "$watch"

pin_vcpu() {
  /usr/lib/pve-helpers/pin-vcpu.sh "$@"
}

while read file; do
  VMID=$(basename "$file" .pid)

  # ignore non-pid matches
  if [[ "$file" == "$VMID" ]]; then
    continue
  fi

  if [[ -e "$watch/$file" ]]; then
    echo "* $VMID is up"
    [[ -f "$hooks/$VMID.up" ]] && "$hooks/$VMID.up"
    pin_vcpu "$VMID" &
  else
    echo "* $VMID is down"
    [[ -f "$hooks/$VMID.down" ]] && "$hooks/$VMID.down"
  fi
done < <(/usr/bin/inotifywait -mq -e create,delete --format "%f" "$watch")
