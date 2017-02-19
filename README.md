# xshok-proxmox

## Install Proxmox
Recommeneded partitioning scheme:

Raid 1 (mirror) 100GB ext4 /

2x swap 8192mb (16GB total)

Remaining unpartitioned

# Post Install Script
https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/postinstall.sh

Or run *postinstall.sh* after installation

curl -O https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/postinstall.sh && bash postinstall.sh && rm postinstall.sh

## 

Run *lvm2zfs.sh* after "postinstall.sh" to convert the storage into a ZFS mirror

Run *tincvpn.sh* to create a private mesh vpn/network which supports multicast, ideal for cluster communication
