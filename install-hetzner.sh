#!/usr/bin/env bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################
#
# Script updates can be found at: https://github.com/extremeshok/xshok-proxmox
#
# hetzner installation script for Proxmox
#
# License: BSD (Berkeley Software Distribution)
#
##############################################################################
#
# Assumptions:
# Run this script from the hetzner rescue system
# Operating system=Linux, Architecture=64 bit, Public key=*optional*
#
# Assumes 2 or 4 identical disks at /dev/sda and /dev/sdb,sdc,sdd,sde,sdf it ignores any extra disks which are not identical
# Will make sure the raid 1 use sda and the next identical sized disk, eg. sdc if sdb is not the same siza as sda
# software raid 1 (mirror) will be setup as well as LVM and will automatically detect and set the swap size
# If 4 identical disks are detected (sda,sdb,sdc,sdd) raid 10 will be used. (mirror and striped)
#
# SWAP partition size is adjusted according to available drive space
#
# Notes:
# will automatically run the install-post.sh script
# will automatically detect and use the latest debian install image
# ext3 boot partition is always created, as per Hetzner requirements
#
################################################################################
#
#   ALL CONFIGURATION OPTIONS ARE LOCATED BELOW THIS MESSAGE
#
################################################################################

#set size of swap partition or leave blank for autoconfig, USE NUMBER ONLY, will be in gbytes, 0 to disable
MY_SWAP=""
#set size of cache partition or leave blank for autoconfig, USE NUMBER ONLY, will be in gbytes, 0 to disable
MY_CACHE=""
#set size of slog partition or leave blank for autoconfig, USE NUMBER ONLY, will be in gbytes, 0 to disable
MY_SLOG=""
#set size of boot partition or leave blank for autoconfig, will be in gbytes, 1GB or larger
MY_BOOT="1"
#set size of root partition, will be in gbytes, 10GB or larger
MY_ROOT="40"
#comment out to disable LVM and use a very simple partition setup of / and swap
USE_LVM="TRUE"

################################################################################

# Set the local
export LANG="en_US.UTF-8"
export LC_ALL="C"

installimage_bin="/root/.oldroot/nfs/install/installimage"

MY_HOSTNAME="$1"
if [ "$MY_HOSTNAME" == "" ]; then
  echo "Please set a hostname"
  echo "$0 host.name"
  exit 1
fi

##### CONFIGURE RAID
# Detect discs for software raid and ensure sda and sd? are the identical size
# autoselects the second drive to raid with sda
# sda is always used, as sda is generally the primary boot disk
# disables raid if a suitable second disk is not found
if [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -eq $(awk '/sdb$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) ]]; then
  MY_RAID_ENABLE="yes"
  MY_RAID_SLAVE=",sdb"
elif [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -eq $(awk '/sdc$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) ]]; then
  MY_RAID_ENABLE="yes"
  MY_RAID_SLAVE=",sdc"
elif [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -eq $(awk '/sdd$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) ]]; then
  MY_RAID_ENABLE="yes"
  MY_RAID_SLAVE=",sdd"
elif [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -eq $(awk '/sde$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) ]]; then
  MY_RAID_ENABLE="yes"
  MY_RAID_SLAVE=",sde"
elif [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -eq $(awk '/sdf$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) ]]; then
  MY_RAID_ENABLE="yes"
  MY_RAID_SLAVE=",sdf"
else
  MY_RAID_ENABLE="no"
  MY_RAID_SLAVE=""
fi
#test for possible raid10, using 4 devices of equal size
if [ "$MY_RAID_ENABLE" == "yes" ]; then
  if [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -eq $(awk '/sdb$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) ]] && [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -eq $(awk '/sdc$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) ]] && [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -eq $(awk '/sdd$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) ]] ; then
    MY_RAID_LEVEL="10"
    MY_RAID_SLAVE=",sdb,sdc,sdd"
  else
    MY_RAID_LEVEL="1"
  fi
  echo "RAID ENABLED"
  echo "RAID Devices: sda${MY_RAID_SLAVE}"
  echo "Set RAID level to ${MY_RAID_LEVEL}"
fi

# check for ram size
#if [[ $(( $(vmstat -s | grep -i "total memory" | xargs | cut -d" " -f 1) / 1024 / 1000)) -le "64" ]] ; then

##### CONFIGURE BOOT
if [[ $MY_BOOT -lt 1 ]] ; then
  echo "error: MY_ROOT is too small, must be larger than 10 GB"
  exit 1
elif [ "$MY_BOOT" == "" ] || [[ ! $MY_BOOT =~ ^[0-9]+$ ]] ; then
  echo "error: MY_BOOT is Not a number, specify in GB"
  exit 1
fi

##### CONFIGURE ROOT
if [[ $MY_ROOT -lt 10 ]] ; then
  echo "error: MY_ROOT is too small, must be larger than 10 GB"
  exit 1
elif [ "$MY_ROOT" == "" ] || [[ ! $MY_ROOT =~ ^[0-9]+$ ]] ; then
  echo "error: MY_ROOT is Not a number, specify in GB"
  exit 1
fi

#### CONFIGURE SWAP
# HDD more than 400gb = 64GB swap
# HDD more than 160gb = 32GB swap
# HDD less than 160gb = 16GB swap
if [ "$MY_SWAP" == "0" ] ; then
  MY_SWAP=""
elif [ "$MY_SWAP" != "" ] && [[ ! $MY_SWAP =~ ^[0-9]+$ ]] ; then
  echo "error: MY_SWAP is Not a number, specify in GB"
  exit 1
else
  echo "Detecting and setting optimal swap partition size"
  if [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -gt "400" ]] ; then
    MY_SWAP="64"
  elif [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -gt "160" ]] ; then
    MY_SWAP="32"
  else
    MY_SWAP="16"
  fi
fi

#### CONFIGURE SLOG PARTITION
if [ "$MY_SLOG" == "0" ] ; then
  MY_SLOG=""
elif [ "$MY_SLOG" != "" ] && [[ ! $MY_SLOG =~ ^[0-9]+$ ]] ; then
  echo "error: MY_SLOG is Not a number, specify in GB"
  exit 1
elif [ "$(cat /sys/block/sda/queue/rotational)" == "1" ] ; then
  echo "HDD Detected, ignoring slog partition"
  MY_SLOG=""
elif [ "$MY_RAID_LEVEL" == "10" ]; then
  echo "SSD Detected, RAID 10 enabled, ignoring slog partition"
  MY_SLOG=""
elif [ "$(cat /sys/block/sdb/queue/rotational)" == "1" ] || [ "$(cat /sys/block/sdc/queue/rotational)" == "1" ]  || [ "$(cat /sys/block/sdd/queue/rotational)" == "1" ] || [ "$(cat /sys/block/sde/queue/rotational)" == "1" ] || [ "$(cat /sys/block/sdf/queue/rotational)" == "1" ] ; then
  echo "HDD Detected with SSD, enabling slog partition"
  #### CONFIGURE CACHE
  # HDD more than 800gb = 120GB CACHE
  # HDD more than 400gb = 60GB CACHE
  # HDD more than 160gb = 30GB CACHE
  # HDD less than 160gb = DISABLE CACHE
  echo "Detecting and setting optimal slog partition size"
  if [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -gt "800" ]] ; then
    MY_SLOG="10"
  elif [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -gt "400" ]] ; then
    MY_SLOG="5"
  elif [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -gt "160" ]] ; then
    MY_SLOG="1"
  else
    MY_SLOG=""
  fi
fi

#### CONFIGURE CACHE PARTITION
if [ "$MY_CACHE" == "0" ] ; then
  MY_CACHE=""
elif [ "$MY_CACHE" != "" ] && [[ ! $MY_CACHE =~ ^[0-9]+$ ]] ; then
  echo "error: ${MY_CACHE} is Not a number, specify in GB"
  exit 1
elif [ "$(cat /sys/block/sda/queue/rotational)" == "1" ] ; then
  echo "HDD Detected, ignoring cache partition"
  MY_CACHE=""
elif [ "$MY_RAID_LEVEL" == "10" ]; then
  echo "SSD Detected, RAID 10 enabled, ignoring cache partition"
  MY_CACHE=""
elif [ "$(cat /sys/block/sdb/queue/rotational)" == "1" ] || [ "$(cat /sys/block/sdc/queue/rotational)" == "1" ]  || [ "$(cat /sys/block/sdd/queue/rotational)" == "1" ] || [ "$(cat /sys/block/sde/queue/rotational)" == "1" ] || [ "$(cat /sys/block/sdf/queue/rotational)" == "1" ] ; then
  echo "HDD Detected with SSD, enabling cache partition"
  #### CONFIGURE CACHE
  # HDD more than 800gb = 120GB CACHE
  # HDD more than 400gb = 60GB CACHE
  # HDD more than 160gb = 30GB CACHE
  # HDD less than 160gb = DISABLE CACHE
  echo "Detecting and setting optimal swap partition size"
  if [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -gt "800" ]] ; then
    MY_CACHE="120"
  elif [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -gt "400" ]] ; then
    MY_CACHE="60"
  elif [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -gt "160" ]] ; then
    MY_CACHE="30"
  else
    MY_CACHE=""
  fi
fi

#### CHECK PARTITIONS WILL FIT ON DISK
if [[ $(( MY_BOOT + MY_ROOT + MY_SWAP + MY_CACHE + MY_SLOG + 1 )) -gt $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) ]] ; then
  echo "ERROR: Drive is too small"
  exit 1
fi

echo "SDA SIZE:  $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions)"
echo "BOOT: ${MY_BOOT}"
echo "ROOT: ${MY_ROOT}"
if [ "$MY_SWAP" != "" ]; then
  echo "SWAP: ${MY_SWAP}"
  MY_SWAP=",swap:swap:${MY_SWAP}G"
fi
if [ "$MY_CACHE" != "" ]; then
  if [ "$MY_RAID_LEVEL" == "1" ]; then
    #devide by 2 as the cache will be doubled (stripped)
    MY_CACHE=$(( MY_CACHE / 2 ))
  fi
  echo "CACHE: ${MY_CACHE}"
  MY_CACHE=",/xshok/zfs-cache:ext4:${MY_CACHE}G"
fi
if [ "$MY_SLOG" != "" ]; then
  echo "SLOG: ${MY_SLOG}"
  MY_SLOG=",/xshok/zfs-slog:ext4:${MY_SLOG}G"
fi

#wait 5 seconds
sleep 5

# Detect the latest installimage file to use
installimage_file=$(find root/images/ -iname 'Debian-*-stretch-64-minimal.tar.gz' | sort --version-sort --field-separator=- --key=2,2 -r | head -n1)
if [ ! -f $installimage_file ] ; then
  echo "Error: Image file was not found: ${installimage_file}"
  echo "Please log an issue on the github repo with the following"
  ls -laFh root/images
  exit 1  
fi

#fetching post install
curl "https://raw.githubusercontent.com/hetzneronline/installimage/master/post-install/proxmox5" --output /post-install

#Customising post install file
echo "wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/install-post.sh -c -O install-post.sh && bash install-post.sh && rm install-post.sh" >> /post-install

if grep -q '#!/bin/bash' "/post-install"; then
  chmod 777 /post-install
  echo "Starting Installer with Install Image: ${installimage_file}"

  if [ "$USE_LVM" == "TRUE" ]; then
    echo "Using LVM"
    $installimage_bin -a -i "$installimage_file" -g -s en -x /post-install -n "${MY_HOSTNAME}" -b grub -d "sda${MY_RAID_SLAVE}" -r "${MY_RAID_ENABLE}" -l "${MY_RAID_LEVEL}" -p "/boot:ext3:${MY_BOOT}G,/:ext4:${MY_ROOT}G${MY_SWAP}${MY_CACHE}${MY_SLOG},lvm:vg0:all" -v "vg0:data:/var/lib/vz:xfs:all"
  else
    $installimage_bin -a -i "$installimage_file" -g -s en -x /post-install -n "${MY_HOSTNAME}" -b grub -d "sda${MY_RAID_SLAVE}" -r "${MY_RAID_ENABLE}" -l "${MY_RAID_LEVEL}" -p "/boot:ext3:${MY_BOOT}G,/:ext4:${MY_ROOT}G${MY_SWAP}${MY_CACHE}${MY_SLOG},/var/lib/vz:xfs:all"
  fi

else
  echo "Failed to fetch post-install"
  exit 1
fi
