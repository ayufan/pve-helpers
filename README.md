# Proxmox VE Qemu Helpers

This repository is a set of scripts to better handle some of the Proxmox functions:

- automatically suspend/resume on host suspend,
- allow to use CPU pinning,
- allow to run actions on VM bootup

## Installation

Clone and compile the repository:

```bash
git clone https://github.com/ayufan/pve-helpers
cd pve-helpers
sudo make install
```

## Usage

### 1. Enable CPU pinning (`/usr/sbin/pin-vcpus.sh`)

The CPU pinning is enabled only when you add in notes the `CPUPIN` keyword.
It will pin each CPU thread to one physical thread.
The pinning will omit the CORE0 as it assumes that you use it
for the purpose of the host machine.

For the best performance you should configure cores specification
exactly the way as they are on your host machine: matching number of threads per-core.

Currently, Proxmox VE does not allow you to configure `threads`, so you have to do it manually:

```bash
qm set VMID -args -smp 10,cores=5,threads=2
```

The above assume that you use CPU with SMT, which has two threads per-each core.
The CPU pinning method will properly assign each virtual thread to physical thread taking
into account CPUs affinity mask as produced by `lscpu -e`.

To ensure that CPU pinning does work,
you can try it from command line as `root` user:

```bash
pin-vcpus.sh VMID
```

#### 1.1. Using `isolcpus`

The above option should be used with conjuction to `isolcpus` of kernel.
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

### 2. Suspend/resume

There's a set of scripts that try to perform shutdown of machines
when Proxmox VE machine goes to sleep.

First, you might be interested in doing `suspend` on power button.
Edit the `/etc/systemd/logind.conf` to modify:

```
HandlePowerKey=suspend
```

Then `systemctl restart systemd-logind.service` or reboot Proxmox VE.

After that every of your machines should shutdown alongside with Proxmox VE
suspend, thus be able to support restart on PCI passthrough devices,
like GPU.

**Ensure that each of your machines does support Qemu Guest Agent**.
This function will not work if you don't have Qemu Guest Agent installed
and running.

**Ensure that all machines does have hibernation**.

### 3. Run hooks on machine start and stop

This allows you to add a script `/etc/qemu-server-hooks/VMID.up` that
will be executed when machine starts.

This allows you to add a script `/etc/qemu-server-hooks/VMID.down` that
will be executed when machine stops.

## Author, License

Kamil Trzciński, 2019, MIT
