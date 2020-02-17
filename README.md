# Proxmox VE Helpers

This repository is a set of scripts to better handle some of the Proxmox functions:

- automatically restart VMs on host suspend,
- allow to use CPU pinning,
- allow to set fifo scheduler

## Installation

Clone and compile the repository:

```bash
# install dependencies
sudo apt-get install -f ruby-dev
sudo gem install fpm
```

```bash
# compile pve-helpers
git clone https://github.com/ayufan/pve-helpers
cd pve-helpers
sudo make install
```

## Usage

### 1. Enable snippet

You need to configure each machine to enable the hookscript.

The snippet by default is installed in `/var/lib/vz`
that for Proxmox is present as `local`.

```bash
qm set 204 --hookscript=local:snippets/exec-cmds
```

### 2. Configure VM

Edit VM description and add a new line if one or both these two commands.

### 2.1. `cpu_taskset`

Check the `isolcpus`, but in general for the best performance
you want to assign VM to physical cores, not a mix of physical
and virtual cores.

For example for `i7-8700` each core has two threads: 0-6, 1-7, 2-8.
You can easily check that with `lscpu -e`, checking which cores are
assigned twice.

For example it is advised to assign a one CPU less than a number of
physical cores. For the `i7-8700` it will be 5 cores.

Then, you can assign the 5 cores (with CPU pinning, but not pinning specific
threads) to VM:

```text
cpu_taskset 7-11
```

This does assign to VM second thread of physical cores 1-6. We deliberatly
choose to not assign `CORE 0`.

If you have two VMs concurrently running, you can assign it on one thread,
second on another thread, like this:

```text
VM 1:
cpu_taskset 1-5

VM 2:
cpu_taskset 7-11
```

### 2.2. `cpu_chrt` (likely not needed)

Running virtualized environment always results in quite random latency
due to amount of other work being done. This is also, because Linux
hypervisor does balance all threads that has bad effects on `DPC`
and `ISR` execution times. Latency in Windows VM can be measured with https://www.resplendence.com/latencymon. Ideally, we want to have the latency of `< 300us`.

To improve the latency you can switch to the usage of `FIFO` scheduler.
This has a catastrophic effects to everything else that is not your VM,
but this is likely acceptable for Gaming / daily use of passthrough VMs.

Configure VM description with:

```text
cpu_chrt fifo 1
```

> Note:
> It seems that if Hyper-V entitlements (they are enabled for `ostype: win10`) are enabled this is no longer needed.
> I now have amazing performance without using `cpu_chrt`.

### 2.3. `pci_unbind` and `pci_rescan`

At least for AMD Radeon there's an ongoing problem with Reset bug when running
using VGA passthrough.

There are multiple approaches to handle Radeon graphics cards. I did find that
to make it stable:

1. VGA bios needs to be exported, put in `/usr/share/kvm` and passed as `romfile` of `hostpci*`,
2. PCIE unbind/rescan needs to happen.

Exporting bios should happen ideally when running "natively", so with graphics card available,
ideally on Windows, with `GPU-Z`. Once bios is exported, you should ensure that it
contains UEFI section: https://pve.proxmox.com/wiki/Pci_passthrough#How_to_known_if_card_is_UEFI_.28ovmf.29_compatible.
Sometimes the bios can be found on https://www.techpowerup.com/vgabios/.
Ensure that you find the exact one for you `vid:pid` of your graphics card.

This is how my config looks like once a bios is put in a correct place:

```yaml
cat /etc/pve/qemu-server/204.conf

## Fix VGA
#pci_rescan
#pci_unbind 02 00 0
#pci_unbind 02 00 1
...
hookscript: local:snippets/exec-cmds
...
hostpci0: 02:00,pcie=1,romfile=215895.rom,x-vga=1
...
machine: q35
...
```

The comment defines a commands to execute to unbind and rebind graphics card VM.

In cases where there are bugs in getting VM up, the `suspend/resume` cycle of Proxmox
helps: `systemctl suspend`.

### 2.4. `qm_conflict` and `qm_depends`

Sometimes some VMs are conflicting with each other due to dependency on the same resources,
like disks, or VGA.

There are helper commands to shutdown (the `qm_conflict`) or start (the `qm_depends`)
when main machine is being started.

```yaml
cat /etc/pve/qemu-server/204.conf

# qm_conflict 204
# qm_depends 207
...
```

This first `qm_conflict` will shuttdown VM with VMID 204 before starting the current one,
and it will also start VMID 207, that might be a sibiling VM.

I use the `qm_conflict` or `qm_depends` to run Linux VM sometimes with VGA passthrough,
sometimes as a sibiling VM without graphics cards passed, but running in a console mode.

Be careful if you use `pci_unbind` and `pci_rebind`, they should be after the `qm_*` commands.

#### 3. Using `isolcpus`

The option of `#cpu_taskset` can be used with conjuction to `isolcpus` of kernel.
This is a way to disable CPU cores from being used by hypervisor,
making it possible to assign cores exclusively to the VMs only.

For doing that edit `/etc/default/grub` and add:

```bash
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX isolcpus=1-5,7-11"
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX nohz_full=1-5,7-11"
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX rcu_nocbs=1-5,7-11"
```

Where `1-5,7-11` matches a cores that Proxmox VE should not use.
You really want to omit everything that is on CORE0.
The above specification is valid for latest `i7-8700` CPUs:

```bash
CPU NODE SOCKET CORE L1d:L1i:L2:L3 ONLINE MAXMHZ    MINMHZ
0   0    0      0    0:0:0:0       yes    4600.0000 800.0000
1   0    0      1    1:1:1:0       yes    4600.0000 800.0000
2   0    0      2    2:2:2:0       yes    4600.0000 800.0000
3   0    0      3    3:3:3:0       yes    4600.0000 800.0000
4   0    0      4    4:4:4:0       yes    4600.0000 800.0000
5   0    0      5    5:5:5:0       yes    4600.0000 800.0000
6   0    0      0    0:0:0:0       yes    4600.0000 800.0000
7   0    0      1    1:1:1:0       yes    4600.0000 800.0000
8   0    0      2    2:2:2:0       yes    4600.0000 800.0000
9   0    0      3    3:3:3:0       yes    4600.0000 800.0000
10  0    0      4    4:4:4:0       yes    4600.0000 800.0000
11  0    0      5    5:5:5:0       yes    4600.0000 800.0000
```

For Ryzen CPUs you will rather see CORE0 to be assigned
to CPU0 and CPU1, thus your specification will look `2-11`.

After editing configuration `update-grub` and reboot Proxmox VE.

> Note: I have amazing performance without using `isolcpus`.

### 4. Suspend/resume

There's a set of scripts that try to perform restart of machines
when Proxmox VE machine goes to sleep.

First, you might be interested in doing `suspend` on power button.
Edit the `/etc/systemd/logind.conf` to modify:

```text
HandlePowerKey=suspend
```

Then `systemctl restart systemd-logind.service` or reboot Proxmox VE.

After that every of your machines should restart alongside with Proxmox VE
suspend, thus be able to support restart on PCI passthrough devices,
like GPU.

**Ensure that each of your machines does support Qemu Guest Agent**.
This function will not work if you don't have Qemu Guest Agent installed
and running.

### 5. My setup

Here's a quick rundown of my environment that I currently use
with above quirks.

#### 5.1. Hardware

- i7-8700
- 48GB DDR4
- Intel iGPU used by Proxmox VE
- AMD RX560 2GB used by Linux VM
- GeForce RTX 2080 Super used by Windows VM
- Audio is being output by both VMs to the shared speakers that are connected to Motherboard audio card
- Each VM has it's own dedicated USB controller
- Each VM has a dedicated amount of memory using 1G hugepages
- Each VM does not use SMT, rather it is assigned to the thread 0 (Linux) or thread 1 (Windows) of each CPU, having only 5 vCPUs available to VM

#### 5.2. Kernel config

```text
GRUB_CMDLINE_LINUX=""
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX pci_stub.ids=10de:1e81,10de:10f8,10de:1ad8,10de:1ad9,10de:13c2,10de:0fbb,1002:67ef,1002:aae0"
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX intel_iommu=on kvm_intel.ept=Y kvm_intel.nested=Y i915.enable_hd_vgaarb=1 pcie_acs_override=downstream vfio-pci.disable_idle_d3=1"
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX cgroup_enable=memory swapaccount=1"
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX pcie_aspm=force pcie_aspm.policy=powersave modprobe.blacklist=nouveau,amdgpu"
# it seems that isolcpus does not make a lot of difference when you use `cpu_chrt`, `cpu_taskset` and `intel_pstate=disable`
#GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX isolcpus=1-5,7-11 nohz_full=1-5,7-11 rcu_nocbs=1-5,7-11"
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX intel_pstate=disable"
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX net.ifnames=1 biosdevname=1 acpi=force i915.alpha_support=1 i915.enable_gvt=1"
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX hugepagesz=1G hugepages=42"
```

#### 5.3. Linux VM

I use Linux for regular daily development work.

My Proxmox VE config looks like this:

```text
## CPU PIN
#cpu_taskset 0-5
#
## Fix VGA
#pci_rescan
#pci_unbind 02 00 0
#pci_unbind 02 00 1
#
## Conflict (207 shares disks, 208 shares VGA)
#qm_conflict 207
#qm_conflict 208
agent: 1
args: -audiodev id=alsa,driver=alsa,out.period-length=100000,out.frequency=48000,out.channels=2,out.try-poll=off,out.dev=swapped -soundhw hda
balloon: 0
bios: ovmf
boot: dcn
bootdisk: scsi0
cores: 5
cpu: host
hookscript: local:snippets/exec-cmds
hostpci0: 02:00,romfile=215895.rom,x-vga=1
hostpci1: 04:00
hostpci2: 00:14.0
hugepages: 1024
ide2: none,media=cdrom
memory: 32768
name: ubuntu19-vga
net0: virtio=32:13:40:C7:31:4C,bridge=vmbr0
numa: 1
onboot: 1
ostype: l26
scsi0: nvme-thin:vm-206-disk-1,discard=on,iothread=1,size=200G,ssd=1
scsi1: ssd:vm-206-disk-0,discard=on,iothread=1,size=100G,ssd=1
scsi10: ssd:vm-206-disk-1,iothread=1,replicate=0,size=32G,ssd=1
scsihw: virtio-scsi-pci
serial0: socket
sockets: 1
usb0: host=1050:0406
vga: none
```

#### 5.4. Windows VM

I use Windows for Gaming. It has dedicated RTX 2080 Super.

```text
## CPU PIN
#cpu_taskset 6-11
agent: 1
args: -audiodev id=alsa,driver=alsa,out.period-length=100000,out.frequency=48000,out.channels=2,out.try-poll=off,out.dev=swapped -soundhw hda
balloon: 0
bios: ovmf
boot: dc
bootdisk: scsi0
cores: 5
cpu: host
cpuunits: 10000
efidisk0: nvme-thin:vm-204-disk-1,size=4M
hookscript: local:snippets/exec-cmds
hostpci0: 01:00,pcie=1,x-vga=1,romfile=Gigabyte.RTX2080Super.8192.190820.rom
hugepages: 1024
ide2: none,media=cdrom
machine: pc-q35-3.1
memory: 10240
name: win10-vga
net0: e1000=3E:41:0E:4D:3D:14,bridge=vmbr0
numa: 1
onboot: 1
ostype: win10
runningmachine: pc-q35-3.1
scsi0: ssd:vm-204-disk-2,discard=on,iothread=1,size=64G,ssd=1
scsi1: ssd:vm-204-disk-0,backup=0,discard=on,iothread=1,replicate=0,size=921604M
scsi3: nvme-thin:vm-204-disk-0,backup=0,discard=on,iothread=1,replicate=0,size=100G
scsihw: virtio-scsi-pci
sockets: 1
vga: none
```

#### 5.5. Switching between VMs

To switch between VMs:

1. Both VMs always run concurrently.
1. I do change the monitor input.
1. Audio is by default being output by both VMs, no need to switch it.
1. I use Barrier (previously Synergy) for most of time.
1. In other cases I have Logitech multi-device keyboard and mouse,
   so I switch it on keyboard.
1. I also have a physical switch that I use
   to change lighting and monitor inputs.
1. I have the monitor with PBP and PIP, so I can watch how Windows
   is updating while doing development work on Linux.

## Author, License

Kamil Trzciński, 2019-2020, MIT
