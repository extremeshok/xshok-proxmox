#!/bin/bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################
# 
# Script updates can be found at: https://github.com/extremeshok/xshok-proxmox
#
# post-installation script for Proxmox
#
# License: BSD (Berkeley Software Distribution)
#
################################################################################
#
# Assumptions: proxmox installed
# Recommeneded partitioning scheme:
# Raid 1 / 100GB ext4
# 2x swap 8192mb (16384mb total)
# Remaining unpartitioned
#
################################################################################
#
#    THERE ARE  USER CONFIGURABLE OPTIONS IN THIS SCRIPT
#   ALL CONFIGURATION OPTIONS ARE LOCATED BELOW THIS MESSAGE
#
##############################################################

# disable enterprise proxmox repo
if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
	echo -e "#deb https://enterprise.proxmox.com/debian jessie pve-enterprise\n" > /etc/apt/sources.list.d/pve-enterprise.list
fi
# enable public proxmox repo
if [ ! -f /etc/apt/sources.list.d/pve-public-repo.list ] && [ ! -f /etc/apt/sources.list.d/pve-install-repo.list ] ; then
	echo -e "deb http://download.proxmox.com/debian jessie pve-no-subscription\n" > /etc/apt/sources.list.d/pve-public-repo.list
fi

# Add non-free to sources
sed -i "s/main contrib/main non-free contrib/g" /etc/apt/sources.list

# Install the latest ceph (jewel, aka ceph 10.2.5 or higher)
sed -i "s/hammer/jewel/g" /etc/apt/sources.list.d/ceph.list

#Bugfix frozen/hung update caused by broken ceph systemd script
if [ -f /etc/systemd/system/ceph.service ]; then
	sed -i "s/=ceph.target/=multi-user.target/" /etc/systemd/system/ceph.service
	systemctl daemon-reload; systemctl disable ceph.service; systemctl enable ceph.service; systemctl daemon-reexec
fi

## Update proxmox and install various system utils
apt-get update && apt-get -y dist-upgrade --force-yes
pveam update

## Remove no longer required packages and purge old cached updates
apt-get -y autoremove
apt-get -y autoclean

## Install openvswitch for a virtual internal network
apt-get install -y openvswitch-switch

## Install zfs support, appears to be missing on some Proxmox installs.
apt-get install -y zfsutils

## Install ceph support
pveceph install -y

## Install common system utilities
apt-get install -y omping wget axel nano ntp pigz net-tools htop iptraf iotop iftop iperf vim vim-nox screen unzip zip python-software-properties aptitude curl dos2unix dialog mlocate build-essential git
#snmpd snmp-mibs-downloader

# Set pigz to replace gzip, 2x faster gzip compression
#cat > /bin/pigzwrapper <<EOF
##!/bin/sh
#PATH=\${GZIP_BINDIR-'/bin'}:\$PATH
##GZIP="-1"
#exec /usr/bin/pigz -p 4 "\$@"
#EOF
#chmod 755 /bin/pigzwrapper
#mv /bin/gzip /bin/gzip.original
#ln -s /bin/pigzwrapper /bin/gzip

# Protect the web interface with fail2ban
apt-get install -y fail2ban
cat > /etc/fail2ban/filter.d/proxmox.conf <<EOF
[Definition]
failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.* msg=.*
ignoreregex =
EOF
cat > /etc/fail2ban/jail.d/proxmox <<EOF
[proxmox]
enabled = true
port = https,http,8006
filter = proxmox
logpath = /var/log/daemon.log
maxretry = 3
# 1 hour
bantime = 3600
EOF
systemctl enable fail2ban
systemctl restart fail2ban
##testing
#fail2ban-regex /var/log/daemon.log /etc/fail2ban/filter.d/proxmox.conf

## Increase vzdump backup speed:q
sed -i "s/#bwlimit: KBPS/bwlimit: 102400/" /etc/vzdump.conf

## remove subscription banner
sed -i "s|if (data.status !== 'Active')|if (data.status == 'Active')|g" /usr/share/pve-manager/js/pvemanagerlib.js
##create a daily cron to make sure the banner does not re-appear
cat > /etc/cron.daily/proxmox-nosub <<EOF
#!/bin/sh
sed -i "s|if (data.status !== 'Active')|if (data.status == 'Active')|g" /usr/share/pve-manager/js/pvemanagerlib.js
EOF
chmod 755 /etc/cron.daily/proxmox-nosub 

if ! grep -q https "/etc/motd" ; then
cat > /etc/motd.new <<'EOF'
   This system is managed by:            https://eXtremeSHOK.com
     __   ___                            _____ _    _  ____  _  __
     \ \ / / |                          / ____| |  | |/ __ \| |/ /
  ___ \ V /| |_ _ __ ___ _ __ ___   ___| (___ | |__| | |  | | ' / 
 / _ \ > < | __| '__/ _ \ '_ ` _ \ / _ \\___ \|  __  | |  | |  <  
|  __// . \| |_| | |  __/ | | | | |  __/____) | |  | | |__| | . \ 
 \___/_/ \_\\__|_|  \___|_| |_| |_|\___|_____/|_|  |_|\____/|_|\_\


EOF
	cat /etc/motd >> /etc/motd.new
	mv /etc/motd.new /etc/motd
fi

## Increase max user watches
## BUG FIX : No space left on device
echo 1048576 > /proc/sys/fs/inotify/max_user_watches
echo "fs.inotify.max_user_watches=1048576" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

## Increase max FD limit / ulimit
cat <<'EOF' >> /etc/security/limits.conf
* soft     nproc          131072    
* hard     nproc          131072   
* soft     nofile         131072   
* hard     nofile         131072
root soft     nproc          131072    
root hard     nproc          131072   
root soft     nofile         131072   
root hard     nofile         131072
EOF
 
#script Finish
echo -e '\033[1;33m Finished....please restart the server \033[0m'
return 1


