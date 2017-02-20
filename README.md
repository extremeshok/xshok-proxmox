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
curl -O https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/postinstall.sh && bash postinstall.sh && rm postinstall.sh
```
# Convert to ZFS (lvm2zfs.sh) *run once*
Converts the storage into a ZFS raid 1 (mirror)
```
curl -O https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/lvm2zfs.sh && bash lvm2zfs.sh && rm lvm2zfs.sh
```

# Create Private mesh vpn/network (tincvpn.sh)
tinc private mesh vpn/network which supports multicast, ideal for private cluster communication
```
curl -O https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/tincvpn.sh && bash tincvpn.sh -h
```
