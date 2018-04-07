#!/bin/bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################
#
# Script updates can be found at: https://github.com/extremeshok/xshok-proxmox
#
# Will create a ZFS pool from the devices specified with the correct raid level
#
# Note: compatible with all debian based distributions
# If proxmox is detected, it will add the pools to the storage system
#
# License: BSD (Berkeley Software Distribution)
#
################################################################################
#
# Creates the following storage/rpools
# poolnamebackup (poolname/backup)
# poolnamevmdata (poolname/vmdata)
#
# Will automatically detect the required raid level and optimise.
#
# 1 Drive = zfs
# 2 Drives = mirror
# 3-5 Drives = raidz-1
# 6-11 Drives = raidz-2
# 11+ Drives = raidz-3
#
# NOTE: WILL  DESTROY ALL DATA ON DEVICES SPECIFED
#
# Usage:
# curl -O https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/createzfs.sh && chmod +x createzfs.sh
# ./createzfs.sh poolname /dev/sda /dev/sdb
#
################################################################################
#
#    THERE ARE  USER CONFIGURABLE OPTIONS IN THIS SCRIPT
#   ALL CONFIGURATION OPTIONS ARE LOCATED BELOW THIS MESSAGE
#
##############################################################

poolname=${1}
zfsdevicearray=("${@:2}")

#Detect and install dependencies
if ! type "zpool" >& /dev/null; then
  apt-get install -y zfsutils-linux
  modprobe zfs
fi
if ! type "parted" >& /dev/null; then
  apt-get install -y parted
fi

#check arguments
if [ $# -lt "2" ] ; then
  echo "Usage: $(basename "$0") poolname /list/of /dev/device1 /dev/device2"
  echo "Note will append 'pool' to the poolname, eg. hdd -> hddpool"
  echo "Recommended: use device names, /dev/disk/by-id"
  ls /dev/disk/by-id/ | grep -v "\-part*" | grep -v "wwn\-*"
  exit 1
fi
if [[ "$poolname" =~ "/" ]] ; then
  echo "ERROR: invalid poolname: $poolname"
  exit 1
fi
if [ "${#zfsdevicearray[@]}" -lt "1" ] ; then
  echo "ERROR: less than 1 devices were detected"
  exit 1
fi

#add the suffix pool to the poolname, prevent namepoolpool
poolprefix=${poolname/pool/}
poolname="${poolprefix}pool"  

for zfsdevice in "${zfsdevicearray[@]}" ; do
  if ! [[ "$zfsdevice" =~ "/" ]] ; then
    if ! [[ "$zfsdevice" =~ "-" ]] ; then 
      echo "ERROR: Invalid device specified: $zfsdevice"
      exit 1
    fi
  fi
  if ! [ -e "$zfsdevice" ]; then
    if ! [ -e "/dev/disk/by-id/$zfsdevice" ]; then
      if ! [ -e "/ls /dev/disk/by-uuid/$zfsdevice" ]; then
        echo "ERROR: Device $zfsdevice does not exist"
        exit 1
      fi
    fi 
  fi   
  if grep -q "$zfsdevice" "/proc/mounts" ; then
    echo "ERROR: Device is mounted $zfsdevice"
    exit 1
  fi
  echo "Clearing partitions: ${zfsdevice}"
  for v_partition in $(parted -s ${zfsdevice} print|awk '/^ / {print $1}') ; do
   parted -s "${zfsdevice}" rm ${v_partition}
  done
done

echo "Enable ZFS to autostart and mount"
systemctl enable zfs.target
systemctl enable zfs-mount
systemctl enable zfs-import-cache

echo "Ensure ZFS is started"
systemctl start zfs.target
modprobe zfs

if [ "$(zpool import 2> /dev/null | grep -m 1 -o "\s$poolname\b")" == "$poolname" ] ; then
	echo "ERROR: $poolname already exists as an exported pool"
	zpool import
	exit 1
fi
if [ "$(zpool list 2> /dev/null | grep -m 1 -o "\s$poolname\b")" == "$poolname" ] ; then
	echo "ERROR: $poolname already exists as a listed pool"
	zpool list
	exit 1
fi

echo "Creating the array"
if [ "${#zfsdevicearray[@]}" -eq "1" ] ; then
  echo "Creating ZFS mirror (raid1)"
  zpool create -f -o ashift=12 -O compression=lz4 "$poolname" ${zfsdevicearray[@]}
  ret=$?
elif [ "${#zfsdevicearray[@]}" -eq "2" ] ; then
  echo "Creating ZFS mirror (raid1)"
  zpool create -f -o ashift=12 -O compression=lz4 "$poolname" mirror ${zfsdevicearray[@]}
  ret=$?
elif [ "${#zfsdevicearray[@]}" -ge "3" ] && [ "${#zfsdevicearray[@]}" -le "5" ] ; then
  echo "Creating ZFS raidz-1 (raid5)"
  zpool create -f -o ashift=12 -O compression=lz4 "$poolname" raidz ${zfsdevicearray[@]}
  ret=$?
elif [ "${#zfsdevicearray[@]}" -ge "6" ] && [ "${#zfsdevicearray[@]}" -lt "11" ] ; then
  echo "Creating ZFS raidz-2 (raid6)"
  zpool create -f -o ashift=12 -O compression=lz4 "$poolname" raidz2 ${zfsdevicearray[@]}
  ret=$?
elif [ "${#zfsdevicearray[@]}" -ge "11" ] ; then
  echo "Creating ZFS raidz-3 (raid7)"
  zpool create -f -o ashift=12 -O compression=lz4 "$poolname" raidz3 ${zfsdevicearray[@]}
  ret=$?
fi

if [ $ret != 0 ] ; then
	echo "ERROR: creating ZFS"
	exit 1
fi

if [ "$( zpool list | grep  "$poolname" | cut -f 1 -d " ")" != "$poolname" ] ; then
	echo "ERROR: $poolname pool not found"
	zpool list
	exit 1
fi

echo "Creating Secondary ZFS Pools"
echo "-- ${poolname}/vmdata"
zfs create "${poolname}/vmdata"
echo "-- ${poolname}/backup (/backup_${poolprefix})"
zfs create -o mountpoint="/backup_${poolprefix}" "${poolname}/backup"
echo "-- ${poolname}/tmp (/tmp_${poolprefix})"
zfs create -o setuid=off -o devices=off -o mountpoint="/tmp_${poolprefix}"  "${poolname}/tmp"

#export the pool
zpool export "${poolname}"
sleep 10
zpool import "${poolname}"
sleep 5

echo "Setting ZFS Optimisations"
zfspoolarray=("$poolname" "${poolname}/vmdata" "${poolname}/backup" "${poolname}/tmp")
for zfspool in "${zfspoolarray[@]}" ; do
  echo "Optimising $zfspool"
  zfs set compression=on "$zfspool"
  zfs set compression=lz4 "$zfspool"
  zfs set sync=disabled "$zfspool"
  zfs set primarycache=all "$zfspool"
  zfs set atime=off "$zfspool"
  zfs set checksum=off "$zfspool"
  zfs set dedup=off "$zfspool"
  
  echo "Adding weekly pool scrub for $zfspool"
  if [ ! -f "/etc/cron.weekly/${poolname}" ] ; then
    echo '#!/bin/bash' > "/etc/cron.weekly/${poolname}"
  fi  
  echo "zpool scrub $zfspool" >> "/etc/cron.weekly/${poolname}"
done

# pvesm (proxmox) is optional
if type "pvesm" >& /dev/null; then
  # https://pve.proxmox.com/pve-docs/pvesm.1.html
  echo "Adding the ZFS storage pools to Proxmox GUI"
  echo "-- ${poolname}-vmdata"
  pvesm add zfspool ${poolname}-vmdata --pool "${poolname}/vmdata" --sparse 1
  echo "-- ${poolname}-backup"
  pvesm add dir ${poolname}-backup --path /backup_${poolprefix} 
fi

### Work in progress , create specialised pools ###
# echo "ZFS 8GB swap partition"
# zfs create -V 8G -b $(getconf PAGESIZE) -o logbias=throughput -o sync=always -o primarycache=metadata -o com.sun:auto-snapshot=false "$poolname"/swap
# mkswap -f /dev/zvol/"$poolname"/swap
# swapon /dev/zvol/"$poolname"/swap
# /dev/zvol/"$poolname"/swap none swap discard 0 0
#
# echo "ZFS tmp partition"
# zfs create -o setuid=off -o devices=off -o sync=disabled -o mountpoint=/tmp -o atime=off "$poolname"/tmp
## note: if you want /tmp on ZFS, mask (disable) systemd's automatic tmpfs-backed /tmp
# systemctl mask tmp.mount
#
# echo "RDBMS partition (MySQL/PostgreSQL/Oracle)"
# zfs create -o recordsize=8K -o primarycache=metadata -o mountpoint=/rdbms -o logbias=throughput "$poolname"/rdbms

#script Finish
echo -e '\033[1;33m Finished....please restart the server \033[0m'
