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
# Remaining for /var/lib/vz (LVM)
#
# Creates the following storage/rpools
# zfsbackup (rpool/backup)
# zfsvmdata (rpool/vmdata)
#
# Will automatically detect the required raid level and optimise.
#
# 1 Drive = zfs
# 2 Drives = mirror
# 3-5 Drives = raidz-1
# 6-11 Drives = raidz-2
# 11+ Drives = raidz-3
#
# NOTE: WILL  DESTROY ALL DATA ON LVM_MOUNT_POINT
#
# Usage:
# curl -O https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/lvm2zfs.sh && chmod +x lvm2zfs.sh
# ./lvm2zfs.sh
#
################################################################################
#
#    THERE ARE NO USER CONFIGURABLE OPTIONS IN THIS SCRIPT
#
################################################################################

LVM_MOUNT_POINT="$1"

if [ "$LVM_MOUNT_POINT" == "" ]; then
  # The default LVM mount which will be replaced with ZFS
  LVM_MOUNT_POINT="/var/lib/vz"
fi

echo "LVM_MOUNT_POINT=$LVM_MOUNT_POINT"

MY_LVM_DEV=$(mount | grep "$LVM_MOUNT_POINT" | cut -d " " -f 1)
ret=$?
if [ $ret == 0 ] ; then
   echo "Found partition, continuing"
   echo "MY_LVM_DEV=$MY_LVM_DEV" #/dev/mapper/pve-data
else
  echo "ERROR: $LVM_MOUNT_POINT not found"
fi

#Detect and install dependencies
if [ "$(command -v zpool)" == "" ] ; then
  if [ "$(command -v apt-get)" != "" ] ; then
    apt-get install -y zfsutils-linux
    modprobe zfs
  else
    echo "ERROR: ZFS not installed"
    exit 1
  fi
fi
if [ "$(command -v zpool)" == "" ] ; then
  echo "ERROR: ZFS not installed"
  exit 1
fi

MY_MD_RAID=$(pvdisplay 2> /dev/null  | sed -n -e 's/^.*\/dev\///p')
ret=$?
if [ $ret == 0 ] ; then
   echo "Found raid, continuing"
   echo "MY_MD_RAID=$MY_MD_RAID" #md5
else
  echo "ERROR: $MY_MD_RAID not found"
  exit 1
fi

#pve/data
MY_LV=$(lvdisplay "$MY_LVM_DEV" 2> /dev/null | sed -n -e 's/^.*\/dev\///p')
ret=$?
if [ $ret == 0 ] ; then
  echo "Found lv, continuing"
  echo "MY_LV=$MY_LV" #sda1
else
  echo "ERROR: $MY_LV not found"
  exit 1
fi

IFS=' ' read -r -a mddevarray <<< "$(grep "$MY_MD_RAID :" /proc/mdstat | cut -d ' ' -f5- | xargs)"

if [ "${mddevarray[0]}" == "" ] ; then
  echo "ERROR: no devices found for $MY_MD_RAID in /proc/mdstat"
  exit 1
fi
#check there is a minimum of 1 drives detected, not needed, but i rather have it.
if [ "${#mddevarray[@]}" -lt "1" ] ; then
  echo "ERROR: less than 1 devices were detected"
  exit 1
fi

if [ "$MY_LVM_DEV" != "" ] && [ "$MY_MD_RAID" != "" ] && [ "$MY_LV" != "" ] ; then
  echo "All required varibles detected"
else
  echo "ERROR: required varible not found or the server is already converted to zfs"
  exit 1
fi

# remove [*] and /dev/ to each record
echo "Creating the device array"
for index in "${!mddevarray[@]}" ; do
    tempmddevarraystring="${mddevarray[index]}"
    mddevarray[$index]="/dev/${tempmddevarraystring%\[*\]}"
done

echo "Destroying LV (logical volume)"
echo umount -l "$LVM_MOUNT_POINT"
umount -l "$LVM_MOUNT_POINT"
echo lvremove "/dev/$MY_LV" -y 2> /dev/null
lvremove "/dev/$MY_LV" -y 2> /dev/null

echo "Destroying MD (linux raid)"
echo mdadm --stop "/dev/$MY_MD_RAID"
mdadm --stop "/dev/$MY_MD_RAID"
echo mdadm --remove "/dev/$MY_MD_RAID"
mdadm --remove "/dev/$MY_MD_RAID"

for MY_LVM_DEV in "${mddevarray[@]}" ; do
    echo "zeroing $MY_LVM_DEV"
    echo mdadm --zero-superblock "$MY_LVM_DEV"
    mdadm --zero-superblock "$MY_LVM_DEV"
done

# #used to make a max free space lvm
# #lvcreate -n ZFS pve -l 100%FREE -y
if [ "${#mddevarray[@]}" -eq "1" ] ; then
  echo "Creating ZFS single"
  echo zpool create -f -o ashift=12 -O compression=lz4 -O checksum=on rpool "${mddevarray[@]}"
  zpool create -f -o ashift=12 -O compression=lz4 -O checksum=on rpool "${mddevarray[@]}"
  ret=$?
elif [ "${#mddevarray[@]}" -eq "2" ] ; then
  echo "Creating ZFS mirror (raid1)"
  echo zpool create -f -o ashift=12 -O compression=lz4 -O checksum=on rpool mirror "${mddevarray[@]}"
  zpool create -f -o ashift=12 -O compression=lz4 -O checksum=on rpool mirror "${mddevarray[@]}"
  ret=$?
elif [ "${#mddevarray[@]}" -ge "3" ] && [ "${#mddevarray[@]}" -le "5" ] ; then
  echo "Creating ZFS raidz-1 (raid5)"
  echo zpool create -f -o ashift=12 -O compression=lz4 -O checksum=on rpool raidz "${mddevarray[@]}"
  zpool create -f -o ashift=12 -O compression=lz4 -O checksum=on rpool raidz "${mddevarray[@]}"
  ret=$?
elif [ "${#mddevarray[@]}" -ge "6" ] && [ "${#mddevarray[@]}" -lt "11" ] ; then
  echo "Creating ZFS raidz-2 (raid6)"
  echo zpool create -f -o ashift=12 -O compression=lz4 -O checksum=on rpool raidz2 "${mddevarray[@]}"
  zpool create -f -o ashift=12 -O compression=lz4 -O checksum=on rpool raidz2 "${mddevarray[@]}"
  ret=$?
elif [ "${#mddevarray[@]}" -ge "11" ] ; then
  echo "Creating ZFS raidz-3 (raid7)"
  echo zpool create -f -o ashift=12 -O compression=lz4 -O checksum=on rpool raidz3 "${mddevarray[@]}"
  zpool create -f -o ashift=12 -O compression=lz4 -O checksum=on rpool raidz3 "${mddevarray[@]}"
  ret=$?
fi

if [ $ret != 0 ] ; then
  echo "ERROR: creating ZFS"
  exit 1
fi

echo "Creating Secondary ZFS sparse volumes"
echo "-- rpool/vmdata"
echo zfs create rpool/vmdata
zfs create rpool/vmdata
echo "-- rpool/backup (/backup_rpool)"
echo zfs create -o mountpoint=/backup_rpool rpool/backup
zfs create -o mountpoint=/backup_rpool rpool/backup

#export the pool
echo zpool export rpool
zpool export rpool
echo sleep 5
sleep 5
echo zpool import rpool
zpool import rpool
echo sleep 5
sleep 5

echo "Cleaning up fstab / mounts"
#/dev/pve/data   /var/lib/vz     ext3    defaults        1       2
grep -v "$LVM_MOUNT_POINT" /etc/fstab > /tmp/fstab.new && mv /tmp/fstab.new /etc/fstab

echo "Optimising rpool"
zfs set compression=on "rpool"
zfs set compression=lz4 "rpool"
zfs set primarycache=all "rpool"
zfs set atime=off "rpool"
zfs set relatime=off "rpool"
zfs set checksum=on "rpool"
zfs set dedup=off "rpool"
zfs set xattr=sa "rpool"

#check we do not already have a cron for zfs
if [ ! -f "/etc/cron.d/zfsutils-linux" ] ; then
  if [ -f /usr/lib/zfs-linux/scrub ] ; then
    cat <<'EOF' > /etc/cron.d/zfsutils-linux
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Scrub the pool every second Sunday of every month.
24 0 8-14 * * root [ $(date +\%w) -eq 0 ] && [ -x /usr/lib/zfs-linux/scrub ] && /usr/lib/zfs-linux/scrub
EOF
  else
    echo "Scrub the pool every second Sunday of every month rpool"
    if [ ! -f "/etc/cron.d/zfs-scrub" ] ; then
      echo "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"  > "/etc/cron.d/zfs-scrub"
    fi
    echo "24 0 8-14 * * root [ \$(date +\\%w) -eq 0 ] && zpool scrub rpool" >> "/etc/cron.d/zfs-scrub"
  fi
fi

if [ -f "/etc/vzdump.conf" ]; then
  echo "set vzdump temp dir to use the /tmp_rpool"
  sed -i "s|tmpdir: /var/lib/vz/tmp_backup|tmpdir: /tmp_rpool|" /etc/vzdump.conf
fi

if type "pvesm" >& /dev/null; then
  # https://pve.proxmox.com/pve-docs/pvesm.1.html
  echo "Adding the ZFS storage pools to Proxmox GUI"
  echo "-- rpool-vmdata"
  echo pvesm add zfspool rpool-vmdata --pool rpool/vmdata --sparse 1
  pvesm add zfspool rpool-vmdata --pool rpool/vmdata --sparse 1
  echo "-- rpool-backup"
  echo pvesm add dir rpool-backup --path /backup_rpool
  pvesm add dir rpool-backup --path /backup_rpool
fi

#script Finish
echo -e '\033[1;33m Finished....please restart the server \033[0m'
