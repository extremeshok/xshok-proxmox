# Hetzner Proxmox Installation Guide #

## Assumptions:
Run this script from the hetzner rescue system
Operating system=Linux, Architecture=64 bit, Public key=*optional*

Will automatically detect nvme, ssd and hdd and configure accordingly.

# Semi-Automated Using VNC

## VNC Install (Native install Proxmox from ISO  on systems without ipmi)
## Notes:
Will automatically detect nvme, ssd and hdd and configure accordingly.
sata ssd is used (boot and root) instead of nvme
will use nvme, if sda is a spinning disk

### Proxmox VE (PVE)
```
curl -O https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/hetzner/vnc-install-proxmox.sh && chmod +x vnc-install-proxmox.sh
./vnc-install-proxmox.sh
```

### Proxmox Backup Server (PBS)
```
curl -O https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/hetzner/vnc-install-proxmox.sh && chmod +x vnc-install-proxmox.sh
./vnc-install-proxmox.sh pbs
```

# Automated Using Installimage

## Notes:
ext3 boot partition of 1GB
ext4 root partition adjusted according to available drive space, upto 128GB

sata ssd is used (boot and root) instead of nvme
will use nvme as target, if sda is a spinning disk
slog and L2ARC if nvme is present, no ssd and hdd is present
slog and L2ARC if ssd is present, no nvme and hdd is present

*includes and runs the  (install-post.sh) script*
* Select the Rescue tab for the specific server, via the hetzner robot manager
* * Operating system=Linux
* * Architecture=64 bit
* * Public key=*optional*
* --> Activate rescue system
* Select the Reset tab for the specific server,
* Check: Execute an automatic hardware reset
* --> Send
* Wait a few mins
* Connect via ssh/terminal to the rescue system running on your server and run either of the following
* To Install Proxmox VE (PVE)
````
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/hetzner/installimage-proxmox.sh -c -O installimage-proxmox.sh && chmod +x installimage-proxmox.sh
./installimage-proxmox.sh "your.hostname.here"
````
* To Install Proxmox Backup Server (PBS)
````
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/hetzner/installimage-proxmox.sh -c -O installimage-proxmox.sh && chmod +x installimage-proxmox.sh
./installimage-proxmox.sh "your.hostname.here" pbs
````
* Reboot
* Connect via ssh/terminal to the new Proxmox system running on your server and run the following

## LVM to ZFS
````
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/zfs/lvm-2-zfs.sh -c -O lvm-2-zfs.sh  && chmod +x lvm-2-zfs.sh
 ./lvm-2-zfs.sh && rm lvm-2-zfs.sh
````
* Reboot
* Connect via ssh/terminal to the new Proxmox system running on your server and run the following

## NETWORKING (vmbr0 vmbr1)
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/networking/network-configure.sh -c -O network-configure.sh && chmod +x network-configure.sh
./network-configure.sh && rm network-configure.sh
```
* Reboot
* Post Install: Now login via ssh as root and create a password, which will be used for the webinterface when logging in with pam authentication

## OPTIONAL: POST INSTALL OPTIMISATION
```
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/install-post.sh -c -O install-post.sh && chmod +x install-post.sh
./install-post.sh && rm install-post.sh
