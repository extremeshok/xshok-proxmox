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
# Docker : not advisable to run docker on the Hypervisor(proxmox) directly.
# Correct way is to create a VM which will be used exclusively for docker.
# ie. fresh ubuntu lts server with https://github.com/extremeshok/xshok-docker
################################################################################
#
#    THERE ARE NO USER CONFIGURABLE OPTIONS IN THIS SCRIPT
#
################################################################################

#####  T O   S E T   Y O U R   O P T I O N S  ######
# User Defined Options for (install-post.sh) post-installation script for Proxmox
# are set in the xs-install-post.env, see the sample : xs-install-post.env.sample
#####  D O   N O T   E D I T   B E L O W  ######

#### VARIABLES / options
XS_AMDFIXES="yes"
XS_APTUPGRADE="yes"
XS_BASHRC="yes"
XS_CEPH="yes"
XS_DISABLERPC="yes"
XS_ENTROPY="yes"
XS_FAIL2BAN="yes"
XS_GUESTAGENT="yes"
XS_IFUPDOWN2="yes"
XS_JOURNALD="yes"
XS_KERNELHEADERS="yes"
XS_KEXEC="yes"
XS_KSMTUNED="yes"
XS_LANG="en_US.UTF-8"
XS_LIMITS="yes"
XS_LOGROTATE="yes"
XS_LYNIS="yes"
XS_MAXFS="yes"
XS_MEMORYFIXES="yes"
XS_MOTD="yes"
XS_NET="yes"
XS_NOAPTLANG="yes"
XS_NOENTREPO="yes"
XS_NOSUBBANNER="yes"
XS_OPENVSWITCH="no"
XS_OVHRTM="yes"
XS_PIGZ="yes"
XS_SWAPPINESS="yes"
XS_TCPBBR="yes"
XS_TCPFASTOPEN="yes"
XS_TCPFASTOPEN="yes"
XS_TESTREPO="no"
XS_TIMESYNC="yes"
XS_TIMEZONE="" #empty = set automatically by ip
XS_UTILS="yes"
XS_VZDUMP="yes"
XS_ZFSARC="yes"
XS_ZFSAUTOSNAPSHOT="yes"

#################  D O   N O T   E D I T  ######################################

# VARIABLES are overrideen with xs-install-post.env
if [ -f "xs-install-post.env" ] ; then
    echo "Loading variables from xs-install-post.env ..."
    source xs-install-post.env;
fi

# Set the local
export LANG="$XS_LANG"
export LC_ALL="C"

# enforce proxmox
if [ ! -f "/etc/pve/.version" ] ; then
  echo "ERROR: This script only supports Proxmox"
  exit 1
fi

if [ -f "/etc/extremeshok" ] ; then
  echo "ERROR: Script can only be run once"
  exit 1
fi

# SET VARIBLES

OS_CODENAME="$(grep "VERSION_CODENAME=" /etc/os-release | cut -d"=" -f 2 | xargs )"
RAM_SIZE_GB=$(( $(vmstat -s | grep -i "total memory" | xargs | cut -d" " -f 1) / 1024 / 1000))

if [ "$XS_LANG" == "en_US.UTF-8" ] && [ "$XS_NOAPTLANG" == "yes" ] ; then
    #save bandwidth and skip downloading additional languages
    echo -e "Acquire::Languages \"none\";\\n" > /etc/apt/apt.conf.d/99-xs-disable-translations
fi

## Force APT to use IPv4
echo -e "Acquire::ForceIPv4 \"true\";\\n" > /etc/apt/apt.conf.d/99-xs-force-ipv4

if [ "$XS_NOENTREPO" == "yes" ] ; then
    ## disable enterprise proxmox repo
    if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
      sed -i "s/^deb/#deb/g" /etc/apt/sources.list.d/pve-enterprise.list
    fi
    ## enable public proxmox repo
    if [ ! -f /etc/apt/sources.list.d/proxmox.list ] && [ ! -f /etc/apt/sources.list.d/pve-public-repo.list ] && [ ! -f /etc/apt/sources.list.d/pve-install-repo.list ] ; then
      echo -e "deb http://download.proxmox.com/debian/pve ${OS_CODENAME} pve-no-subscription\\n" > /etc/apt/sources.list.d/pve-public-repo.list
    fi
    if [ "$XS_TESTREPO" == "yes" ] ; then
        ## enable testing proxmox repo
        echo -e "deb http://download.proxmox.com/debian/pve ${OS_CODENAME} pvetest\\n" > /etc/apt/sources.list.d/pve-testing-repo.list
    fi
fi

# rebuild and add non-free to /etc/apt/sources.list
cat <<EOF > /etc/apt/sources.list
deb https://ftp.debian.org/debian ${OS_CODENAME} main contrib
deb https://ftp.debian.org/debian ${OS_CODENAME}-updates main contrib
# non-free
deb https://httpredir.debian.org/debian/ ${OS_CODENAME} main contrib non-free
# security updates
deb https://security.debian.org/debian-security ${OS_CODENAME}/updates main contrib
EOF

## Refresh the package lists
apt-get update > /dev/null 2>&1

## Remove conflicting utilities
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' purge ntp openntpd chrony

## Fixes for common apt repo errors
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install apt-transport-https debian-archive-keyring ca-certificates

if [ "$XS_APTUPGRADE" == "yes" ] ; then
    ## Update proxmox and install various system utils
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' dist-upgrade
    pveam update
fi

## Install packages which are sometimes missing on some Proxmox installs.
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install zfsutils-linux

if [ "$XS_UTILS" == "yes" ] ; then
## Install common system utilities
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install \
    axel \
    build-essential \
    curl \
    dialog \
    dnsutils \
    dos2unix \
    git \
    gnupg-agent \
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
fi

if [ "$XS_CEPH" == "yes" ] ; then
    ## Add the latest ceph provided by proxmox
    echo "deb https://download.proxmox.com/debian/ceph-octopus ${OS_CODENAME} main" > /etc/apt/sources.list.d/ceph.list
    ## Refresh the package lists
    apt-get update > /dev/null 2>&1
    ## Install ceph support
    echo "Y" | pveceph install
fi

if [ "$XS_LYNIS" == "yes" ] ; then
    # Lynis security scan tool by Cisofy
    wget -O - https://packages.cisofy.com/keys/cisofy-software-public.key | apt-key add -
    ## Add the latest lynis
    echo "deb https://packages.cisofy.com/community/lynis/deb/ stable main" > /etc/apt/sources.list.d/cisofy-lynis.list
    ## Refresh the package lists
    apt-get update > /dev/null 2>&1
    ## Install ceph support
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef'  install lynis
fi

if [ "$XS_OPENVSWITCH" == "yes" ] && [ "$XS_IFUPDOWN2" == "no" ] ; then
    ## Install openvswitch for a virtual internal network
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install ifenslave
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' purge ifupdown2
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install openvswitch-switch
else
    ## Install ifupdown2 for a virtual internal network allows rebootless networking changes (not compatible with openvswitch-switch)
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' purge openvswitch-switch
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install ifupdown2
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' purge ifenslave
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
    sed -i -e "s/\# KSM_THRES_COEF=.*/KSM_THRES_COEF=${KSM_THRES_COEF}/g" /etc/ksmtuned.conf
    sed -i -e "s/\# KSM_SLEEP_MSEC=.*/KSM_SLEEP_MSEC=${KSM_SLEEP_MSEC}/g" /etc/ksmtuned.conf
    systemctl enable ksmtuned
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
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install pve-headers module-assistant
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
    this_ip="$(dig +short myip.opendns.com @resolver1.opendns.com)"
    timezone="$(curl https://ipapi.co/${this_ip}/timezone)"
    if [ "$timezone" != "" ] ; then
        echo "Found $timezone for ${this_ip}"
        timedatectl set-timezone $timezone
    else
        echo "WARNING: Timezone not found for ${this_ip}, set to UTC"
        timedatectl set-timezone UTC
    fi
else
    ## Set Timezone to XS_TIMEZONE
    timedatectl set-timezone $XS_TIMEZONE
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

if [ "$XS_GUESTAGENT" == "yes" ] ; then
    ## Detect if virtual machine and install guest agent
    if [ "$(dmidecode -s system-manufacturer | xargs)" == "QEMU" ] || [ "$(systemd-detect-virt | xargs)" == "kvm" ] ; then
      echo "QEMU Detected, installing guest agent"
      /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install qemu-guest-agent
    elif [ "$(systemd-detect-virt | xargs)" == "vmware" ] ; then
      echo "VMware Detected, installing vm-tools"
      /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install open-vm-tools
    elif [ "$(systemd-detect-virt | xargs)" == "oracle" ] ; then
      echo "Virtualbox Detected, installing guest-utils"
      /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install virtualbox-guest-utils
    fi
fi

if [ "$XS_PIGZ" == "yes" ] ; then
    ## Set pigz to replace gzip, 2x faster gzip compression
    sed -i "s/#pigz:.*/pigz: 1/" /etc/vzdump.conf
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install pigz
    cat  <<EOF > /bin/pigzwrapper
#!/bin/sh
# eXtremeSHOK.com
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
      # create a daily cron to make sure the banner does not re-appear
  cat <<'EOF' > /etc/cron.daily/xs-pve-nosub
#!/bin/sh
# eXtremeSHOK.com Remove subscription banner
sed -i "s/data.status !== 'Active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
sed -i "s/checked_command: function(orig_cmd) {/checked_command: function() {} || function(orig_cmd) {/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
EOF
      chmod 755 /etc/cron.daily/xs-pve-nosub
      bash /etc/cron.daily/xs-pve-nosub
    fi
    # Remove nag @tinof
    echo "DPkg::Post-Invoke { \"dpkg -V proxmox-widget-toolkit | grep -q '/proxmoxlib\.js$'; if [ \$? -eq 1 ]; then { echo 'Removing subscription nag from UI...'; sed -i '/data.status/{s/\!//;s/Active/NoMoreNagging/}' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js; }; fi\"; };" > /etc/apt/apt.conf.d/xs-pve-no-nag && apt --reinstall install proxmox-widget-toolkit
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
    cat <<EOF > /etc/sysctl.d/99-xs-maxwatches.conf
# eXtremeSHOK.com
# Increase max user watches
fs.inotify.max_user_watches=1048576
fs.inotify.max_user_instances=1048576
fs.inotify.max_queued_events=1048576
EOF
    ## Increase max FD limit / ulimit
    cat <<EOF >> /etc/security/limits.d/99-xs-limits.conf
# eXtremeSHOK.com
# Increase max FD limit / ulimit
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
    cat <<EOF > /etc/sysctl.d/99-xs-maxkeys.conf
# eXtremeSHOK.com
# Increase kernel max Key limit
kernel.keys.root_maxkeys=1000000
kernel.keys.maxkeys=1000000
EOF
    ## Set systemd ulimits
    echo "DefaultLimitNOFILE=256000" >> /etc/systemd/system.conf
    echo "DefaultLimitNOFILE=256000" >> /etc/systemd/user.conf

    echo 'session required pam_limits.so' >> /etc/pam.d/common-session
    echo 'session required pam_limits.so' >> /etc/pam.d/runuser-l

    ## Set ulimit for the shell user
    echo "ulimit -n 256000" >> /root/.profile
fi

if [ "$XS_LOGROTATE" == "yes" ] ; then
    ## Optimise logrotate
    cat <<EOF > /etc/logrotate.conf
# eXtremeSHOK.com
daily
su root adm
rotate 7
create
compress
size=10M
delaycompress
copytruncate

include /etc/logrotate.d
EOF
    systemctl restart logrotate
fi

if [ "$XS_JOURNALD" == "yes" ] ; then
    ## Limit the size and optimise journald
    cat <<EOF > /etc/systemd/journald.conf
# eXtremeSHOK.com
[Journal]
# Store on disk
Storage=persistent
# Don't split Journald logs by user
SplitMode=none
# Disable rate limits
RateLimitInterval=0
RateLimitIntervalSec=0
RateLimitBurst=0
# Disable Journald forwarding to syslog
ForwardToSyslog=no
# Journald forwarding to wall /var/log/kern.log
ForwardToWall=yes
# Disable signing of the logs, save cpu resources.
Seal=no
Compress=yes
# Fix the log size
SystemMaxUse=64M
RuntimeMaxUse=60M
# Optimise the logging and speed up tasks
MaxLevelStore=warning
MaxLevelSyslog=warning
MaxLevelKMsg=warning
MaxLevelConsole=notice
MaxLevelWall=crit
EOF
    systemctl restart systemd-journald.service
    journalctl --vacuum-size=64M --vacuum-time=1d;
    journalctl --rotate
fi

if [ "$XS_ENTROPY" == "yes" ] ; then
## Ensure Entropy Pools are Populated, prevents slowdowns whilst waiting for entropy
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install haveged
    ## Net optimising
    cat <<EOF > /etc/default/haveged
# eXtremeSHOK.com
#   -w sets low entropy watermark (in bits)
DAEMON_ARGS="-w 1024"
EOF
    systemctl daemon-reload
    systemctl enable haveged
fi

if [ "$XS_VZDUMP" == "yes" ] ; then
    ## Increase vzdump backup speed, ix ionice
    sed -i "s/#bwlimit:.*/bwlimit: 0/" /etc/vzdump.conf
    sed -i "s/#ionice:.*/ionice: 5/" /etc/vzdump.conf
fi

if [ "$XS_MEMORYFIXES" == "yes" ] ; then
    ## Memory Optimising
cat <<EOF > /etc/sysctl.d/99-xs-memory.conf
# eXtremeSHOK.com
# Memory Optimising
## Bugfix: reserve 512MB memory for system
vm.min_free_kbytes=524288
vm.nr_hugepages=72
# (Redis/MongoDB)
vm.max_map_count=262144
vm.overcommit_memory = 1
EOF
fi

if [ "$XS_TCPBBR" == "yes" ] ; then
## Enable TCP BBR congestion control
cat <<EOF > /etc/sysctl.d/99-xs-kernel-bbr.conf
# eXtremeSHOK.com
# TCP BBR congestion control
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
fi

if [ "$XS_TCPFASTOPEN" == "yes" ] ; then
## TCP fastopen
cat <<EOF > /etc/sysctl.d/99-xs-tcp-fastopen.conf
# eXtremeSHOK.com
# TCP fastopen
net.ipv4.tcp_fastopen=3
EOF
fi

if [ "$XS_NET" == "yes" ] ; then
## Net optimising
cat <<EOF > /etc/sysctl.d/99-xs-net.conf
# eXtremeSHOK.com
net.core.netdev_max_backlog=8192
net.core.optmem_max=8192
net.core.rmem_max=16777216
net.core.somaxconn=8151
net.core.wmem_max=16777216
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.ip_local_port_range=1024 65535
net.ipv4.tcp_base_mss = 1024
net.ipv4.tcp_challenge_ack_limit = 999999999
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_probes=3
net.ipv4.tcp_keepalive_time=240
net.ipv4.tcp_limit_output_bytes=65536
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rfc1337=1
net.ipv4.tcp_rmem=8192 87380 16777216
net.ipv4.tcp_sack=1
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_syn_retries=3
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_tw_reuse = 0
net.ipv4.tcp_wmem=8192 65536 16777216
net.netfilter.nf_conntrack_generic_timeout = 60
net.netfilter.nf_conntrack_helper=0
net.netfilter.nf_conntrack_max = 524288
net.netfilter.nf_conntrack_tcp_timeout_established = 28800
net.unix.max_dgram_qlen = 4096
EOF
fi

if [ "$XS_SWAPPINESS" == "yes" ] ; then
    ## Bugfix: high swap usage with low memory usage
    cat <<EOF > /etc/sysctl.d/99-xs-swap.conf
# eXtremeSHOK.com
# Bugfix: high swap usage with low memory usage
vm.swappiness=10
EOF
fi

if [ "$XS_MAXFS" == "yes" ] ; then
    ## FS Optimising
    cat <<EOF > /etc/sysctl.d/99-xs-fs.conf
# eXtremeSHOK.com
# MAS FS Optimising
fs.nr_open=12000000
fs.file-max=9000000
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
    echo "source /root/.bashrc" >> /root/.bash_profile
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
      cat <<EOF > /etc/modprobe.d/99-xs-zfsarc.conf
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

echo "# eXtremeSHOK.com" > /etc/extremeshok
date >> /etc/extremeshok

## Script Finish
echo -e '\033[1;33m Finished....please restart the system \033[0m'
