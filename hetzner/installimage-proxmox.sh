#!/usr/bin/env bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################
#
# Script updates can be found at: https://github.com/extremeshok/xshok-proxmox
#
# hetzner installation script for Proxmox v2
#
# License: BSD (Berkeley Software Distribution)
#
##############################################################################
# Usage :
########## Proxmox VE
# vnc-install-proxmox.sh hostname.fqd.com
########## Backup Server
# vnc-install-proxmox.sh  hostname.fqd.com pbs
#
###############################################################################
# Assumptions:
# Run this script from the hetzner rescue system
# Operating system=Linux, Architecture=64 bit, Public key=*optional*
#
# Will automatically detect nvme, ssd and hdd and configure accordingly.
#
# Notes:
# ext3 boot partition of 1GB
# ext4 root partition adjusted according to available drive space, upto 128GB
#
# sata ssd is used (boot and root) instead of nvme
# will use nvme as target, if sda is a spinning disk
# slog and L2ARC if nvme is present, no ssd and hdd is present
# slog and L2ARC if ssd is present, no nvme and hdd is present
#
################################################################################
#
#   ALL CONFIGURATION OPTIONS ARE LOCATED BELOW THIS MESSAGE
#
################################################################################
# Ensure NVME devices use 4K block size and not 512 block size, can cause problems with some devices
NVME_FORCE_4K="FALSE"
# Will create a new GPT partition table on the install target drives.
# this will wipe all patition information on the drives
WIPE_PARTITION_TABLE="TRUE"
# FQDN Hostname
MY_HOSTNAME=""
# Select the OS to install "PVE" "PBS", default is PVE
MY_OS=""
#set size of boot partition or leave blank for autoconfig, will be in gbytes, 1GB or larger
MY_BOOT=""
#set size of root partition, will be in gbytes, 10GB or larger
MY_ROOT=""
#set size of swap partition or leave blank for autoconfig, USE NUMBER ONLY, will be in gbytes, 0 to disable
MY_SWAP=""
#set size of L2ARC partition or leave blank for autoconfig, USE NUMBER ONLY, will be in gbytes, 0 to disable
MY_ZFS_L2ARC=""
#set size of slog partition or leave blank for autoconfig, USE NUMBER ONLY, will be in gbytes, 0 to disable
MY_ZFS_SLOG=""
################################################################################

# Set the local
export LANG="en_US.UTF-8"
export LC_ALL="C"

# Reconnect to screen, incase of a disconnect
screen -r proxmox-install && exit 0

#Check for Installimage
installimage_bin="/root/.oldroot/nfs/install/installimage"
if [ ! -f "$installimage_bin" ]; then
    echo "$installimage_bin does not exist"
    echo "Please report the issue with the following"
    ls -laFh "/root/.oldroot/nfs/install/"
    exit 1
fi

#Check for base image
installimage_file="/root/images/Debian-bullseye-latest-amd64-base.tar.gz"
# Detect the latest installimage file to use
#installimage_file=$(find /root/images/ -iname 'Debian-*-bullseye-amd64-base.tar.gz.tar.gz' | sort --version-sort --field-separator=- --key=2,2 -r | head -n1)
if [ ! -f $installimage_file ] ; then
  echo "Error: Image file was not found: ${installimage_file}"
  echo "Please log an issue on the github repo with the following"
  ls -laFh "/root/images/"
  exit 1
fi

#Hostname
if [ "$MY_HOSTNAME" == "" ] ; then
  MY_HOSTNAME="$1"
fi
if [[ "$MY_HOSTNAME" != *.* ]] ; then
  echo "ERROR: Please set a FQDN hostname"
  echo "$0 host.name"
  exit 1
  echo "Hostname: ${MY_HOSTNAME}"
fi

if [ "$MY_USE_LVM" != "" ] && [ "${MY_USE_LVM,,}" != "true" ] && [ "${MY_USE_LVM,,}" != "yes" ]  ; then
  LVM="FALSE"
else
  LVM="TRUE"
fi

# Validate Custom partition sizes
if [[ ! $MY_ZFS_SLOG =~ ^[0-9]+$ ]] && [ "$MY_ZFS_SLOG" != "" ] ; then
  echo "ERROR: ${MY_ZFS_SLOG} is Not a number, specify in GB"
  exit 1
fi
if [[ ! $MY_ZFS_L2ARC =~ ^[0-9]+$ ]] && [ "$MY_ZFS_L2ARC" != "" ] ; then
  echo "ERROR: ${MY_ZFS_L2ARC} is Not a number, specify in GB"
  exit 1
fi
if [[ ! $MY_SWAP =~ ^[0-9]+$ ]] && [ "$MY_SWAP" != "" ]; then
  echo "ERROR: ${MY_SWAP} is Not a number, specify in GB"
  exit 1
fi
if [[ ! $MY_BOOT =~ ^[0-9]+$ ]] && [ "$MY_BOOT" != "" ] ; then
  echo "ERROR: MY_BOOT is Not a number, specify in GB"
  exit 1
fi
if [[ $MY_BOOT -lt 1 ]] && [ "$MY_BOOT" != "" ]; then
  echo "ERROR: MY_BOOT cannot be less than 1 GB"
  exit 1
fi
if [[ ! $MY_ROOT =~ ^[0-9]+$ ]] && [ "$MY_ROOT" != "" ] ; then
  echo "ERROR: MY_ROOT is Not a number, specify in GB"
  exit 1
fi
if [[ $MY_ROOT -lt 10 ]] && [ "$MY_ROOT" != "" ] ; then
  echo "ERROR: MY_ROOT cannot be less than 10 GB"
  exit 1
fi

#OS to install
if [ "$MY_OS" == "" ]; then
  OS="$2"
fi
if [ "${OS,,}" == "pve" ] ; then
  OS="PVE"
elif [ "${OS,,}" == "pbs" ] ; then
  OS="PBS"
else
  OS="PVE"
fi

# Generate NVME Device Arrays
# shellcheck disable=SC2010
mapfile -t NVME_ARRAY < <( ls -1 /sys/block | grep ^nvme | sort -d )
NVME_COUNT=${#NVME_ARRAY[@]}
NVME_TARGET=""
NVME_TARGET_FIRST=""
NVME_TARGET_COUNT=0
if [[ $NVME_COUNT -ge 1 ]] ; then
  for nvme_device in "${NVME_ARRAY[@]}"; do
    if [ "$NVME_FORCE_4K" == "yes" ] ; then
      if  [[ $(nvme id-ns "/dev/${nvme_device}" -H | grep "LBA Format" | grep "(in use)" | grep -oP "Data Size\K.*" | cut -d" " -f 2) -ne 4096 ]] ; then
        echo "Appling 4K block size to NVME: ${nvme_device}"
        nvme format "/dev/${nvme_device}" -b 4096 -f || exit 1
        sleep 5
        echo "Reset NVME controller: ${nvme_device::-2}"
        nvme reset "/dev/${nvme_device::-2}" || exit 1
        sleep 5
      fi
    fi
      if [ "${NVME_TARGET}" == "" ] ; then
        NVME_TARGET="${nvme_device}"
        NVME_TARGET_FIRST="${nvme_device}"
        NVME_TARGET_COUNT=1
      else
        if [[ $(grep "${NVME_TARGET_FIRST}" -m1 /proc/partitions | xargs | cut -d" " -f3) -eq $(grep "${nvme_device}" -m1 /proc/partitions | xargs | cut -d" " -f3) ]]; then
          NVME_TARGET="${NVME_TARGET},${nvme_device}"
          NVME_TARGET_COUNT=$((NVME_TARGET_COUNT+1))
        fi
      fi
  done
fi

# Generate SCSI (HDD/SSD) Device Arrays
# shellcheck disable=SC2010
mapfile -t SCSI_ARRAY < <( ls -1 /sys/block | grep ^sd | sort -d )
SCSI_COUNT=${#SCSI_ARRAY[@]}
SSD_COUNT=0
HDD_COUNT=0
SSD_TARGET=""
HDD_TARGET=""
SSD_TARGET_COUNT=0
HDD_TARGET_COUNT=0
SSD_TARGET_FIRST=""
HDD_TARGET_FIRST=""
if [[ $SCSI_COUNT -ge 1 ]] ; then
  for scsi_device in "${SCSI_ARRAY[@]}"; do
    if [ "$(lsblk -d -o rota "/dev/${scsi_device}" | tail -n 1 | xargs)" -ne "1" ] ; then
      SSD_COUNT=$((SSD_COUNT+1))
      if [ "${SSD_TARGET}" == "" ] ; then
        SSD_TARGET="${scsi_device}"
        SSD_TARGET_FIRST="${scsi_device}"
        SSD_TARGET_COUNT=1
      else
        if [[ $(grep "${SSD_TARGET_FIRST}" -m1 /proc/partitions | xargs | cut -d" " -f3) -eq $(grep "${scsi_device}" -m1 /proc/partitions | xargs | cut -d" " -f3) ]]; then
          SSD_TARGET="${SSD_TARGET},${scsi_device}"
          SSD_TARGET_COUNT=$((SSD_TARGET_COUNT+1))
        fi
      fi
    else
      HDD_COUNT=$((HDD_COUNT+1))
      if [ "${HDD_TARGET}" == "" ] ; then
        HDD_TARGET="${scsi_device}"
        HDD_TARGET_FIRST="${scsi_device}"
        HDD_TARGET_COUNT=1
      else
        if [[ $(grep "${HDD_TARGET_FIRST}" -m1 /proc/partitions | xargs | cut -d" " -f3) -eq $(grep "${scsi_device}" -m1 /proc/partitions | xargs | cut -d" " -f3) ]]; then
          HDD_TARGET="${HDD_TARGET},${scsi_device}"
          HDD_TARGET_COUNT=$((HDD_TARGET_COUNT+1))
        fi
      fi
    fi
  done
fi

# Calculate Install Target
RAID=""
INSTALL_TARGET=""
ZFS_L2ARC=""
ZFS_SLOG=""
#NVME only
if [[ $NVME_TARGET_COUNT -ge 1 ]] && [[ $SSD_TARGET_COUNT -eq 0 ]] && [[ $HDD_TARGET_COUNT -eq 0 ]]; then
  if [[ $NVME_TARGET_COUNT -eq 4 ]] ; then
    RAID="10"
  elif [[ $NVME_TARGET_COUNT -eq 2 ]] ; then
    RAID="1"
  else
    RAID=""
  fi
  SWAP="yes"
  INSTALL_TARGET="${NVME_TARGET}"
#SSD Only
elif [[ $NVME_TARGET_COUNT -eq 0 ]] && [[ $SSD_TARGET_COUNT -ge 1 ]] && [[ $HDD_TARGET_COUNT -eq 0 ]] ; then
  if [[ $SSD_TARGET_COUNT -eq 4 ]] ; then
    RAID="10"
  elif [[ $SSD_TARGET_COUNT -eq 2 ]] ; then
    RAID="1"
  else
    RAID=""
  fi
  SWAP="yes"
  INSTALL_TARGET="${SSD_TARGET}"
#HDD Only
elif [[ $NVME_TARGET_COUNT -eq 0 ]] && [[ $SSD_TARGET_COUNT -eq 0 ]] && [[ $HDD_TARGET_COUNT -ge 1 ]] ; then
  if [[ $HDD_TARGET_COUNT -eq 4 ]] ; then
    RAID="10"
  elif [[ $HDD_TARGET_COUNT -eq 2 ]] ; then
    RAID="1"
  else
    RAID=""
  fi
  SWAP="no"
  INSTALL_TARGET="${HDD_TARGET}"
#NVME with SSD, OS on SSD
elif [[ $NVME_TARGET_COUNT -ge 1 ]] && [[ $SSD_TARGET_COUNT -ge 1 ]] && [[ $HDD_TARGET_COUNT -eq 0 ]] ; then
  if [[ $SSD_TARGET_COUNT -eq 4 ]] ; then
    RAID="10"
  elif [[ $SSD_TARGET_COUNT -eq 2 ]] ; then
    RAID="1"
  else
    RAID=""
  fi
  SWAP="yes"
  INSTALL_TARGET="${SSD_TARGET}"
#SSD with HDD, OS on SSD with ZFS L2ARC and slog on SSD
elif [[ $NVME_TARGET_COUNT -eq 0 ]] && [[ $SSD_TARGET_COUNT -ge 1 ]] && [[ $HDD_TARGET_COUNT -ge 1 ]] ; then
  if [[ $SSD_TARGET_COUNT -eq 4 ]] ; then
    RAID="10"
  elif [[ $SSD_TARGET_COUNT -eq 2 ]] ; then
    RAID="1"
  else
    RAID=""
  fi
  ZFS_L2ARC="yes"
  ZFS_SLOG="yes"
  SWAP="yes"
  INSTALL_TARGET="${SSD_TARGET}"
#NVME with SSD and HDD, OS on SSD
elif [[ $NVME_TARGET_COUNT -ge 1 ]] && [[ $SSD_TARGET_COUNT -ge 1 ]] && [[ $HDD_TARGET_COUNT -ge 1 ]] ; then
  if [[ $SSD_TARGET_COUNT -eq 4 ]] ; then
    RAID="10"
  elif [[ $SSD_TARGET_COUNT -eq 2 ]] ; then
    RAID="1"
  else
    RAID=""
  fi
  INSTALL_TARGET="${SSD_TARGET}"
#NVME with HDD, OS on NVME with ZFS L2ARC and slog on NVME
elif [[ $NVME_TARGET_COUNT -ge 1 ]] && [[ $SSD_TARGET_COUNT -eq 0 ]] && [[ $HDD_TARGET_COUNT -ge 1 ]] ; then
  if [[ $NVME_TARGET_COUNT -eq 4 ]] ; then
    RAID="10"
  elif [[ $NVME_TARGET_COUNT -eq 2 ]] ; then
    RAID="1"
  else
    RAID=""
  fi
  ZFS_L2ARC="yes"
  ZFS_SLOG="yes"
  SWAP="yes"
  INSTALL_TARGET="${NVME_TARGET}"
fi

# check for ram size
#MEMORY_SIZE_GB=$(( $(vmstat -s | grep -i "total memory" | xargs | cut -d" " -f 1) / 1024 / 1000))
TARGET_SIZE_GB=$(( $(grep "${INSTALL_TARGET//,*}" -m1 /proc/partitions | xargs | cut -d" " -f3) / 1024 / 1024))

##### CONFIGURE BOOT PARTITION SIZE
if [ "$MY_BOOT" != "" ] ; then
  BOOT="${MY_BOOT}"
else
  BOOT=1
fi

##### CONFIGURE ROOT PARTITION SIZE
if [[ $MY_ROOT != "" ]] ; then
  ROOT=$MY_ROOT
elif [[ $TARGET_SIZE_GB -gt 800 ]] ; then
  ROOT=100
elif [[ $TARGET_SIZE_GB -gt 400 ]] ; then
  ROOT=60
elif [[ $TARGET_SIZE_GB -gt 200 ]] ; then
  ROOT=50
elif [[ $TARGET_SIZE_GB -gt 100 ]] ; then
  ROOT=40
elif [[ $TARGET_SIZE_GB -gt 50 ]] ; then
  ROOT=20
else
  ROOT=10
fi

#### CONFIGURE SWAP PARTITION SIZE&
if [ "$MY_SWAP" != "" ] ; then
  SWAP="${MY_SWAP}"
elif [ "${SWAP,,}" == "yes" ] || [ "${SWAP,,}" == "true" ] ; then
  if [[ $TARGET_SIZE_GB -gt 800 ]] ; then
    SWAP=128
  elif [[ $TARGET_SIZE_GB -gt 400 ]] ; then
    SWAP=64
  elif [[ $TARGET_SIZE_GB -gt 200 ]] ; then
    SWAP=32
  elif [[ $TARGET_SIZE_GB -gt 100 ]] ; then
    SWAP=16
  elif [[ $TARGET_SIZE_GB -gt 50 ]] ; then
    SWAP=8
  else
    SWAP=4
  fi
else
  SWAP=0
fi

#### CONFIGURE ZFS SLOG PARTITION SIZE&
if [ "$MY_ZFS_SLOG" != "" ] ; then
  ZFS_SLOG="${MY_ZFS_SLOG}"
elif [ "${ZFS_SLOG,,}" == "yes" ] || [ "${ZFS_SLOG,,}" == "true" ] ; then
  if [[ $TARGET_SIZE_GB -gt 800 ]] ; then
    ZFS_SLOG=64
  elif [[ $TARGET_SIZE_GB -gt 400 ]] ; then
    ZFS_SLOG=32
  elif [[ $TARGET_SIZE_GB -gt 200 ]] ; then
    ZFS_SLOG=16
  elif [[ $TARGET_SIZE_GB -gt 100 ]] ; then
    ZFS_SLOG=8
  elif [[ $TARGET_SIZE_GB -gt 50 ]] ; then
    ZFS_SLOG=4
  else
    ZFS_SLOG=2
  fi
else
  ZFS_SLOG=0
fi

#### CONFIGURE ZFS SLOG PARTITION SIZE&
if [ "$MY_ZFS_L2ARC" != "" ] ; then
  ZFS_SLOG="${MY_ZFS_L2ARC}"
elif [ "${ZFS_L2ARC,,}" == "yes" ] || [ "${ZFS_L2ARC,,}" == "true" ] ; then
  if [[ $TARGET_SIZE_GB -gt 800 ]] ; then
    ZFS_L2ARC=128
  elif [[ $TARGET_SIZE_GB -gt 400 ]] ; then
    ZFS_L2ARC=64
  elif [[ $TARGET_SIZE_GB -gt 200 ]] ; then
    ZFS_L2ARC=32
  elif [[ $TARGET_SIZE_GB -gt 100 ]] ; then
    ZFS_L2ARC=16
  elif [[ $TARGET_SIZE_GB -gt 50 ]] ; then
    ZFS_L2ARC=8
  else
    ZFS_L2ARC=4
  fi
else
  ZFS_L2ARC=0
fi

#### CHECK PARTITIONS WILL FIT ON DISK
if [[ $(( BOOT + ROOT + SWAP + ZFS_L2ARC + ZFS_SLOG + 1 )) -gt $TARGET_SIZE_GB ]] ; then
  echo "ERROR: Drive of ${TARGET_SIZE_GB} is too small"
  exit 1
fi

echo "--------------------------------"
echo "OS: ${OS}"
echo "LVM: ${LVM}"
echo "RAID: ${RAID}"
echo "BOOT: ${BOOT}"
echo "ROOT: ${ROOT}"
echo "SWAP: ${SWAP}"
echo "ZFS_L2ARC: ${ZFS_L2ARC}"
echo "ZFS_SLOG: ${ZFS_SLOG}"
echo "Total+1: $(( BOOT + ROOT + SWAP + ZFS_L2ARC + ZFS_SLOG + 1 ))"
echo "TARGET_SIZE_GB: ${TARGET_SIZE_GB}"
echo "INSTALL_TARGET: ${INSTALL_TARGET}"
echo "NVME_COUNT: ${NVME_COUNT}"
echo "NVME_TARGET: ${NVME_TARGET}"
echo "NVME_TARGET_COUNT: ${NVME_TARGET_COUNT}"
echo "SSD_COUNT: ${SSD_COUNT}"
echo "SSD_TARGET: ${SSD_TARGET}"
echo "SSD_TARGET_COUNT: ${SSD_TARGET_COUNT}"
echo "HDD_COUNT: ${HDD_COUNT}"
echo "HDD_TARGET: ${HDD_TARGET}"
echo "HDD_TARGET_COUNT: ${HDD_TARGET_COUNT}"
echo "--------------------------------"

#wait 10 seconds
sleep 10


# GENERATE PARTITION STRINGS

if [ "$SWAP" != "0" ]; then
  SWAP=",swap:swap:${SWAP}G"
else
  SWAP=""
fi
if [ "$ZFS_L2ARC" != "0" ]; then
  ZFS_L2ARC=",/xshok/zfs-L2ARC:ext4:${ZFS_L2ARC}G"
else
  ZFS_L2ARC=""
fi
if [ "$ZFS_SLOG" != "0" ]; then
  ZFS_SLOG=",/xshok/zfs-slog:ext4:${ZFS_SLOG}G"
else
  ZFS_SLOG=""
fi
if [ "$RAID" != "" ]; then
  RAID="-r yes -l ${RAID}"
else
  RAID=""
fi

if [ "$OS" == "PBS" ] ; then
  if [ ! -f postinstall_file="/root/pbs" ] ; then
    wget "https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/hetzner/pbs" -c -O /root/pbs
  fi
  postinstall_file="/root/pbs"
else
  if [ ! -f postinstall_file="/root/pve" ] ; then
    wget "https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/hetzner/pve" -c -O /root/pve
  fi
  postinstall_file="/root/pve"
fi

if [ ! -f "$postinstall_file" ] ; then
  echo "Error: postinstall file was not found: ${postinstall_file}"
  exit 1
fi
cp -f "$postinstall_file" /post-install-proxmox
chmod 777 /post-install-proxmox


if [ "${WIPE_PARTITION_TABLE,,}" == "yes" ] || [ "${WIPE_PARTITION_TABLE,,}" == "true" ] ; then
  IFS=', ' read -r -a INSTALL_TARGET_ARRAY <<< "${INSTALL_TARGET}"
  for install_device in "${INSTALL_TARGET_ARRAY[@]}"; do
    echo "Creating NEW GPT table: ${install_device}"
    printf "Yes\n" | parted "/dev/${install_device}" mklabel gpt ---pretend-input-tty || exit 1
    sleep 5
  done
fi


# INSTALL
if [ "$OS" == "PVE"  ]; then
  INSTALL_COMMAND="${installimage_bin} -a -t yes -i ${installimage_file} -g -s en -x /post-install-proxmox -n ${MY_HOSTNAME} -b grub -d ${INSTALL_TARGET} ${RAID} -p /boot:ext3:${BOOT}G,/:ext4:${ROOT}G${SWAP}${ZFS_L2ARC}${ZFS_SLOG},lvm:pve:all -v pve:data:/var/lib/vz:xfs:all"
else
  INSTALL_COMMAND="${installimage_bin} -a -t yes -i ${installimage_file} -g -s en -x /post-install-proxmox -n ${MY_HOSTNAME} -b grub -d ${INSTALL_TARGET} ${RAID} -p /boot:ext3:${BOOT}G,/:ext4:${ROOT}G${SWAP}${ZFS_L2ARC}${ZFS_SLOG},/backup:xfs:all"
fi

echo "Starting Installer ...."
echo "launching via a screen process, incase your connection is disconnected"
echo "run this script again to automatically reconnect to it."

screen -mS proxmox-install /usr/bin/bash -c "$INSTALL_COMMAND"

echo "Please reboot to load proxmox"

# usage:  installimage [options]
#   -a                    automatic mode / batch mode
#   -x <post-install>     Use this file as post-install script, that will be executed after installation inside the chroot.
#   -n <hostname>         set the specified hostNAME.
#   -r <yes|no>           activate software RAID or not.
#   -l <0|1|5|6|10>       set the specified raid LEVEL.
#   -i <imagepath>        use the specified IMAGE to install (full path to the OS image)
#   -g                    Use this to force validation of the image file with detached GPG signature.
#   -p <partitions>       define the PARTITIONS to create, example:
#                         - regular partitions:  swap:swap:4G,/:ext3:all
#                         - lvm setup example:   /boot:ext2:256M,lvm:vg0:all
#   -v <logical volumes>  define the logical VOLUMES you want to be created
#                         - example: vg0:root:/:ext3:20G,vg0:swap:swap:swap:4G
#   -d <drives>           /dev names of DRIVES to use, e.g.: sda or sda,sdb
#   -f <yes|no>           FORMAT the second drive (if not used for raid)?
#   -s <de|en>            Language to use for different things (e.g.PLESK)
#   -z PLESK_<Version>    Install optional software like PLESK with version <Version>
#   -K <path/url>         Install SSH-Keys from file/URL
#   -t <yes|no>           Take over rescue system SSH public keys
#   -u <yes|no>           Allow usb drives
#   -G <yes|no>           Generate new SSH host keys (default: yes)
