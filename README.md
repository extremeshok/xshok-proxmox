# xshok-proxmox :: eXtremeSHOK.com Proxmox (pve)

## Optimization / Post Install Script (install-post.sh aka postinstall.sh) *run once*
*not required if server setup with install-hetzner.sh*
* 'reboot-quick' command which uses kexec to boot the latest kernel set in the boot loader
* Force APT to use IPv4
* Disable the enterprise repo, enable the public repo, Add non-free sources
* Fixes known bugs (public key missing, max user watches, etc)
* Update the system
* Install ceph, ksmtuned, openvswitch-switch, zfsutils and common system utilities
* Increase vzdump backup speed, enable pigz and fix ionice
* Increase max Key limits,  max user watches, max File Discriptor Limits, ulimits
* Detect AMD EPYC CPU and install kernel 4.15
* Detect AMD EPYC CPU and Apply EPYC fixes to kernel and KVM
* Install and configure ZFS-auto-snapshots (12x5min, 7daily, 4weekly, 3monthly)
* Disable portmapper / rpcbind (security)
* set-timezone UTC and enable timesyncd as nntp client
* Set pigz to replace gzip, 2x faster gzip compression
* Detect OVH Server and install OVH RTM (real time monitoring)"
* Protect the webinterface with fail2ban (security)
* Optimize ZFS arc size depending on installed memory, Use 1/16 RAM for MAX cache, 1/8 RAM for MIN cache, or 1GB
* ZFS Tuning, set prefetch method and max write speed to l2arc
* Enable TCP BBR congestion control, improves overall network throughput

https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/install-post.sh

return value is 0

Or run *install-post.sh* after installation

```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/install-post.sh -c -O install-post.sh && bash install-post.sh && rm install-post.sh
```

## Install Proxmox Recommendations
Recommeneded partitioning scheme:
* Raid 1 (mirror) 40 000MB ext4 /
* Raid 1 (mirror) 30 000MB ext4 /xshok/zfs-cache *only create if an ssd and there is 1+ unused hdd which will be made into a zfspool*
* Raid 1 (mirror) 5 000MB ext4 /xshok/zfs-slog *only create if an ssd and there is 1+ unused hdd which will be made into a zfspool*
* SWAP
* * HDD less than 130gb = 16GB swap
* * HDD more than 130GB and RAM less than 64GB = 32GB swap
* * HDD more than 130GB and RAM more than 64GB = 64GB swap
* Remaining for lv	xfs	/var/lib/vz (LVM)

# Hetzner Proxmox Installation Guide #
*includes and runs the  (install-post.sh) script*
* Select the Rescue tab for the specific server, via the hetzner robot manager
* * Operating system=Linux
* * Architecture=64 bit
* * Public key=*optional*
* --> Activate rescue system
* Select the Reset tab for the specific server,
* Check: Execute an automatic hardware reset
* --> Send
* Wait a few mins
* Connect via ssh/terminal to the rescue system running on your server and run the following
````
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/install-hetzner.sh -c -O install-hetzner.sh && chmod +x install-hetzner.sh
./install-hetzner.sh
````
* Reboot
* Connect via ssh/terminal to the new Proxmox system running on your server and run the following
## LVM to ZFS
````
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/lvm-2-zfs.sh -c -O lvm-2-zfs.sh  && chmod +x lvm-2-zfs.sh
 ./lvm-2-zfs.sh && rm lvm-2-zfs.sh
````
* Reboot
* Connect via ssh/terminal to the new Proxmox system running on your server and run the following
## NETWORKING (vmbr0 vmbr1)
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/network-configure.sh -c -O network-configure.sh && chmod +x network-configure.sh
./network-configure.sh && rm network-configure.sh
```
* Reboot
* Post Install: Now login via ssh as root and create a password, which will be used for the webinterface when logging in with pam authentication

# OVH Proxmox Installation Guide #
Select install for the specific server, via the ovh manager
* --INSTALL-->
* Install from an OVH template
* --NEXT-->
* Type of OS: Ready-to-go (graphical user interface)
* VPS Proxmox VE *(pick the latest non zfs version)*
* Language: EN
* Target disk arrray: *(always select the SSD array if you have ssd and hdd arrays)*
* Enable/Tick: Customise the partition configuration
* --NEXT-->
* Disks used for this installation: *(All of them)*
* (Remove all the partitions and do the following)
* Type: Filesystem: Mount Point: LVM Name: RAID: Size:
* * 1	primary	Ext4	/	 -	1	20.0 GB
* * 2	primary	Swap	swap -	-	2 x 8.0 GB	*(minimum 16GB total, set recommended swap size)*
* * 3	LV	xfs	/var/lib/vz	data	1	REMAINING GB *(use all the remaining space)*
* --NEXT-->
* Hostname: server.fqdn.com
* Installation script (URL): https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/install-post.sh
* Script return value: 0
* SSH keys: *(always suggested, however if this value is used a webinterface login will not work without setting a root password in shell)*
* --CONFIRM-->
After installation, Connect via ssh/terminal to the new Proxmox system running on your server and run the following
## LVM to ZFS
````
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/lvm-2-zfs.sh -c -O lvm-2-zfs.sh  && chmod +x lvm-2-zfs.sh
 ./lvm-2-zfs.sh && rm lvm-2-zfs.sh
````
* Reboot
* Connect via ssh/terminal to the new Proxmox system running on your server and run the following
## NETWORKING (vmbr0 vmbr1)
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/network-configure.sh -c -O network-configure.sh && chmod +x network-configure.sh
./network-configure.sh && rm network-configure.sh
```
* Reboot
* Post Install: Now login via ssh as root and create a password, which will be used for the webinterface when logging in with pam authentication

# Advance Installation Options #
Assumptions: Proxmox installed, SSD raid1 partitions mounted as /xshok/zfs-slog and /xshok/zfs-cache, 1+ unused hdd which will be made into a zfspool

* Connect via ssh/terminal to the new Proxmox system running on your server and run the follow
## Create ZFS from unused devices (createzfs.sh)

**NOTE: WILL  DESTROY ALL DATA ON SPECIFIED DEVICES**
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/createzfs.sh -c -O createzfs.sh && chmod +x createzfs.sh
./createzfs.sh poolname /dev/device1 /dev/device2
```
## Create ZFS cache and slog from /xshok/zfs-cache and /xshok/zfs-slog partitions and adds them to a zpool (xshok_slog_cache-2-zfs.sh) *optional*

**NOTE: WILL  DESTROY ALL DATA ON SPECIFIED PARTITIONS**
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/xshok_slog_cache-2-zfs.sh -c -O xshok_slog_cache-2-zfs.sh && chmod +x xshok_slog_cache-2-zfs.sh
./xshok_slog_cache-2-zfs.sh poolname
```
* Reboot

# ------- SCRIPTS ------

## Convert from Debian 9 to Proxmox 5 (debian9-2-proxmox5.sh) *optional*
Assumptions: Debian9 installed with a valid FQDN hostname set
* Tested on KVM, VirtualBox and Dedicated Server
* Will automatically detect cloud-init and disable.
* Will automatically generate a correct /etc/hosts
* Note: will automatically run the install-post.sh script
```
curl -O https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/debian9-2-proxmox5.sh && chmod +x debian9-2-proxmox5.sh
./debian9-2-proxmox5.sh
```

## Enable Docker support for an LXC container (pve-enable-lxc-docker.sh) *optional*
There can be security implications as the LXC container is running in a higher privileged mode.
```
curl https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/pve-enable-lxc-docker.sh --output /usr/sbin/pve-enable-lxc-docker && chmod +x /usr/sbin/pve-enable-lxc-docker
pve-enable-lxc-docker container_id
```

## Convert from LVM to ZFS (lvm-2-zfs.sh) *run once*
Converts the a MDADM BASED LVM into a ZFS raid 1 (mirror)
* Defaults to mount point: /var/lib/vz
* Optional: specify the LVM_MOUNT_POINT ( ./lvm-2-zfs.sh LVM_MOUNT_POINT )
* Creates the following storage/rpools
* zfsbackup (rpool/backup)
* zfsvmdata (rpool/vmdata)
* /var/lib/vz/tmp_backup (rpool/tmp_backup)
*
* Will automatically detect the required raid level and optimise.
* 1 Drive = zfs
* 2 Drives = mirror
* 3-5 Drives = raidz-1
* 6-11 Drives = raidz-2
* 11+ Drives = raidz-3

**NOTE: WILL  DESTROY ALL DATA ON LVM_MOUNT_POINT**
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/lvm-2-zfs.sh -c -O lvm-2-zfs.sh && chmod +x lvm-2-zfs.sh
./lvm-2-zfs.sh
```

## Create ZFS from devices (createzfs.sh) *optional*
Creates a zfs pool from specified devices
* Will automatically detect the required raid level and optimise
* 1 Drive = zfs (single)
* 2 Drives = mirror (raid1)
* 3-5 Drives = raidz-1 (raid5)
* 6-11 Drives = raidz-2 (raid6)
* 11+ Drives = raidz-3 (raid7)

**NOTE: WILL  DESTROY ALL DATA ON SPECIFIED DEVICES**
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/createzfs.sh -c -O createzfs.sh && chmod +x createzfs.sh
./createzfs.sh poolname /dev/device1 /dev/device2
```

## Create ZFS cache and slog from /xshok/zfs-cache and /xshok/zfs-slog partitions and adds them to a zpool (xshok_slog_cache-2-zfs.sh) *optional*
Creates a zfs pool from specified devices
* Will automatically mirror the slog and stripe the cache if there are multiple drives

**NOTE: WILL  DESTROY ALL DATA ON SPECIFIED PARTITIONS**
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/xshok_slog_cache-2-zfs.sh -c -O xshok_slog_cache-2-zfs.sh && chmod +x xshok_slog_cache-2-zfs.sh
./xshok_slog_cache-2-zfs.sh poolname
```

## CREATES A ROUTED vmbr0 AND NAT vmbr1 NETWORK CONFIGURATION FOR PROXMOX (network-configure.sh) **run once**
Autodetects the correct settings (interface, gatewat, netmask, etc)
Supports IPv4 and IPv6, Private Network uses 10.10.10.1/24
Also installs and properly configures the isc-dhcp-server to allow for DHCP on the vmbr1 (NAT)
ROUTED (vmbr0):
   All traffic is routed via the main IP address and uses the MAC address of the physical interface.
   VM's can have multiple IP addresses and they do NOT require a MAC to be set for the IP via service provider

 NAT (vmbr1):
   Allows a VM to have internet connectivity without requiring its own IP address
   Assignes 10.10.10.100 - 10.10.10.200 via DHCP

 Public IP's can be assigned via DHCP, adding a host define to the /etc/dhcp/hosts.public file

 Tested on OVH and Hetzner based servers

ALSO CREATES A NAT Private Network as vmbr1

 NOTE: WILL OVERWRITE /etc/network/interfaces
 A backup will be created as /etc/network/interfaces.timestamp
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/network-configure.sh -c -O network-configure.sh && chmod +x network-configure.sh
./network-configure.sh && rm network-configure.sh
```

##  Creates default routes to allow for extra ip ranges to be used (network-addiprange.sh) *optional*
If no interface is specified the default gateway interface will be detected and used.
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/network-addiprange.sh -c -O network-addiprange.sh && chmod +x network-addiprange.sh
./network-addiprange.sh ip.xx.xx.xx/cidr interface_optional
```

## Create Private mesh vpn/network (tincvpn.sh)
tinc private mesh vpn/network which supports multicast, ideal for private cluster communication
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/tincvpn.sh -c -O tincvpn.sh && chmod +x tincvpn.sh
./tincvpn.sh -h
```
### Example for 3 node Cluster
# cat /etc/hosts
# global ips for tinc servers
# 11.11.11.11 host1
# 22.22.22.22 host2
# 33.33.33.33 host3
#### First Host (hostname: host1)
```
bash tincvpn.sh -i 1 -c host2
```
#### Second Host (hostname: host2)
```
bash tincvpn.sh -i 2 -c host3
```
#### Third Host (hostname: host3)
```
bash tincvpn.sh -i 3 -c host1
```

# NOTES

## Alpine Linux KVM / Qemu Agent Client Fix
Run the following on the guest alpine linux
```
apk update && apk add qemu-guest-agent acpi
echo 'GA_PATH="/dev/vport2p1"' >> /etc/conf.d/qemu-guest-agent
rc-update add qemu-guest-agent default
rc-update add acpid default
/etc/init.d/qemu-guest-agent restart
```

## Proxmox ACME / Letsencrypt
Run the following on the proxmox server, ensure you have a valid DNS for the server which resolves
```
pvenode acme account register default mail@example.invalid
pvenode config set --acme domains=example.invalid
pvenode acme cert order
```

## ZFS Snapshot Usage
```
# list all snapshots
zfs list -t snapshot
# create a pre-rollback snapshot
zfs-auto-snapshot --verbose --label=prerollback -r //
# rollback to a specific snapshot
zfs rollback <snapshotname>
```
