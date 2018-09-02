#!/bin/bash
# https://blog.programster.org/zfs-add-intent-log-device

echo "Performing cached write of 100,000 4k blocks..."
/usr/bin/time -f "%e" sh -c 'dd if=/dev/zero of=4k-test.img bs=4k count=100000 2> /dev/null'

rm 4k-test.img
echo ""
sleep 3


echo "Performing cached write of 1,000 1M blocks..."
/usr/bin/time -f "%e" sh -c 'dd if=/dev/zero of=1GB.img bs=1M count=1000 2> /dev/null'

rm 1GB.img
echo ""
sleep 3


echo "Performing non-cached write of 100,000 4k blocks..."
/usr/bin/time -f "%e" sh -c 'dd if=/dev/zero of=4k-test.img bs=4k count=100000 conv=fdatasync 2> /dev/null'

rm 4k-test.img
echo ""
sleep 3


echo "Performing non-cached write of 1,000 1M blocks..."
/usr/bin/time -f "%e" sh -c 'dd if=/dev/zero of=1GB.img bs=1M count=1000 conv=fdatasync 2> /dev/null'

rm 1GB.img
echo ""
sleep 3


echo "Performing sequential write of 1,000 4k blocks..."
/usr/bin/time -f "%e" sh -c 'dd if=/dev/zero of=4k-test.img bs=4k count=1000 oflag=dsync 2> /dev/null'

rm 4k-test.img
echo ""
sleep 3

echo "Performing sequential write of 1,000 1M blocks..."
/usr/bin/time -f "%e" sh -c 'dd if=/dev/zero of=1GB.img bs=1M count=1000 oflag=dsync 2> /dev/null'

rm 1GB.img
