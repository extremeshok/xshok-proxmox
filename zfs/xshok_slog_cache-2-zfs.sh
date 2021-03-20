#!/usr/bin/env bash
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
# Assumptions: /xshok/zfs-cache and/or /xshok/zfs-slog are mounted.
#
# Assumes mounted MD raid partitions (linux software raid)
#
# Usage:
# curl -O https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/zfs/xshok_slog_cache-2-zfs.sh && chmod +x xshok_slog_cache-2-zfs.sh
# ./xshok_slog_cache-2-zfs.sh MY_ZFS_POOL
#
# NOTES: remove slog with
#  zpool remove MYPOOL mirror-1
# NOTES: remove cache with
# zpool remove DEVICE
#
################################################################################
#
#    THERE ARE NO USER CONFIGURABLE OPTIONS IN THIS SCRIPT
#
################################################################################

# Set the local
export LANG="en_US.UTF-8"
export LC_ALL="C"

MY_ZFS_POOL="$1"

if [ "$MY_ZFS_POOL" == "" ]; then
  #DEFAULT ZFS POOL
  MY_ZFS_POOL="hddpool"
fi

declare -a XSHOK_MOUNTS=('/xshok/zfs-cache' '/xshok/zfs-slog');

echo "+++++++++++++++++++++++++"
echo "WILL DESTROY ALL DATA ON"
echo "${XSHOK_MOUNTS[@]}"
echo "+++++++++++++++++++++++++"
echo "[CTRL]+[C] to exit"
echo "+++++++++++++++++++++++++"
sleep 1
echo "5.." ; sleep 1
echo "4.." ; sleep 1
echo "3.." ; sleep 1
echo "2.." ; sleep 1
echo "1.." ; sleep 1
echo "STARTING CONVERSION"
sleep 1

for XSHOK_MOUNT_POINT in "${XSHOK_MOUNTS[@]}" ; do
  echo "$XSHOK_MOUNT_POINT"
  #check mountpiont exists and is a device
  XSHOK_MOUNT_POINT_DEV=$(mount | grep -i "$XSHOK_MOUNT_POINT" | cut -d " " -f 1)
  ret=$?
  if [ $ret == 0 ] && [ "$XSHOK_MOUNT_POINT_DEV" != "" ] ; then
     echo "Found partition, continuing"
     echo "XSHOK_MOUNT_POINT_DEV=$XSHOK_MOUNT_POINT_DEV" #/dev/mapper/pve-data
  else
    echo "SKIPPING: $XSHOK_MOUNT_POINT not found"
    break
  fi

  #Detect and install dependencies
  if [ "$(command -v zpool)" == "" ] ; then
    if [ "$(command -v apt-get)" != "" ] ; then
      /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install zfsutils-linux
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
  if [ "$(command -v tune2fs)" == "" ] ; then
    echo "ERROR: tune2fs not installed"
    exit 1
  fi

  if ! zpool status "$MY_ZFS_POOL" 2> /dev/null ; then
    echo "ERROR: ZFS pool ${MY_ZFS_POOL} not found"
    exit 1
  fi

  XSHOK_MOUNT_POINT_MD_RAID=${XSHOK_MOUNT_POINT_DEV/\/dev\//}

  IFS=' ' read -r -a mddevarray <<< "$(grep "$XSHOK_MOUNT_POINT_MD_RAID :" /proc/mdstat | cut -d ' ' -f5- | xargs)"

  if [ "${mddevarray[0]}" == "" ] ; then
    echo "ERROR: no devices found for $XSHOK_MOUNT_POINT_DEV in /proc/mdstat"
    #exit 1
  fi
  #check there is a minimum of 1 drives detected, not needed, but i rather have it.
  if [ "${#mddevarray[@]}" -lt "1" ] ; then
    echo "ERROR: less than 1 devices were detected"
    #exit 1
  fi

  # remove [*] and /dev/ to each record
  echo "Creating the device array"
  for index in "${!mddevarray[@]}" ; do
      tempmddevarraystring="${mddevarray[index]}"
      mddevarray[$index]="/dev/${tempmddevarraystring%\[*\]}"
  done

  echo "Destroying MD (linux raid)"
  echo umount -f "${XSHOK_MOUNT_POINT_DEV}"
  umount -f "${XSHOK_MOUNT_POINT_DEV}"
  echo mdadm --stop "${XSHOK_MOUNT_POINT_DEV}"
  mdadm --stop "${XSHOK_MOUNT_POINT_DEV}"
  echo mdadm --remove "${XSHOK_MOUNT_POINT_DEV}"
  mdadm --remove "${XSHOK_MOUNT_POINT_DEV}"
  echo "Cleaning up fstab / mounts"
  grep -v "$XSHOK_MOUNT_POINT" /etc/fstab > /tmp/fstab.new && mv /tmp/fstab.new /etc/fstab

  MY_MD_DEV_UUID_LIST=""
  for MY_MD_DEV in "${mddevarray[@]}" ; do
      echo "zeroing $MY_MD_DEV"
      echo mdadm --zero-superblock "$MY_MD_DEV"
      mdadm --zero-superblock "$MY_MD_DEV"
      #MY_MD_DEV_UUID="$(uuidgen)"
      #tune2fs "$MY_MD_DEV" -U "$MY_MD_DEV_UUID"
      MY_MD_DEV_UUID="$(blkid | grep "$MY_MD_DEV" | cut -d= -f2 | xargs)"
      MY_MD_DEV_UUID_LIST="${MY_MD_DEV_UUID_LIST} ${MY_MD_DEV_UUID}"
  done

  if [ "$XSHOK_MOUNT_POINT" == "/xshok/zfs-cache" ] ; then
    echo "Adding ${mddevarray[*]} to ${MY_ZFS_POOL} as CACHE"
    echo "$MY_MD_DEV_UUID_LIST"
    zpool add ${MY_ZFS_POOL} cache "$MY_MD_DEV_UUID_LIST"
  elif [ "$XSHOK_MOUNT_POINT" == "/xshok/zfs-slog" ] ; then
    echo "Adding ${mddevarray[*]} to ${MY_ZFS_POOL} as SLOG"
    echo "$MY_MD_DEV_UUID_LIST"
    if [ "${#mddevarray[@]}" -eq "1" ] ; then
      zpool add ${MY_ZFS_POOL} log "$MY_MD_DEV_UUID_LIST"
    else
      zpool add ${MY_ZFS_POOL} log mirror "$MY_MD_DEV_UUID_LIST"
    fi
  else
    echo "SKIPPING: Nothing todo with the partions"
    echo "${mddevarray[@]}"
    echo "$MY_MD_DEV_UUID_LIST"
  fi
done

zpool iostat -v "$MY_ZFS_POOL" -L -T d


#script Finish
echo -e '\033[1;33m Finished....please restart the server \033[0m'
