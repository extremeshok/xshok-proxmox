# xshok-proxmox :: eXtremeSHOK.com Proxmox (pve)

## Optimization / Post Install Script (install-post.sh aka postinstall.sh) *run once*
*not required if server setup with install-hetzner.sh*
* 'reboot-quick' command which uses kexec to boot the latest kernel set in the boot loader
* Force APT to use IPv4
* Disable the enterprise repo, enable the public repo, Add non-free sources
* Fixes known bugs (public key missing, max user watches, etc)
* Update the system
* Install ceph, ksmtuned, openvswitch-switch, zfsutils and common system utilities
* Increase vzdump backup speed, enable pigz and fix ionice
* Increase max Key limits,  max user watches, max File Discriptor Limits, ulimits
* Detect AMD EPYC CPU and install kernel 4.15
* Detect AMD EPYC CPU and Apply EPYC fixes to kernel and KVM
* Install and configure ZFS-auto-snapshots (12x5min, 7daily, 4weekly, 3monthly)
* Disable portmapper / rpcbind (security)
* set-timezone UTC and enable timesyncd as nntp client
* Set pigz to replace gzip, 2x faster gzip compression
* Detect OVH Server and install OVH RTM (real time monitoring)"
* Protect the webinterface with fail2ban (security)
* Optimize ZFS arc size depending on installed memory, Use 1/16 RAM for MAX cache, 1/8 RAM for MIN cache, or 1GB
* ZFS Tuning, set prefetch method and max write speed to l2arc
* Enable TCP BBR congestion control, improves overall network throughput


wget https://raw.githubusercontent.com/tinof/xshok-proxmox/master/install-hetzner.sh -c -O install-hetzner.sh && chmod +x install-hetzner.sh
./install-hetzner.sh
