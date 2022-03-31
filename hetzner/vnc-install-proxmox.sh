#!/usr/bin/env bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################
#
# Script updates can be found at: https://github.com/extremeshok/xshok-proxmox
#
# VNC Installation script for Proxmox VE and Backup Server
#
# License: BSD (Berkeley Software Distribution)
#
##############################################################################
# Usage :
########## Proxmox VE
# vnc-install-proxmox.sh
########## Backup Server
# vnc-install-proxmox.sh pbs
#
###############################################################################
## Assumptions:
# Run this script from a fresh rescue system
# Operating system=Linux, Architecture=64 bit, Public key=*optional*
#
# Will automatically detect nvme, ssd and hdd and configure accordingly.
#
# sata ssd is used (boot and root) instead of nvme
# will use nvme, if sda is a spinning disk
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
################################################################################

# Set the local
export LANG="en_US.UTF-8"
export LC_ALL="C"

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

MY_IFACE="$(udevadm info -e | grep -m1 -A 20 ^P.*eth0 | grep ID_NET_NAME_PATH | cut -d'=' -f2)"

MY_IP4_AND_NETMASK="$(ip address show ${MY_IFACE} | grep global | grep "inet "| xargs | cut -d" " -f2)"

MY_IP6_AND_NETMASK="$(ip address show ${MY_IFACE} | grep global | grep "inet6 "| xargs | cut -d" " -f2)"

MY_IP4_GATEWAY="$(ip route | grep default | xargs | cut -d" " -f3)"

MY_DNS_SERVER="$(resolvectl status | grep "Current DNS Server" | cut -d":" -f2 | xargs)"

if [ "$OS" == "PBS" ] ; then
  if [ ! -f INSTALL_IMAGE="proxmox-pbs.iso" ] ; then
    wget "http://download.proxmox.com/iso/proxmox-backup-server_2.1-1.iso" -c -O proxmox-pbs.iso || exit 1
  fi
  INSTALL_IMAGE="proxmox-pbs.iso"
else
  if [ ! -f INSTALL_IMAGE="" ] ; then
     wget "http://download.proxmox.com/iso/proxmox-ve_7.1-2.iso" -c -O proxmox-ve.iso || exit 1
  fi
  INSTALL_IMAGE="proxmox-ve.iso"
fi

# Generate NVME Device Arrays
mapfile -t NVME_ARRAY < <( ls -1 /sys/block | grep ^nvme | sort -d )
NVME_COUNT=${#NVME_ARRAY[@]}
NVME_TARGET=""
NVME_TARGET_FIRST=""
NVME_TARGET_COUNT=0
if [[ $NVME_COUNT -ge 1 ]] ; then
  for nvme_device in "${NVME_ARRAY[@]}"; do
    if [ "${NVME_FORCE_4K,,}" == "yes" ] || [ "${NVME_FORCE_4K,,}" == "true" ] ; then
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
INSTALL_TARGET=""
INSTALL_COUNT=0
INSTALL_NVME="no"
#NVME only
if [[ $NVME_TARGET_COUNT -ge 1 ]] && [[ $SSD_TARGET_COUNT -eq 0 ]] && [[ $HDD_TARGET_COUNT -eq 0 ]]; then
  INSTALL_TARGET="${NVME_TARGET}"
  INSTALL_COUNT=$NVME_TARGET_COUNT
  INSTALL_NVME="yes"
#SSD Only
elif [[ $NVME_TARGET_COUNT -eq 0 ]] && [[ $SSD_TARGET_COUNT -ge 1 ]] && [[ $HDD_TARGET_COUNT -eq 0 ]] ; then
  INSTALL_TARGET="${SSD_TARGET}"
  INSTALL_COUNT=$SSD_TARGET_COUNT
#HDD Only
elif [[ $NVME_TARGET_COUNT -eq 0 ]] && [[ $SSD_TARGET_COUNT -eq 0 ]] && [[ $HDD_TARGET_COUNT -ge 1 ]] ; then
  INSTALL_TARGET="${HDD_TARGET}"
  INSTALL_COUNT=$SSD_TARGET_COUNT
#NVME with SSD, OS on SSD
elif [[ $NVME_TARGET_COUNT -ge 1 ]] && [[ $SSD_TARGET_COUNT -ge 1 ]] && [[ $HDD_TARGET_COUNT -eq 0 ]] ; then
  INSTALL_TARGET="${SSD_TARGET}"
  INSTALL_COUNT=$SSD_TARGET_COUNT
#SSD with HDD, OS on SSD with ZFS L2ARC and slog on SSD
elif [[ $NVME_TARGET_COUNT -eq 0 ]] && [[ $SSD_TARGET_COUNT -ge 1 ]] && [[ $HDD_TARGET_COUNT -ge 1 ]] ; then
  INSTALL_TARGET="${SSD_TARGET}"
  INSTALL_COUNT=$SSD_TARGET_COUNT
#NVME with SSD and HDD, OS on SSD
elif [[ $NVME_TARGET_COUNT -ge 1 ]] && [[ $SSD_TARGET_COUNT -ge 1 ]] && [[ $HDD_TARGET_COUNT -ge 1 ]] ; then
  INSTALL_TARGET="${SSD_TARGET}"
  INSTALL_COUNT=$SSD_TARGET_COUNT
#NVME with HDD, OS on NVME with ZFS L2ARC and slog on NVME
elif [[ $NVME_TARGET_COUNT -ge 1 ]] && [[ $SSD_TARGET_COUNT -eq 0 ]] && [[ $HDD_TARGET_COUNT -ge 1 ]] ; then
  INSTALL_TARGET="${NVME_TARGET}"
  INSTALL_COUNT=$NVME_TARGET_COUNT
  INSTALL_NVME="yes"
fi

# Generate DISK config for VM
#alpha=({a..z})
#yc=0
IFS=', ' read -r -a INSTALL_TARGET_ARRAY <<< "${INSTALL_TARGET}"
DISKS=""
for install_device in "${INSTALL_TARGET_ARRAY[@]}"; do
  if [ "${INSTALL_NVME,,}" == "yes" ]; then
    install_device_serial="$(nvme id-ctrl "/dev/${install_device}" | grep "^sn" | xargs | cut -d":" -f 2 | xargs)"
    if [ "$install_device_serial" != "" ] ; then
      DISKS="${DISKS} -device nvme,drive=${install_device::-2},serial=${install_device_serial} -drive file=/dev/${install_device},format=raw,if=none,id=${install_device::-2}"
    else
      DISKS="${DISKS} -device nvme,drive=${install_device::-2} -drive file=/dev/${install_device},format=raw,if=none,id=${install_device::-2}"
    fi
  else
    DISKS="${DISKS} -drive file=/dev/${install_device},format=raw,media=disk,if=virtio"
  fi
done
if [ "${WIPE_PARTITION_TABLE,,}" == "yes" ] || [ "${WIPE_PARTITION_TABLE,,}" == "true" ] ; then
  for install_device in "${INSTALL_TARGET_ARRAY[@]}"; do
    echo "Creating NEW GPT table: ${install_device}"
    printf "Yes\n" | parted "/dev/${install_device}" mklabel gpt ---pretend-input-tty
    sleep 1
  done
fi

echo "--------------------------------"
echo "NVME_FORCE_4K: ${NVME_FORCE_4K}"
echo "WIPE_PARTITION_TABLE: ${WIPE_PARTITION_TABLE}"
echo "MY_IFACE: ${MY_IFACE}"
echo "MY_IP4_AND_NETMASK: ${MY_IP4_AND_NETMASK}"
echo "MY_IP4_GATEWAY: ${MY_IP4_GATEWAY}"
echo "MY_IP6_AND_NETMASK: ${MY_IP6_AND_NETMASK}"
echo "MY_DNS_SERVER: ${MY_DNS_SERVER}"
echo "INSTALL_TARGET: ${INSTALL_TARGET}"
echo "INSTALL_COUNT: ${INSTALL_COUNT}"
echo "INSTALL_NVME: ${INSTALL_NVME}"
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

#GENERATE A RANDOM 32CHAR VNC PASSWORD
MY_RANDOM_PASS="$(tr -dc 'a-zA-Z0-9' < "/dev/urandom" | fold -w 32 | head -n 1 | xargs)"

echo ""
echo ">> CONNECT VIA VNC TO ${MY_IP4_AND_NETMASK%/*} WITH PASSWORD ${MY_RANDOM_PASS}"
echo "** Please use the following, install options **"
echo "Target Harddisk: [OPTIONS]"
if [[ $INSTALL_COUNT -ge 8 ]] ; then
  echo "Filesystem: zfs (RAIDZ-2)"
elif [[ $INSTALL_COUNT -ge 3 ]] ; then
  echo "Filesystem: zfs (RAIDZ-1)"
elif [[ $INSTALL_COUNT -ge 2 ]] ; then
  echo "Filesystem: zfs (RAID1)"
fi
echo "Keyboard Layout: U.S. English"

echo "IP Address (CIDR): ${MY_IP4_AND_NETMASK}"
echo "Gateway: ${MY_IP4_GATEWAY}"
echo "DNS Server: ${MY_DNS_SERVER}"
echo "********************************"

echo ">> CONNECT VIA VNC TO ${MY_IP4_AND_NETMASK%/*} WITH PASSWORD ${MY_RANDOM_PASS}"

printf "change vnc password\n%s\n" ${MY_RANDOM_PASS} | qemu-system-x86_64 -machine type=q35,accel=kvm -cpu host -enable-kvm -smp 4 -m 4096 -boot d -cdrom ${INSTALL_IMAGE} ${DISKS} -vnc :0,password -monitor stdio -no-reboot

#https://blogs.oracle.com/linux/post/how-to-emulate-block-devices-with-qemu

printf "n\n" | zfsonlinux_install 2&> /dev/null
retVal=$?
if [ $retVal -eq 1 ]; then
  echo "Installing zfsonlinux"
  printf "y\n" | zfsonlinux_install
  echo "Correcting network config"
  zpool import -f -R /mnt rpool
  sed -i -e "s/enp[0-9]s[0-9]/${MY_IFACE}/g" /mnt/etc/network/interfaces
  #cat /mnt/etc/network/interfaces
  zpool export -f rpool
else
  echo "zfsonlinux_install not detected, launching vnc to complete networking config."
  echo ">> SERVER SHOULD BE INSTALLED, RESTARTING <<"
  echo ""
  echo ">>  RE-CONNECT VIA VNC TO ${MY_IP4_AND_NETMASK%/*} WITH PASSWORD ${MY_RANDOM_PASS}"
  echo ""
  echo "Login as root, with the password which was set during install"
  echo ">> run the following command below"
  echo "nano /etc/network/interfaces"
  echo "** edit the file to have the following **"
  echo "
auto lo
iface lo inet loopback

iface ${MY_IFACE} inet manual

auto vmbr0
iface vmbr0 inet static
    address ${MY_IP4_AND_NETMASK}
    gateway ${MY_IP4_GATEWAY}
    bridge_ports ${MY_IFACE}
    bridge_stp off
    bridge_fd 0
  "
  echo ">> save the file <<"
  echo "export the zfs pool, so the machine will boot correctly "
  echo ">> run the following command below"
  echo "zpool export -f rpool"
  printf "change vnc password\n%s\n" ${MY_RANDOM_PASS} | qemu-system-x86_64 -enable-kvm -smp 4 -m 4096 $DISKS -vnc :0,password -monitor stdio -no-reboot -serial telnet:localhost:4321,server,nowait

fi

echo ">> COMPLETED PROXMOX IS NOW INSTALLED"
echo ""
echo ">> PLEASE REBOOT and connect to https://${MY_IP4_AND_NETMASK%/*}:8006"
