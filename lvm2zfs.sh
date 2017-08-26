#!/bin/bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################
#
# Script updates can be found at: https://github.com/extremeshok/xshok-proxmox
#
# post-installation script for Proxmox
#
# License: BSD (Berkeley Software Distribution)
#
################################################################################
#
# Assumptions: proxmox installed via OVH manager (non zfs)
# Recommeneded partitioning scheme:
# Raid 1 / 100GB ext4
# 2x swap 8192mb (16384mb total)
# Remaining for /var/lib/vz
#
# Usage:
# curl -O https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/lvm2zfs.sh && chmod +x lvm2zfs.sh
# ./lvm2zfs.sh
#
################################################################################
#
#    THERE ARE  USER CONFIGURABLE OPTIONS IN THIS SCRIPT
#   ALL CONFIGURATION OPTIONS ARE LOCATED BELOW THIS MESSAGE
#
##############################################################

apt-get install -y zfsutils-linux

modprobe zfs

mypart="/var/lib/vz"

mydev=$(mount | grep "$mypart" | cut -d " " -f 1)
ret=$?
if [ $ret == 0 ] ; then
 	echo "Found partition, continuing"
 	echo "$mydev" #/dev/mapper/pve-data
else
	echo "ERROR: $mypart not found"
fi

if [ "$(which zpool)" == "" ] ; then
	echo "ERROR: ZFS not installed"
	exit 0
fi

myraid=$(pvdisplay 2> /dev/null  | sed -n -e 's/^.*\/dev\///p')
ret=$?
if [ $ret == 0 ] ; then
	 echo "Found raid, continuing"
	 echo "$myraid" #md5
else
	echo "ERROR: myraid not found"
	exit 0
fi

#pve/data
mylv=$(lvdisplay "$mydev" | sed -n -e 's/^.*\/dev\///p')
ret=$?
if [ $ret == 0 ] ; then
	echo "Found lv, continuing"
	echo "$mylv" #sda1
else
	echo "ERROR: mylv not found"
	exit 0
fi

IFS=' ' read -r -a mddevarray <<< "$(grep "$myraid :" /proc/mdstat | cut -d ' ' -f5- | xargs)"
#without IFS
#mddevarray="$(grep "$myraid :" /proc/mdstat | cut -d ' ' -f5- | xargs)"
#mddevarray=(${mddevarray//:/ })

echo "${mddevarray[0]}"
if [ "${mddevarray[0]}" == "" ] ; then
	echo "ERROR: no devices found for $myraid in /proc/mdstat"
	exit 0
fi

#Only need to check there is a minimum of 2 drives detected
if [ "$mydev" != "" ] && [ "$myraid" != "" ] && [ "$mylv" != "" ] && [ "${mddevarray[0]}" != "" ] && [ "${mddevarray[1]}" != "" ] ; then
	echo "All required varibles detected"
else
	echo "ERROR: required varible not found or the server is already converted to zfs"
	exit 0
fi

echo "Destroying LV (logical volume)"
umount -l "$mypart"
lvremove "/dev/$mylv" -y
echo "Destroying MD (linux raid)"
mdadm --stop "/dev/$myraid"
mdadm --remove "/dev/$myraid"

for mydev in "${mddevarray[@]}" ; do
    echo "zeroing $mydev"
    mdadm --zero-superblock "/dev/$mydev"
done

# add the /dev to each record
for index in "${!mddevarray[@]}" ; do
    mddevarray[$index]="/dev/${mddevarray[index]}"
done

# #used to make a max free space lvm
# #lvcreate -n ZFS pve -l 100%FREE -y
if [ "${#mddevarray[@]}" -eq "2" ] ; then
  echo "Creating ZFS mirror (raid1)"
  zpool create -f -o ashift=12 -O compression=lz4 rpool mirror "${mddevarray[@]}"
elif [ "${#mddevarray[@]}" -ge "3" ] && [ "${#mddevarray[@]}" -lt "5" ] ; then
  echo "Creating ZFS raidz-1 (raid5)"
  zpool create -f -o ashift=12 -O compression=lz4 rpool raidz "${mddevarray[@]}"
elif [ "${#mddevarray[@]}" -ge "6" ] && [ "${#mddevarray[@]}" -lt "11" ] ; then
  echo "Creating ZFS raidz-2 (raid6)"
  zpool create -f -o ashift=12 -O compression=lz4 rpool raidz2 "${mddevarray[@]}"
elif [ "${#mddevarray[@]}" -ge "11" ] ; then
  echo "Creating ZFS raidz-3 (raid7)"
  zpool create -f -o ashift=12 -O compression=lz4 rpool raidz3 "${mddevarray[@]}"
fi

echo "Setting Additional Options"
zfs set compression=on rpool
zfs set sync=disabled rpool
zfs set primarycache=all rpool
zfs set atime=off rpool
zfs set checksum=off rpool
zfs set dedup=off rpool

echo "Creating Secondary ZFS Pools"
zfs create rpool/vm-disks
zfs create -o mountpoint=/backup rpool/backup
zpool export rpool

echo "Cleaning up fstab / mounts"
#/dev/pve/data   /var/lib/vz     ext3    defaults        1       2
grep -v "$mypart" /etc/fstab > /tmp/fstab.new && mv /tmp/fstab.new /etc/fstab


#script Finish
echo -e '\033[1;33m Finished....please restart the server \033[0m'
#return 1
