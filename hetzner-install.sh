#!/bin/bash
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
# Assumes 2 identical disks at /dev/sda and /dev/ssb, it ignores any extra disks
# software raid 1 (mirror) will be setup as well as LVM and will automatically detect and set the swap size
#
################################################################################
#
#
#   ALL CONFIGURATION OPTIONS ARE LOCATED BELOW THIS MESSAGE
#
##############################################################

#set size of swap file or leave blank for autoconfig, USE NUMBER ONLY, will be in gbytes
MY_SWAP=""
#comment out to disable LVM and use a very simple partition setup of / and swap
USE_LVM="TRUE"

##############################################################

installimage_bin="/root/.oldroot/nfs/install/installimage"

MY_HOSTNAME="$1"
if [ "$MY_HOSTNAME" == "" ]; then
  echo "Please set a hostname"
  echo "$0 host.name" 
  exit 1
fi

# HDD less than 130gb = 16GB swap
# RAM less or equal to 64GB = 32GB swap
# RAM more than 64GB = 64GB swap

if [ "$MY_SWAP" == "" ]; then
  echo "Detecting and setting optimal swap partition size"
  if [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -gt "130" ]] ; then
    if [[ $(( $(vmstat -s | grep -i "total memory" | xargs | cut -d" " -f 1) / 1024 / 1000)) -le "64" ]] ; then
      MY_SWAP="32"
    else
      MY_SWAP="64"
    fi
  else
    MY_SWAP="16"
  fi
else
  if ! [ $MY_SWAP -ne 0 -o $MY_SWAP -eq 0 2>/dev/null ] ; then
    echo "MY_SWAP is not an integer"
    exit 1
  fi  
fi

echo "Set swap size to ${MY_SWAP} GBytes"

#fetching post install
curl "https://raw.githubusercontent.com/hetzneronline/installimage/master/post-install/proxmox5" --output /post-install

#Customising post install file
echo "wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/postinstall.sh -c -O postinstall.sh && bash postinstall.sh && rm postinstall.sh" >> /post-install

if grep -q '#!/bin/bash' "/post-install"; then
  echo "Starting Installer"
  if [ "$USE_LVM" == "TRUE" ]; then
    $installimage_bin -a -i "root/images/Debian-94-stretch-64-minimal.tar.gz" -g -s en -x /post-install -n "${MY_HOSTNAME}" -b grub -d sda,sdb -r yes -l 1 -p "/:ext4:40G,swap:swap:${MY_SWAP}G,lvm:vg0:all" -v "vg0:data:/var/lib/vz:ext4:all"
  else
    $installimage_bin -a -i "root/images/Debian-94-stretch-64-minimal.tar.gz" -g -s en -x /post-install -n "${MY_HOSTNAME}" -b grub -d sda,sdb -r yes -l 1 -p "/:ext4:all,swap:swap:${MY_SWAP}G"
  fi
  
else
  echo "Failed to fetch post-install"
  exit 1
fi
