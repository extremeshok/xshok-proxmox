# eXtremeSHOK.com Proxmox (pve) only for Hetzner

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

## For server with SATA Disk
````
wget https://raw.githubusercontent.com/CasCas2/proxmox6-hetzner/master/install-hetzner-sata.sh -c -O install-hetzner.sh && chmod +x install-hetzner.sh
./install-hetzner.sh "PVE Hostname"
````

## For server with NVME Disk
````
wget https://raw.githubusercontent.com/CasCas2/proxmox6-hetzner/master/install-hetzner-nvme.sh -c -O install-hetzner.sh && chmod +x install-hetzner.sh
./install-hetzner.sh "PVE Hostname"
````
* Reboot
* Connect via ssh/terminal to the new Proxmox system running on your server and run the following
## LVM to ZFS
````
wget https://raw.githubusercontent.com/CasCas2/xshok-proxmox/master/lvm-2-zfs.sh -c -O lvm-2-zfs.sh  && chmod +x lvm-2-zfs.sh
 ./lvm-2-zfs.sh && rm lvm-2-zfs.sh
````
* Reboot
* Connect via ssh/terminal to the new Proxmox system running on your server and run the following


# Advance Installation Options #
Assumptions: Proxmox installed, SSD raid1 partitions mounted as /xshok/zfs-slog and /xshok/zfs-cache, 1+ unused hdd which will be made into a zfspool

* Connect via ssh/terminal to the new Proxmox system running on your server and run the follow
## Create ZFS from unused devices (createzfs.sh)

**NOTE: WILL  DESTROY ALL DATA ON SPECIFIED DEVICES**
```
wget https://raw.githubusercontent.com/CasCas2/xshok-proxmox/master/createzfs.sh -c -O createzfs.sh && chmod +x createzfs.sh
./createzfs.sh poolname /dev/device1 /dev/device2
```
## Create ZFS cache and slog from /xshok/zfs-cache and /xshok/zfs-slog partitions and adds them to a zpool (xshok_slog_cache-2-zfs.sh) *optional*

**NOTE: WILL  DESTROY ALL DATA ON SPECIFIED PARTITIONS**
```
wget https://raw.githubusercontent.com/CasCas2/xshok-proxmox/master/xshok_slog_cache-2-zfs.sh -c -O xshok_slog_cache-2-zfs.sh && chmod +x xshok_slog_cache-2-zfs.sh
./xshok_slog_cache-2-zfs.sh poolname
```
* Reboot

# ------- SCRIPTS ------


## Enable Docker support for an LXC container (pve-enable-lxc-docker.sh) *optional*
There can be security implications as the LXC container is running in a higher privileged mode.
```
curl https://raw.githubusercontent.com/CasCas2/xshok-proxmox/master/pve-enable-lxc-docker.sh --output /usr/sbin/pve-enable-lxc-docker && chmod +x /usr/sbin/pve-enable-lxc-docker
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
wget https://raw.githubusercontent.com/CasCas2/xshok-proxmox/master/lvm-2-zfs.sh -c -O lvm-2-zfs.sh && chmod +x lvm-2-zfs.sh
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
wget https://raw.githubusercontent.com/CasCas2/xshok-proxmox/master/createzfs.sh -c -O createzfs.sh && chmod +x createzfs.sh
./createzfs.sh poolname /dev/device1 /dev/device2
```

## Create ZFS cache and slog from /xshok/zfs-cache and /xshok/zfs-slog partitions and adds them to a zpool (xshok_slog_cache-2-zfs.sh) *optional*
Creates a zfs pool from specified devices
* Will automatically mirror the slog and stripe the cache if there are multiple drives

**NOTE: WILL  DESTROY ALL DATA ON SPECIFIED PARTITIONS**
```
wget https://raw.githubusercontent.com/CasCas2/xshok-proxmox/master/xshok_slog_cache-2-zfs.sh -c -O xshok_slog_cache-2-zfs.sh && chmod +x xshok_slog_cache-2-zfs.sh
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
wget https://raw.githubusercontent.com/CasCas2/xshok-proxmox/master/network-configure.sh -c -O network-configure.sh && chmod +x network-configure.sh
./network-configure.sh && rm network-configure.sh
```

##  Creates default routes to allow for extra ip ranges to be used (network-addiprange.sh) *optional*
If no interface is specified the default gateway interface will be detected and used.
```
wget https://raw.githubusercontent.com/CasCas2/xshok-proxmox/master/network-addiprange.sh -c -O network-addiprange.sh && chmod +x network-addiprange.sh
./network-addiprange.sh ip.xx.xx.xx/cidr interface_optional
```

# NOTES

## ZFS Snapshot Usage (Diabled for now)
```
# list all snapshots
zfs list -t snapshot
# create a pre-rollback snapshot
zfs-auto-snapshot --verbose --label=prerollback -r //
# rollback to a specific snapshot
zfs rollback <snapshotname>
```
