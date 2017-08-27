# xshok-proxmox :: proxmox post installation scripts

## Install Proxmox
Recommeneded partitioning scheme:
* Raid 1 (mirror) 20 000MB ext4 /
* 2x swap 8192mb (16GB total)
* Remaining for lv	ext3	/var/lib/vz (LVM)

# OVH Proxmox Installation Guide #
````
Select install for the specific server, via the ovh manager
--INSTALL-->
Install from an OVH template
--NEXT-->
Type of OS: Ready-to-go (graphical user interface)
VPS Proxmox VE **(pick the latest non zfs version)**
Language: EN
Target disk arrray: **(always select the SSD array if you have ssd and hdd arrays)
Enable/Tick: Customise the partition configuration
--NEXT-->
Disks used for this installation: **(All of them)
(Remove all the partitions and do the following)
Type: Filesystem: Mount Point: LVM Name: RAID: Size:
 1	primary	Ext4	/	 -	1	20.0 GB
 2	primary	Swap	swap -	-	2 x 8.0 GB	**(minimum 16GB total, recommended 50% ram)
 3	LV	Ext4	/var/lib/vz	data	1	REMAINING GB **(use all the remaining space)
--NEXT-->
Hostname: server.fqdn.com
Installation script (URL): https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/postinstall.sh
Script return value: 1
SSH keys: **(always suggested, however if this value is used a webinterface login will not work without setting a root password in shell)
--CONFIRM-->
After installation, login via ssh as root and create a password, which will be used for the webinterface when logging in with pam authentication
````
# Post Install Script (postinstall.sh) *run once*
* Disables the enterprise repo, enables the public repo
* Adds non-free sources
* Adds the latest ceph
* Fixes known bugs (public key missing, max user watches, etc)
* Updates the system
* Installs openvswitch-switch, zfsutils and common system utilities
* Protects the webinterface with fail2ban
* Increase vzdump backup speed
* Increase max File Discriptor Limits

https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/postinstall.sh

return value is 1

Or run *postinstall.sh* after installation

```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/postinstall.sh -c -O postinstall.sh && bash postinstall.sh && rm postinstall.sh
```

# Convert from LVM to ZFS (lvm2zfs.sh) *run once*
Converts the storage LVM into a ZFS raid 1 (mirror)
* Uses the LVM with the path/mount of /var/lib/vz
* Will automatically detect the required raid level and optimise
* 1 Drive = zfs (single)
* 2 Drives = mirror (raid1)
* 3-5 Drives = raidz-1 (raid5)
* 6-11 Drives = raidz-2 (raid6)
* 11+ Drives = raidz-3 (raid7)

**NOTE: WILL  DESTROY ALL DATA ON /var/lib/vz**
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/lvm2zfs.sh -c -O lvm2zfs.sh && bash lvm2zfs.sh && rm lvm2zfs.sh
```

# Create ZFS from devices (createzfs.sh) *optional*
Creates a zfs pool from specified devices
* Will automatically detect the required raid level and optimise
* 1 Drive = zfs (single)
* 2 Drives = mirror (raid1)
* 3-5 Drives = raidz-1 (raid5)
* 6-11 Drives = raidz-2 (raid6)
* 11+ Drives = raidz-3 (raid7)

**NOTE: WILL  DESTROY ALL DATA ON SPECIFIED DEVICES**
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/lvm2zfs.sh -c -O lvm2zfs.sh
bash createzfs.sh poolname /dev/device1 /dev/device2
```

# Create Private mesh vpn/network (tincvpn.sh)
tinc private mesh vpn/network which supports multicast, ideal for private cluster communication
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/tincvpn.sh -c -O tincvpn.sh && bash tincvpn.sh -h
```
## Example for 3 node Cluster
### First Host (hostname: host1)
```
bash tincvpn.sh -i 1 -c host2
```
### Second Host (hostname: host2)
```
bash tincvpn.sh -i 2 -c host3
```
### Third Host (hostname: host3)
```
bash tincvpn.sh -3 -c host1
```
