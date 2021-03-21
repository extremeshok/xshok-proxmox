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
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/zfs/lvm-2-zfs.sh -c -O lvm-2-zfs.sh  && chmod +x lvm-2-zfs.sh
 ./lvm-2-zfs.sh && rm lvm-2-zfs.sh
````
* Reboot
* Connect via ssh/terminal to the new Proxmox system running on your server and run the following
## NETWORKING (vmbr0 vmbr1)
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/networking/network-configure.sh -c -O network-configure.sh && chmod +x network-configure.sh
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
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/zfs/createzfs.sh -c -O createzfs.sh && chmod +x createzfs.sh
./createzfs.sh poolname /dev/device1 /dev/device2
```
## Create ZFS cache and slog from /xshok/zfs-cache and /xshok/zfs-slog partitions and adds them to a zpool (xshok_slog_cache-2-zfs.sh) *optional*

**NOTE: WILL  DESTROY ALL DATA ON SPECIFIED PARTITIONS**
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/zfs/xshok_slog_cache-2-zfs.sh -c -O xshok_slog_cache-2-zfs.sh && chmod +x xshok_slog_cache-2-zfs.sh
./xshok_slog_cache-2-zfs.sh poolname
```
* Reboot
