#!/usr/bin/env bash
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
# Version: 2.0-beta
#
# Assumptions: proxmox installed
#
# Notes:
# openvswitch will be disabled (removed) when ifupdown2 is enabled
# ifupdown2 will be disabled (removed) when openvswitch is enabled
#
# Todo:
# Docker ?
#
################################################################################
#
#    THERE ARE NO USER CONFIGURABLE OPTIONS IN THIS SCRIPT
#
################################################################################

#### VARIBLES / options
XS_AMDFIXES="yes"
XS_APTUPGRADE="yes"
XS_BASHRC="yes"
XS_CEPH="yes"
XS_DISABLERPC="yes"
XS_DISENTREPO="yes"
XS_FAIL2BAN="yes"
XS_IFUPDOWN2="yes"
XS_KERNELHEADERS="yes"
XS_KEXEC="yes"
XS_KSMTUNED="yes"
XS_LIMITS="yes"
XS_MEMORYFIXES="yes"
XS_MOTD="yes"
XS_NOSUBBANNER="yes"
XS_OPENVSWITCH="no"
XS_OVHRTM="yes"
XS_PIGZ="yes"
XS_TCPBBR="yes"
XS_TIMESYNC="yes"
XS_TIMEZONE="" #set auto by ip
XS_VZDUMP="yes"
XS_ZFSARC="yes"
XS_ZFSAUTOSNAPSHOT="yes"

# varibles/options are overrideen with xs.env
if [ -f xs.env ] ; then
    source xs.env;
fi

# Set the local
export LANG="en_US.UTF-8"
export LC_ALL="C"

# SET VARIBLES
RAM_SIZE_GB=$(( $(vmstat -s | grep -i "total memory" | xargs | cut -d" " -f 1) / 1024 / 1000))

## Force APT to use IPv4
echo -e "Acquire::ForceIPv4 \"true\";\\n" > /etc/apt/apt.conf.d/99force-ipv4

if [ "$XS_DISENTREPO" == "yes" ] ; then
    ## disable enterprise proxmox repo
    if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
      sed -i "s/^deb/#deb/g" /etc/apt/sources.list.d/pve-enterprise.list
    fi
else
    ## enable public proxmox repo
    if [ ! -f /etc/apt/sources.list.d/proxmox.list ] && [ ! -f /etc/apt/sources.list.d/pve-public-repo.list ] && [ ! -f /etc/apt/sources.list.d/pve-install-repo.list ] ; then
      echo -e "deb http://download.proxmox.com/debian/pve buster pve-no-subscription\\n" > /etc/apt/sources.list.d/pve-public-repo.list
    fi
fi
## Add the latest ceph provided by proxmox
echo "deb http://download.proxmox.com/debian/ceph-nautilus buster main" > /etc/apt/sources.list.d/ceph.list

## Add non-free and contrib to sources
sed -i "s/main /main non-free/g" /etc/apt/sources.list
sed -i "s/main /main contrib/g" /etc/apt/sources.list

## Refresh the package lists
apt-get update > /dev/null

## Remove conflicting utilities
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' purge ntp openntpd chrony

## Fix no public key error for debian repo
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install debian-archive-keyring

if [ "$XS_APTUPGRADE" == "yes" ] ; then
    ## Update proxmox and install various system utils
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' dist-upgrade
    pveam update
fi

## Install packages which are sometimes missing on some Proxmox installs.
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install zfsutils

## Install common system utilities
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install \
aptitude \
axel \
build-essential \
curl \
dialog \
dnsutils \
dos2unix \
git \
grc \
htop \
iftop \
iotop \
iperf \
ipset \
iptraf \
mlocate \
msr-tools \
nano \
net-tools \
omping \
software-properties-common \
sshpass \
tmux \
unzip \
vim \
vim-nox \
wget \
whois \
zip

if [ "$XS_OPENVSWITCH" == "yes" ] && [ "$XS_IFUPDOWN2" == "no" ] ; then
    ## Install openvswitch for a virtual internal network
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' purge fupdown2
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install openvswitch-switch
else
    ## Install ifupdown2 for a virtual internal network allows rebootless networking changes (not compatible with openvswitch-switch)
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' purge openvswitch-switch
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install fupdown2
fi

if [ "$XS_ZFSAUTOSNAPSHOT" == "yes" ] ; then
    ## Install zfs-auto-snapshot
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install zfs-auto-snapshot
    # make 5min snapshots , keep 12 5min snapshots
    if [ -f "/etc/cron.d/zfs-auto-snapshot" ] ; then
      sed -i 's|--keep=[0-9]*|--keep=12|g' /etc/cron.d/zfs-auto-snapshot
      sed -i 's|*/[0-9]*|*/5|g' /etc/cron.d/zfs-auto-snapshot
    fi
    # keep 24 hourly snapshots
    if [ -f "/etc/cron.hourly/zfs-auto-snapshot" ] ; then
      sed -i 's|--keep=[0-9]*|--keep=24|g' /etc/cron.hourly/zfs-auto-snapshot
    fi
    # keep 7 daily snapshots
    if [ -f "/etc/cron.daily/zfs-auto-snapshot" ] ; then
      sed -i 's|--keep=[0-9]*|--keep=7|g' /etc/cron.daily/zfs-auto-snapshot
    fi
    # keep 4 weekly snapshots
    if [ -f "/etc/cron.weekly/zfs-auto-snapshot" ] ; then
      sed -i 's|--keep=[0-9]*|--keep=4|g' /etc/cron.weekly/zfs-auto-snapshot
    fi
    # keep 3 monthly snapshots
    if [ -f "/etc/cron.monthly/zfs-auto-snapshot" ] ; then
      sed -i 's|--keep=[0-9]*|--keep=3|g' /etc/cron.monthly/zfs-auto-snapshot
    fi
fi

if [ "$XS_KSMTUNED" == "yes" ] ; then
    ## Ensure ksmtuned (ksm-control-daemon) is enabled
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install ksm-control-daemon
    if [[ RAM_SIZE_GB -le 16 ]] ; then
        # start at 50% full
        KSM_THRES_COEF=50
        KSM_SLEEP_MSEC=80
    elif [[ RAM_SIZE_GB -le 32 ]] ; then
        # start at 60% full
        KSM_THRES_COEF=40
        KSM_SLEEP_MSEC=60
    elif [[ RAM_SIZE_GB -le 64 ]] ; then
        # start at 70% full
        KSM_THRES_COEF=30
        KSM_SLEEP_MSEC=40
    elif [[ RAM_SIZE_GB -le 128 ]] ; then
        # start at 80% full
        KSM_THRES_COEF=20
        KSM_SLEEP_MSEC=20
    else
        # start at 90% full
        KSM_THRES_COEF=10
        KSM_SLEEP_MSEC=10
    fi
    sed -i -e "s/\# KSM_THRES_COEF=.*/KSM_THRES_COEF=${KSM_THRES_COEF}/g" /tmp/ksmtuned.conf
    sed -i -e "s/\# KSM_SLEEP_MSEC=.*/KSM_SLEEP_MSEC=${KSM_SLEEP_MSEC}/g" /tmp/ksmtuned.conf
    systemctl enable ksmtuned
fi

if [ "$XS_CEPH" == "yes" ] ; then
    ## Install ceph support
    echo "Y" | pveceph install
fi

if [ "$XS_AMDFIXES" == "yes" ] ; then
    ## Detect AMD EPYC CPU
    if [ "$(grep -i -m 1 "model name" /proc/cpuinfo | grep -i "EPYC")" != "" ]; then
      echo "AMD EPYC detected"
      #Apply EPYC fix to kernel : Fixes random crashing and instability
      if ! grep "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub | grep -q "idle=nomwait" ; then
        echo "Setting kernel idle=nomwait"
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="idle=nomwait /g' /etc/default/grub
        update-grub
      fi
    fi
    if [ "$(grep -i -m 1 "model name" /proc/cpuinfo | grep -i "EPYC")" != "" ] || [ "$(grep -i -m 1 "model name" /proc/cpuinfo | grep -i "Ryzen")" != "" ]; then
      ## Add msrs ignore to fix Windows guest on EPIC/Ryzen host
      echo "options kvm ignore_msrs=Y" >> /etc/modprobe.d/kvm.conf
      echo "options kvm report_ignored_msrs=N" >> /etc/modprobe.d/kvm.conf
    fi
fi

if [ "$XS_KERNELHEADERS" == "yes" ] ; then
    ## Install kernel source headers
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install pve-headers-$(uname -r) module-assistant
fi

if [ "$XS_KEXEC" == "yes" ] ; then
    ## Install kexec, allows for quick reboots into the latest updated kernel set as primary in the boot-loader.
    # use command 'reboot-quick'
    echo "kexec-tools kexec-tools/load_kexec boolean false" | debconf-set-selections
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install kexec-tools
    cat <<'EOF' > /etc/systemd/system/kexec-pve.service
[Unit]
Description=Loading new kernel into memory
Documentation=man:kexec(8)
DefaultDependencies=no
Before=reboot.target
RequiresMountsFor=/boot
#Before=shutdown.target umount.target final.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/kexec -d -l /boot/pve/vmlinuz --initrd=/boot/pve/initrd.img --reuse-cmdline

[Install]
WantedBy=default.target
EOF
    systemctl enable kexec-pve.service
    echo "alias reboot-quick='systemctl kexec'" >> /root/.bash_profile
fi

if [ "$XS_DISABLERPC" == "yes" ] ; then
    ## Disable portmapper / rpcbind (security)
    systemctl disable rpcbind
    systemctl stop rpcbind
fi

if [ "$XS_TIMEZONE" == "" ] ; then
    ## Set Timezone by IP
    timezone="$(curl https://ipapi.co/$(dig +short myip.opendns.com @resolver1.opendns.com)/timezone)"
    echo "Got $timezone from $(dig +short myip.opendns.com @resolver1.opendns.com)"
    timedatectl set-timezone $timezone
else
    ## Set Timezone to UTC and enable NTP
    timedatectl set-timezone UTC
fi

if [ "$XS_TIMESYNC" == "yes" ] ; then
    cat <<EOF > /etc/systemd/timesyncd.conf
[Time]
NTP=0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org
FallbackNTP=0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=2048
EOF
    service systemd-timesyncd start
    timedatectl set-ntp true
fi

if [ "$XS_PIGZ" == "yes" ] ; then
    ## Set pigz to replace gzip, 2x faster gzip compression
    sed -i "s/#pigz:.*/pigz: 1/" /etc/vzdump.conf
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install pigz
    cat  <<EOF > /bin/pigzwrapper
#!/bin/sh
PATH=/bin:\$PATH
GZIP="-1"
exec /usr/bin/pigz "\$@"
EOF
    mv -f /bin/gzip /bin/gzip.original
    cp -f /bin/pigzwrapper /bin/gzip
    chmod +x /bin/pigzwrapper
    chmod +x /bin/gzip
fi

if [ "$XS_OVHRTM" == "yes" ] ; then
    ## Detect if this is an OVH server by getting the global IP and checking the ASN
    if [ "$(whois -h v4.whois.cymru.com " -t $(curl ipinfo.io/ip 2> /dev/null)" | tail -n 1 | cut -d'|' -f3 | grep -i "ovh")" != "" ] ; then
      echo "Deteted OVH Server, installing OVH RTM (real time monitoring)"
      # http://help.ovh.co.uk/RealTimeMonitoring
      # https://docs.ovh.com/gb/en/dedicated/install-rtm/
      wget -qO - https://last-public-ovh-infra-yak.snap.mirrors.ovh.net/yak/archives/apply.sh | OVH_PUPPET_MANIFEST=distribyak/catalog/master/puppet/manifests/common/rtmv2.pp bash
    fi
fi

if [ "$XS_FAIL2BAN" == "yes" ] ; then
    #todo: add support for ssh
    ## Protect the web interface with fail2ban
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install fail2ban
    # shellcheck disable=1117
cat <<EOF > /etc/fail2ban/filter.d/proxmox.conf
[Definition]
failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.* msg=.*
ignoreregex =
EOF
cat <<EOF > /etc/fail2ban/jail.d/proxmox.conf
[proxmox]
enabled = true
port = https,http,8006
filter = proxmox
logpath = /var/log/daemon.log
maxretry = 3
# 1 hour
bantime = 3600
findtime = 600
EOF
cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
banaction = iptables-ipset-proto4
EOF
    systemctl enable fail2ban
    ##testing
    #fail2ban-regex /var/log/daemon.log /etc/fail2ban/filter.d/proxmox.conf
fi

if [ "$XS_NOSUBBANNER" == "yes" ] ; then
    ## Remove subscription banner
    if [ -f "/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js" ] ; then
      sed -i "s/data.status !== 'Active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
      sed -i "s/checked_command: function(orig_cmd) {/checked_command: function() {} || function(orig_cmd) {/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
      # create a daily cron to make sure the banner does not re-appear
  cat <<'EOF' > /etc/cron.daily/proxmox-nosub
#!/bin/sh
# eXtremeSHOK.com Remove subscription banner
sed -i "s/data.status !== 'Active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
sed -i "s/checked_command: function(orig_cmd) {/checked_command: function() {} || function(orig_cmd) {/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
EOF
      chmod 755 /etc/cron.daily/proxmox-nosub
    fi
    # Remove nag @tinof
    echo "DPkg::Post-Invoke { \"dpkg -V proxmox-widget-toolkit | grep -q '/proxmoxlib\.js$'; if [ \$? -eq 1 ]; then { echo 'Removing subscription nag from UI...'; sed -i '/data.status/{s/\!//;s/Active/NoMoreNagging/}' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js; }; fi\"; };" > /etc/apt/apt.conf.d/no-nag-script && apt --reinstall install proxmox-widget-toolkit
fi

if [ "$XS_MOTD" == "yes" ] ; then
## Pretty MOTD BANNER
  if ! grep -q https "/etc/motd" ; then
    cat << 'EOF' > /etc/motd.new
	   This system is optimised by:            https://eXtremeSHOK.com
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
fi

if [ "$XS_LIMITS" == "yes" ] ; then
    ## Increase max user watches
    # BUG FIX : No space left on device
    echo 1048576 > /proc/sys/fs/inotify/max_user_watches
    echo "fs.inotify.max_user_watches=1048576" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf
    ## Increase max FD limit / ulimit
cat <<EOF >> /etc/security/limits.conf
# eXtremeSHOK.com Increase max FD limit / ulimit
* soft     nproc          256000
* hard     nproc          256000
* soft     nofile         256000
* hard     nofile         256000
root soft     nproc          256000
root hard     nproc          256000
root soft     nofile         256000
root hard     nofile         256000
EOF
    ## Increase kernel max Key limit
cat <<EOF > /etc/sysctl.d/60-maxkeys.conf
# eXtremeSHOK.com
# Increase kernel max Key limit
kernel.keys.root_maxkeys=1000000
kernel.keys.maxkeys=1000000
EOF
    ## Set systemd ulimits
    echo "DefaultLimitNOFILE=256000" >> /etc/systemd/system.conf
    echo "DefaultLimitNOFILE=256000" >> /etc/systemd/user.conf
    echo 'session required pam_limits.so' | tee -a /etc/pam.d/common-session-noninteractive
    echo 'session required pam_limits.so' | tee -a /etc/pam.d/common-session
    echo 'session required pam_limits.so' | tee -a /etc/pam.d/runuser-l
    ## Set ulimit for the shell user
    echo "ulimit -n 256000" >> /root/.bashrc
    echo "ulimit -n 256000" >> /root/.profile
fi

if [ "$XS_VZDUMP" == "yes" ] ; then
    ## Increase vzdump backup speed, ix ionice
    sed -i "s/#bwlimit:.*/bwlimit: 0/" /etc/vzdump.conf
    sed -i "s/#ionice:.*/ionice: 5/" /etc/vzdump.conf
    fi

if [ "$XS_MEMORYFIXES" == "yes" ] ; then
    ## Bugfix: pve 5.1 high swap usage with low memory usage
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    sysctl -p
    ## Bugfix: reserve 512MB memory for system
    echo "vm.min_free_kbytes = 524288" >> /etc/sysctl.conf
    sysctl -p
fi

if [ "$XS_TCPBBR" == "yes" ] ; then
## Enable TCP BBR congestion control
cat <<EOF > /etc/sysctl.d/10-kernel-bbr.conf
# eXtremeSHOK.com
# TCP BBR congestion control
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
fi

if [ "$XS_BASHRC" == "yes" ] ; then
    ## Customise bashrc (thanks broeckca)
cat <<EOF >> /root/.bashrc
export HISTTIMEFORMAT="%d/%m/%y %T "
export PS1='\u@\h:\W \$ '
alias l='ls -CF'
alias la='ls -A'
alias ll='ls -alF'
alias ls='ls --color=auto'
source /etc/profile.d/bash_completion.sh
export PS1="\[\e[31m\][\[\e[m\]\[\e[38;5;172m\]\u\[\e[m\]@\[\e[38;5;153m\]\h\[\e[m\] \[\e[38;5;214m\]\W\[\e[m\]\[\e[31m\]]\[\e[m\]\\$ "
EOF
    source /root/.bashrc
fi

if [ "$XS_ZFSARC" == "yes" ] ; then
    ## Optimise ZFS arc size
    if [ "$(command -v zfs)" != "" ] ; then
      if [[ RAM_SIZE_GB -le 16 ]] ; then
        MY_ZFS_ARC_MIN=536870912
        MY_ZFS_ARC_MAX=536870912
    elif [[ RAM_SIZE_GB -le 32 ]] ; then
        # 1GB/1GB
        MY_ZFS_ARC_MIN=1073741824
        MY_ZFS_ARC_MAX=1073741824
      else
        MY_ZFS_ARC_MIN=$((RAM_SIZE_GB * 1073741824 / 16))
        MY_ZFS_ARC_MAX=$((RAM_SIZE_GB * 1073741824 / 8))
      fi
      # Enforce the minimum, incase of a faulty vmstat
      if [[ MY_ZFS_ARC_MIN -lt 536870912 ]] ; then
        MY_ZFS_ARC_MIN=536870912
      fi
      if [[ MY_ZFS_ARC_MAX -lt 536870912 ]] ; then
        MY_ZFS_ARC_MAX=536870912
      fi
      cat <<EOF > /etc/modprobe.d/zfs.conf
# eXtremeSHOK.com ZFS tuning

# Use 1/16 RAM for MAX cache, 1/8 RAM for MIN cache, or 1GB
options zfs zfs_arc_min=$MY_ZFS_ARC_MIN
options zfs zfs_arc_max=$MY_ZFS_ARC_MAX

# use the prefetch method
options zfs l2arc_noprefetch=0

# max write speed to l2arc
# tradeoff between write/read and durability of ssd (?)
# default : 8 * 1024 * 1024
# setting here : 500 * 1024 * 1024
options zfs l2arc_write_max=524288000
EOF
    fi
fi

# propagate the setting into the kernel
update-initramfs -u -k all

# cleanup
## Remove no longer required packages and purge old cached updates
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' autoremove
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' autoclean

## Script Finish
echo -e '\033[1;33m Finished....please restart the system \033[0m'
