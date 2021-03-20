#!/usr/bin/env bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################
#
# Script updates can be found at: https://github.com/extremeshok/xshok-proxmox
#
# tinc vpn - installation script for Proxmox, Debian, CentOS and RedHat based servers
#
# License: BSD (Berkeley Software Distribution)
#
# Usage:
# curl -O https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/networking/tincvpn.sh && chmod +x tincvpn.sh
# ./tincvpn.sh -h
#
# Example for 3 node Cluster
#
# cat /etc/hosts
# global ips for tinc servers
# 11.11.11.11 host1
# 22.22.22.22 host2
# 33.33.33.33 host3
#
# First Host (hostname: host1)
# ./tincvpn.sh -i 1 -c host2
# Second Host (hostname: host2)
# ./tincvpn.sh -i 2 -c host3
# Third Host (hostname: host3)
# ./tincvpn.sh -3 -c host1
#
#
################################################################################
#
#    THERE ARE  USER CONFIGURABLE OPTIONS IN THIS SCRIPT
#   ALL CONFIGURATION OPTIONS ARE LOCATED BELOW THIS MESSAGE
#
##############################################################
vpn_ip_last=1
vpn_connect_to=""
vpn_port=655
my_default_v4ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '192.168.' | grep -v '10.0.' | grep -v '10.10.' | grep -v '127.0.0.' | tail -n 1)
#my_default_v4ip=""
reset="no"


while getopts i:p:c:a:rh:uh option
do
  case "${option}"
      in
    i) vpn_ip_last=${OPTARG} ;;
    p) vpn_port=${OPTARG} ;;
    c) vpn_connect_to=${OPTARG} ;;
    a) my_default_v4ip=${OPTARG} ;;
    r) reset="yes" ;;
    u) uninstall="yes" ;;
    *) echo "-i <last_ip_part 10.10.1.?> -p <vpn port if not 655> -c <vpn host to connect to, eg. prx_b> -a <public ip address, or will auto-detect> -r (reset) -u (uninstall)" ; exit ;;
  esac
done

if [ "$reset" == "yes" ] || [ "$uninstall" == "yes" ] ; then
  echo "Stopping Tinc"
  systemctl stop tinc-xsvpn.service
  pkill -9 tincd

  echo "Removing configs"
  rm -rf /etc/tinc/my_default_v4ip
  rm -rf /etc/tinc/xsvpn
  mv -f /etc/tinc/nets.boot.orig /etc/tinc/nets.boot
  rm -f /etc/network/interfaces.d/tinc-vpn.cfg
  rm -f /etc/systemd/system/tinc-xsvpn.service

  if [ "$uninstall" == "yes" ] ; then
    systemctl disable tinc.service
    echo "Tinc uninstalled"
    exit 0
  fi
fi

if [ "$(command -v tinc)" == "" ] ; then
  if [ "$(command -v apt-get)" != "" ] ; then
    /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install tinc
  else
    echo "ERROR: tinc not installed"
    exit 1
  fi
fi


if [ "$my_default_v4ip" == "" ] ; then
  #detect default ipv4 and default interface
  default_interface="$(ip route | awk '/default/ { print $5 }' | grep -v "vmbr")"
  if [ "$default_interface" == "" ]; then
    #filter the interfaces to get the default interface and which is not down and not a virtual bridge
    default_interface="$(ip link | sed -e '/state DOWN / { N; d; }' | sed -e '/veth[0-9].*:/ { N; d; }' | sed -e '/vmbr[0-9].*:/ { N; d; }' | sed -e '/tap[0-9].*:/ { N; d; }' | sed -e '/lo:/ { N; d; }' | head -n 1 | cut -d':' -f 2 | xargs)"
  fi
  if [ "$default_interface" == "" ]; then
    echo "ERROR: Could not detect default interface"
    exit 1
  fi
  default_v4="$(ip -4 addr show dev "$default_interface" | awk '/inet/ { print $2 }' )"
  my_default_v4ip=${default_v4%/*}
  if [ "$my_default_v4ip" == "" ] ; then
    echo "ERROR: Could not detect default IPv4 address"
    echo "IP: ${my_default_v4ip}"
    exit 1
  fi
fi

# Assign and Fix varibles

my_name=$(uname -n)
my_name=${my_name//-/_}

if [ "$vpn_connect_to" != "${vpn_connect_to//-/_}" ]; then
  echo "ERROR: - character is not allowed in hostname for vpn_connect_to"
  exit 1
fi

echo "Options:"
echo "VPN IP: 10.10.1.${vpn_ip_last}"
echo "VPN PORT: ${vpn_port}"
echo "VPN Connect to host: ${vpn_connect_to}"
echo "Public Address: ${my_default_v4ip}"

# Detect and Install
if [ "$(command -v tincd)" == "" ] ; then
  echo "Tinc not found, installing...."
  if [ "$(command -v yum)" != "" ] ; then
    yum install -y tinc
  elif [ "$(command -v apt-get)" != "" ] ; then
    apt-get install -y tinc
  fi
fi

#Create the DIR and key files
mkdir -p /etc/tinc/xsvpn/hosts
touch /etc/tinc/xsvpn/rsa_key.pub
touch /etc/tinc/xsvpn/rsa_key.priv

if [ "$(grep "BEGIN RSA PUBLIC KEY" /etc/tinc/xsvpn/rssa_key.pub 2> /dev/null)" != "" ] ; then
  if [ "$(grep "BEGIN RSA PRIVATE KEY" /etc/tinc/xsvpn/rssa_key.priv 2> /dev/null)" != "" ] ; then
    echo "Using Previous RSA Keys"
  else
    echo "Generating New RSA Keys"
    tincd -K4096 -c /etc/tinc/xsvpn </dev/null 2>/dev/null
  fi
else
  echo "Generating New 4096 bit RSA Keys"
  tincd -K4096 -c /etc/tinc/xsvpn </dev/null 2>/dev/null
fi

#Generate Configs
cat <<EOF > /etc/tinc/xsvpn/tinc.conf
Name = $my_name
AddressFamily = ipv4
Interface = Tun0
Mode = switch
# Switch: Unicast, multicast and broadcast packaets
ConnectTo = $vpn_connect_to
EOF

cat <<EOF > "/etc/tinc/xsvpn/hosts/$my_name"
Address = ${my_default_v4ip}
Subnet =  10.10.1.${vpn_ip_last}
Port = ${vpn_port}
Compression = 10 #LZO
EOF
cat /etc/tinc/xsvpn/rsa_key.pub >> "/etc/tinc/xsvpn/hosts/${my_name}"

cat <<EOF > /etc/tinc/xsvpn/tinc-up
#!/usr/bin/env bash
ip link set \$INTERFACE up
ip addr add  10.10.1.${vpn_ip_last}/24 dev \$INTERFACE
ip route add 10.10.1.0/24 dev \$INTERFACE

# Set a multicast route over interface
route add -net 224.0.0.0 netmask 240.0.0.0 dev \$INTERFACE

# To allow IP forwarding:
#echo 1 > /proc/sys/net/ipv4/ip_forward

# To limit the chance of Corosync Totem re-transmission issues:
#echo 0 > /sys/devices/virtual/net/\$INTERFACE/bridge/multicast_snooping
EOF

chmod 755 /etc/tinc/xsvpn/tinc-up

cat <<EOF > /etc/tinc/xsvpn/tinc-down
#!/usr/bin/env bash
ip route del 10.10.1.0/24 dev \$INTERFACE
ip addr del 10.10.1.${vpn_ip_last}/24 dev \$INTERFACE
ip link set \$INTERFACE down

# Set a multicast route over interface
route del -net 224.0.0.0 netmask 240.0.0.0 dev \$INTERFACE

#echo 0 > /proc/sys/net/ipv4/ip_forward
EOF

chmod 755 /etc/tinc/xsvpn/tinc-down

# Set which VPN to start
#cp -f /etc/tinc/nets.boot /etc/tinc/nets.boot.orig
#echo "vpn" >> /etc/tinc/nets.boot

cat <<EOF > /etc/systemd/system/tinc-xsvpn.service
[Unit]
Description=eXtremeSHOK.com Tinc VPN
After=network.target

[Service]
Type=simple
WorkingDirectory=/etc/tinc/xsvpn
ExecStart=$(command -v tincd) -n xsvpn -D -d2
ExecReload=$(command -v tincd) -n xsvpn -kHUP
TimeoutStopSec=5
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

# Enable at Boot
systemctl enable tinc-xsvpn.service

# Add a Tun0 entry to /etc/network/interfaces to allow for ceph suport over the VPN
if [ "$(grep "source /etc/network/interfaces.d/*" /etc/network/interfaces 2> /dev/null)" == "" ] ; then
  echo "source /etc/network/interfaces.d/*" >> /etc/network/interfaces
  mkdir -p  /etc/network/interfaces.d/
fi
if [ ! -f /etc/network/interfaces.d/tinc-vpn.cfg ]; then
  cat <<EOF > /etc/network/interfaces.d/tinc-vpn.cfg
# tinc vpn
iface Tun0 inet static
  address 10.10.1.${vpn_ip_last}
  netmask 255.255.255.0
  broadcast 0.0.0.0
EOF
fi

#Display the Host config for simple cpy-paste to another node
echo ""
echo "Run the following on the other VPN nodes:"
echo "The following information is stored in /etc/tinc/xsvpn/this_host.info"

echo 'cat <<EOF >> /etc/tinc/xsvpn/hosts/'"${my_name}" > /etc/tinc/xsvpn/this_host.info
cat "/etc/tinc/xsvpn/hosts/${my_name}" >> /etc/tinc/xsvpn/this_host.info
echo "EOF" >> /etc/tinc/xsvpn/this_host.info

echo ""
echo 'cat <<EOF >> /etc/tinc/xsvpn/hosts/'"${my_name}"
cat "/etc/tinc/xsvpn/hosts/${my_name}"
echo "EOF"
echo ""
