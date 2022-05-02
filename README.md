# xshok-proxmox :: eXtremeSHOK.com Proxmox (pve)

Scripts for working with and optimizing proxmox

## Maintained and provided by <https://eXtremeSHOK.com>

### Please Submit Patches / Pull requests

## Optimization / Post Install Script (install-post.sh aka postinstall.sh) *run once*
Turns a fresh proxmox install into an optimised proxmox host
*not required if server setup with installimage-proxmox.sh*

'reboot-quick' command which uses kexec to boot the latest kernel, its a fast method of rebooting, without needing to do a hardware reboot

* Disable the enterprise repo, enable the public repo, Add non-free sources
* Fixes known bugs (public key missing, max user watches, etc)
* Update the system
* Detect AMD EPYC CPU and Apply Fixes
* Force APT to use IPv4
* Update proxmox and install various system utils
* Customise bashrc
* add the latest ceph provided by proxmox
* Disable portmapper / rpcbind (security)
* Ensure Entropy Pools are Populated, prevents slowdowns whilst waiting for entropy
* Protect the web interface with fail2ban
* Detect if is running in a virtual machine and install the relavant guest agent
* Install ifupdown2 for a virtual internal network allows rebootless networking changes (not compatible with openvswitch-switch)
* Limit the size and optimise journald
* Install kernel source headers
* Install kexec, allows for quick reboots into the latest updated kernel set as primary in the boot-loader.
* Ensure ksmtuned (ksm-control-daemon) is enabled and optimise according to ram size
* Set language, if chnaged will disable XS_NOAPTLANG
* Increase max user watches, FD limit, FD ulimit, max key limit, ulimits
* Optimise logrotate
* Lynis security scan tool by Cisofy
* Increase Max FS open files
* Optimise Memory
* Pretty MOTD BANNER
* Enable Network optimising
* Save bandwidth and skip downloading additional languages, requires XS_LANG="en_US.UTF-8"
* Disable enterprise proxmox repo
* Remove subscription banner
* Install openvswitch for a virtual internal network
* Detect if this is an OVH server and install OVH Real Time Monitoring
* Set pigz to replace gzip, 2x faster gzip compression
* Bugfix: high swap usage with low memory usage
* Enable TCP BBR congestion control
* Enable TCP fastopen
* Enable testing proxmox repo
* Automatically Synchronize the time
* Set Timezone, empty = set automatically by IP
* Install common system utilities
* Increase vzdump backup speed
* Optimise ZFS arc size accoring to memory size
* Install zfs-auto-snapshot

https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/install-post.sh

return value is 0

```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/install-post.sh -c -O install-post.sh && bash install-post.sh && rm install-post.sh
```

##  TO SET AND USE YOUR OWN OPTIONS (using xs-post-install.env)
User Defined Options for (install-post.sh) post-installation script for Proxmox are set in the xs-install-post.env, see the sample : xs-install-post.env.sample
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/xs-install-post.env.sample -c -O xs-install-post.env
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/install-post.sh -c -O install-post.sh
nano xs-install-post.env
bash install-post.sh
```
##  TO SET AND USE YOUR OWN OPTIONS (using ENV)
Examnple to disable the MOTD banner
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/install-post.sh -c -O install-post.sh
export XS_MOTD="no"
bash install-post.sh
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
see *hetzner* folder

# OVH Proxmox Installation Guide #
see *ovh* folder

# ------- SCRIPTS ------

## Convert from Debian 11 to Proxmox 7 (debian11-2-proxmox7.sh) *optional*
Assumptions: Debian11 installed with a valid FQDN hostname set
* Tested on KVM, VirtualBox and Dedicated Server
* Will automatically detect cloud-init and disable.
* Will automatically generate a correct /etc/hosts
* Note: will automatically run the install-post.sh script
```
curl -O https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/debian-2-proxmox/debian11-2-proxmox7.sh && chmod +x debian11-2-proxmox7.sh
./debian11-2-proxmox7.sh
```
## Convert from Debian 10 to Proxmox 6 (debian10-2-proxmox6.sh) *optional*
```
curl -O https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/debian-2-proxmox/debian10-2-proxmox6.sh && chmod +x debian10-2-proxmox6.sh
./debian10-2-proxmox6.sh
```
## Convert from Debian 9 to Proxmox 5 (debian9-2-proxmox5.sh) *optional*
```
curl -O https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/debian-2-proxmox/debian9-2-proxmox5.sh && chmod +x debian9-2-proxmox5.sh
./debian9-2-proxmox5.sh
```

## Enable Docker support for an LXC container (pve-enable-lxc-docker.sh) *optional*
There can be security implications as the LXC container is running in a higher privileged mode.
```
curl https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/helpers/pve-enable-lxc-docker.sh --output /usr/sbin/pve-enable-lxc-docker && chmod +x /usr/sbin/pve-enable-lxc-docker
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
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/zfs/lvm-2-zfs.sh -c -O lvm-2-zfs.sh && chmod +x lvm-2-zfs.sh
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
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/zfs/createzfs.sh -c -O createzfs.sh && chmod +x createzfs.sh
./createzfs.sh poolname /dev/device1 /dev/device2
```

## Create ZFS cache and slog from /xshok/zfs-cache and /xshok/zfs-slog partitions and adds them to a zpool (xshok_slog_cache-2-zfs.sh) *optional*
Creates a zfs pool from specified devices
* Will automatically mirror the slog and stripe the cache if there are multiple drives

**NOTE: WILL  DESTROY ALL DATA ON SPECIFIED PARTITIONS**
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/zfs/xshok_slog_cache-2-zfs.sh -c -O xshok_slog_cache-2-zfs.sh && chmod +x xshok_slog_cache-2-zfs.sh
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
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/networking/network-configure.sh -c -O network-configure.sh && chmod +x network-configure.sh
./network-configure.sh && rm network-configure.sh
```

##  Creates default routes to allow for extra ip ranges to be used (network-addiprange.sh) *optional*
If no interface is specified the default gateway interface will be detected and used.
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/networking/network-addiprange.sh -c -O network-addiprange.sh && chmod +x network-addiprange.sh
./network-addiprange.sh ip.xx.xx.xx/cidr interface_optional
```

## Create Private mesh vpn/network (tincvpn.sh)
tinc private mesh vpn/network which supports multicast, ideal for private cluster communication
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/networking/tincvpn.sh -c -O tincvpn.sh && chmod +x tincvpn.sh
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
