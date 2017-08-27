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

#check arguments
if [ $# -lt "2" ] ; then
  echo "ERROR: missing aguments"
  echo "Usage: $(basename "$0") poolname /list/of /dev/devices"
  exit 0
fi
if [[ "$poolname" =~ "/" ]] ; then
  echo "ERROR: invalid poolname: $poolname"
  exit 0
fi
if [ "${#zfsdevicearray[@]}" -lt "1" ] ; then
  echo "ERROR: less than 1 devices were detected"
  exit 0
fi
for zfsdevice in "${zfsdevicearray[@]}" ; do
  if ! [[ "${2}" =~ "/" ]] ; then
    echo "ERROR: Invalid device specified: $zfsdevice"
    exit 0
  fi
  if ! [ -e "$zfsdevice" ]; then
    echo "ERROR: Device $zfsdevice does not exist"
    exit 0
  fi
  if grep -q "$zfsdevice" "/proc/mounts" ; then
    echo "ERROR: Device is mounted $zfsdevice"
    exit 0
  fi
done

echo "Creating the array"
if [ "${#zfsdevicearray[@]}" -eq "1" ] ; then
  echo "Creating ZFS mirror (raid1)"
  zpool create -f -o ashift=12 -O compression=lz4 rpool "${zfsdevicearray[@]}"
  ret=$?
elif [ "${#zfsdevicearray[@]}" -eq "2" ] ; then
  echo "Creating ZFS mirror (raid1)"
  zpool create -f -o ashift=12 -O compression=lz4 rpool mirror "${zfsdevicearray[@]}"
  ret=$?
elif [ "${#zfsdevicearray[@]}" -ge "3" ] && [ "${#zfsdevicearray[@]}" -le "5" ] ; then
  echo "Creating ZFS raidz-1 (raid5)"
  zpool create -f -o ashift=12 -O compression=lz4 rpool raidz "${zfsdevicearray[@]}"
  ret=$?
elif [ "${#zfsdevicearray[@]}" -ge "6" ] && [ "${#zfsdevicearray[@]}" -lt "11" ] ; then
  echo "Creating ZFS raidz-2 (raid6)"
  zpool create -f -o ashift=12 -O compression=lz4 rpool raidz2 "${zfsdevicearray[@]}"
  ret=$?
elif [ "${#zfsdevicearray[@]}" -ge "11" ] ; then
  echo "Creating ZFS raidz-3 (raid7)"
  zpool create -f -o ashift=12 -O compression=lz4 rpool raidz3 "${zfsdevicearray[@]}"
  ret=$?
fi

if [ $ret != 0 ] ; then
	echo "ERROR: creating ZFS"
	exit 0
fi

echo "Creating Secondary ZFS Pools"
zfs create "$poolname/vmdata"
zfs create -o mountpoint="/backup_$poolname" "$poolname/backup"
zpool export "$poolname"

if type "pvesm" > /dev/null; then
  echo "Adding the ZFS storage pools to Proxmox GUI"
  pvesm add zfspool hddbackup -pool "$poolname/backup"
  pvesm add zfspool hddvmdata -pool "$poolname/vmdata"
fi

echo "Setting ZFS Optimisations"
zfspoolarray=("$poolname" "$poolname/vmdata" "$poolname/backup")
for zfspool in "${zfspoolarray[@]}" ; do
  echo "Optimising $zfspool"
  zfs set compression=on "$zfspool"
  zfs set compression=lz4 "$zfspool"
  zfs set sync=disabled "$zfspool"
  zfs set primarycache=all "$zfspool"
  zfs set atime=off "$zfspool"
  zfs set checksum=off "$zfspool"
  zfs set dedup=off "$zfspool"
done

exit
