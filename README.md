# xshok-proxmox

## Install Proxmox
Recommeneded partitioning scheme:
Raid 1 (mirror) 100GB ext4 /
2x swap 8192mb (16GB total)
Remaining unpartitioned

Run *postinstall.sh* after installation to optimise and configure a default Proxmox install

https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/postinstall.sh

Return value is 1

## 

Run *lvm2zfs.sh* after "postinstall.sh" to convert the storage into a ZFS mirror

Run *tincvpn.sh* to create a private mesh vpn/network which supports multicast, ideal for cluster communication
