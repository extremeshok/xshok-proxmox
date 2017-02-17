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

apt-get install -y zfsutils

mypart="/var/lib/vz"

mydev=$(mount | grep "$mypart" | cut -d " " -f 1)
ret=$?

if [ "$(which zpool)" == "" ] ; then
	echo "ZFS not installed"
	exit
fi


if [ $ret == 0 ] ; then
 	echo "Found partition, continuing"
 	echo "$mydev" #/dev/mapper/pve-data
else 
	echo "ERROR: mypart not found"
fi


myraid=$(pvdisplay  | sed -n -e 's/^.*\/dev\///p')
ret=$?
if [ $ret == 0 ] ; then
 echo "Found raid, continuing"
 echo "$myraid" #md5
else 
	echo "ERROR: myraid not found"
	exit 0
fi

#pve/data
mylv=$(lvdisplay $mydev | sed -n -e 's/^.*\/dev\///p')
ret=$?
if [ $ret == 0 ] ; then
 echo "Found lv, continuing"
 echo "$mylv" #sda1
else 
	echo "ERROR: mylv not found"
	exit 0
fi

mydev1=$(mdadm --detail "/dev/$myraid" | tail -2 | head -n 1 | sed -n -e 's/^.*\/dev\///p')
ret=$?
if [ $ret == 0 ] ; then
 echo "Found raid member1, continuing"
 echo "$mydev1" #sda1
else 
	echo "ERROR: mydev1 not found"
	exit 0
fi

mydev2=$(mdadm --detail "/dev/$myraid" | tail -1 | sed -n -e 's/^.*\/dev\///p')
ret=$?
if [ $ret == 0 ] ; then
 echo "Found raid member2, continuing"
 echo "$mydev2" #sdb1
else 
	echo "ERROR: mydev2 not found"
	exit 0
fi

if [ "$mydev" != "" ] && [ "$myraid" != "" ] && [ "$mylv" != "" ] && [ "$mydev1" != "" ] && [ "$mydev2" != "" ] ; then
	echo "All required varibles detected"
else
	echo "ERROR: required varible not found or the server is already converted to zfs"
	exit 0
fi

echo "Destroying LV (logical volume)"
umount -l "$mypart"
lvremove /dev/$mylv -y
echo "Destroying MD (linux raid)"
mdadm --stop "/dev/$myraid"
mdadm --remove "/dev/$myraid"
mdadm --zero-superblock "/dev/$mydev1"
mdadm --zero-superblock "/dev/$mydev2"

# #used to make a max free space lvm
# #lvcreate -n ZFS pve -l 100%FREE -y

echo "Creating ZFS"
zpool create -f -o ashift=12 -O compression=lz4 rpool mirror "/dev/$mydev1" "/dev/$mydev2"

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


