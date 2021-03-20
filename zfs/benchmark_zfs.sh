#!/usr/bin/env bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################
#
# Script updates can be found at: https://github.com/extremeshok/xshok-proxmox
# Based on https://blog.programster.org/zfs-add-intent-log-device
#
# License: BSD (Berkeley Software Distribution)
#
################################################################################

# Set the local
export LANG="en_US.UTF-8"
export LC_ALL="C"

if [ ! -e /usr/bin/time ] ; then
  /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install time
fi

echo "Performing cached write of 1,000,000 4k blocks..."
/usr/bin/time -f "%e" sh -c 'dd if=/dev/zero of=4k-test.img bs=4k count=1000000 2> /dev/null'

rm 4k-test.img
echo ""
sleep 3


echo "Performing cached write of 10,000 1M blocks..."
/usr/bin/time -f "%e" sh -c 'dd if=/dev/zero of=1GB.img bs=1M count=10000 2> /dev/null'

rm 1GB.img
echo ""
sleep 3


echo "Performing non-cached write of 1,000,000 4k blocks..."
/usr/bin/time -f "%e" sh -c 'dd if=/dev/zero of=4k-test.img bs=4k count=1000000 conv=fdatasync 2> /dev/null'

rm 4k-test.img
echo ""
sleep 3


echo "Performing non-cached write of 10,000 1M blocks..."
/usr/bin/time -f "%e" sh -c 'dd if=/dev/zero of=1GB.img bs=1M count=10000 conv=fdatasync 2> /dev/null'

rm 1GB.img
echo ""
sleep 3


echo "Performing sequential write of 10,000 4k blocks..."
/usr/bin/time -f "%e" sh -c 'dd if=/dev/zero of=4k-test.img bs=4k count=10000 oflag=dsync 2> /dev/null'

rm 4k-test.img
echo ""
sleep 3

echo "Performing sequential write of 10,000 1M blocks..."
/usr/bin/time -f "%e" sh -c 'dd if=/dev/zero of=1GB.img bs=1M count=10000 oflag=dsync 2> /dev/null'

rm 1GB.img
