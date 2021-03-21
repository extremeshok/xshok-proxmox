# Hetzner Proxmox Installation Guide #
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
* Connect via ssh/terminal to the rescue system running on your server and run the following
````
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/hetzner/hetzner-install-proxmox.sh -c -O hetzner-install-proxmox.sh && chmod +x hetzner-install-proxmox.sh
./hetzner-install-proxmox.sh "your.hostname.here"
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
