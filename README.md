# xshok-proxmox

## Install Proxmox
Recommeneded partitioning scheme:

Raid 1 (mirror) 100GB ext4 /

2x swap 8192mb (16GB total)

Remaining unpartitioned

# Post Install Script (postinstall.sh) *run once*
https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/postinstall.sh

Or run *postinstall.sh* after installation

```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/postinstall.sh -c -O postinstall.sh && bash postinstall.sh && rm postinstall.sh
```
# Convert from LVM to ZFS (lvm2zfs.sh) *run once*
Converts the storage into a ZFS raid 1 (mirror)
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/lvm2zfs.sh -c -O lvm2zfs.sh && bash lvm2zfs.sh && rm lvm2zfs.sh
```

# Create Private mesh vpn/network (tincvpn.sh)
tinc private mesh vpn/network which supports multicast, ideal for private cluster communication
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/tincvpn.sh -c -O tincvpn.sh && bash tincvpn.sh -h
```
## Example for 3 node Cluster
### First Host (hostname: host1)
```
bash tincvpn.sh -i 1 -c host2
```
### Second Host (hostname: host2)
```
bash tincvpn.sh -i 2 -c host3
```
### Third Host (hostname: host3)
```
bash tincvpn.sh -3 -c host1
```
