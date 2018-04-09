#!/bin/bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################
#
# Script updates can be found at: https://github.com/extremeshok/xshok-proxmox
#
# License: BSD (Berkeley Software Distribution)
#
################################################################################
#
## CREATES A ROUTED vmbr0 AND NAT vmbr1 NETWORK CONFIGURATION FOR PROXMOX
# Autodetects the correct settings (interface, gatewat, netmask, etc)
# Supports IPv4 and IPv6, Private Network uses 10.10.10.1/24
# ROUTED (vmbr0):
#   All traffic is routed via the main IP address and uses the MAC address of the physical interface.
#   VM's can have multiple IP addresses and they do NOT require a MAC to be set for the IP via service provider
#
# NAT (vmbr1):
#   Allows a VM to have internet connectivity without requiring its own IP address
#
# Tested on OVH and Hetzner based servers
#
# ALSO CREATES A NAT Private Network as vmbr1
#
# NOTE: WILL OVERWRITE /etc/network/interfaces
# A backup will be created as /etc/network/interfaces.timestamp
#
################################################################################
#
#    THERE ARE NO USER CONFIGURABLE OPTIONS IN THIS SCRIPT
#
################################################################################

network_interfaces_file="/etc/network/interfaces"

if ! [ -f "addiprage.sh" ]; then
  curl "https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/addiprange.sh" --output addiprange.sh
fi
if ! grep -q '#!/bin/bash' "addiprange.sh"; then
  echo "ERROR: addiprange.sh invalid"
fi

if ! [ -f "/etc/sysctl.d/99-networking.conf" ]; then
  echo "Creating /etc/sysctl.d/99-networking.conf"
cat > /etc/sysctl.d/99-networking.conf <<EOF
net.ipv4.ip_forward=1
net.ipv4.conf.eth0.send_redirects=0
net.ipv6.conf.all.forwarding=1
EOF
fi

# Auto detect the existing network settings... this is all for ipv4... eeek
default_interface="$(ip route | awk '/default/ { print $5 }' | grep -v "vmbr")"
if [ "$default_interface" == "" ]; then
  #filter the interfaces to get the default interface and which is not down and not a virtual bridge
  default_interface="$(ip link | sed -e '/state DOWN / { N; d; }' | sed -e '/veth[0-9].*:/ { N; d; }' | sed -e '/vmbr[0-9].*:/ { N; d; }' | sed -e '/tap[0-9].*:/ { N; d; }' | sed -e '/lo:/ { N; d; }' | head -n 1 | cut -d':' -f 2 | xargs)"
fi
if [ "$default_interface" == "" ]; then
  echo "ERROR: Could not detect default interface"
  exit 1
fi
default_v4gateway="$(ip route | awk '/default/ { print $3 }')"
default_v4="$(ip -4 addr show dev "$default_interface" | awk '/inet/ { print $2 }' )"
default_v4ip=${default_v4%/*}
default_v4mask=${default_v4#*/}
if [ "$default_v4mask" == "" ] ;then
  default_v4netmask="$(ifconfig vmbr0 | awk '/netmask/ { print $4 }')"
else
  if [ "$default_v4mask" -lt "1" ] || [ "$default_v4mask" -gt "32" ] ; then
    echo "ERROR: Invalid CIDR $default_v4mask"
    exit 1
  fi
  cdr2mask () {
    set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
    if [[ "$1" -gt 1 ]] ; then shift "$1" ; else shift ; fi ;  echo "${1-0}.${2-0}.${3-0}.${4-0}"
  }
  default_v4netmask="$(cdr2mask "$default_v4mask")"
fi

if [ "$default_v4ip" == "" ] || [ "$default_v4netmask" == "" ] || [ "$default_v4gateway" == "" ]; then
  echo "ERROR: Could not detect all IPv4 varibles"
  echo "IP: ${default_v4ip} Netmask: ${default_v4netmask} Gateway: ${default_v4gateway}"
  exit 1
fi

cp "$network_interfaces_file" "${network_interfaces_file}.$(date +"%Y-%m-%d_%H-%M-%S")"

cat > "$network_interfaces_file" <<EOF
###### eXtremeSHOK.com

# Load extra files, ie for extra gateways
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback
iface lo inet6 loopback

### IPv4 ###
# Main IPv4 from Host
auto ${default_interface}
iface ${default_interface} inet static
  address ${default_v4ip}
  netmask ${default_v4netmask}
  gateway ${default_v4gateway}
  pointopoint ${default_v4gateway}

# VM-Bridge used by Proxmox Guests
auto vmbr0
iface vmbr0 inet static
  address ${default_v4ip}
  netmask ${default_v4netmask}
  bridge_ports none
  bridge_stp off
  bridge_fd 0
  bridge_maxwait 0

EOF

default_v6="$(ip -6 addr show dev "$default_interface" | awk '/global/ { print $2}')"
default_v6ip=${default_v6%/*}
default_v6mask=${default_v6#*/}
default_v6gateway="$(ip -6 route | awk '/default/ { print $3 }')"

if [ "$default_v6ip" != "" ] && [ "$default_v6mask" != "" ] && [ "$default_v6gateway" != "" ]; then
cat >> "$network_interfaces_file"  << EOF
### IPv6 ###
iface ${default_interface} inet6 static
  address ${default_v6ip}
  netmask ${default_v6mask}
  gateway ${default_v6gateway}

iface vmbr0 inet6 static
  address ${default_v6ip}
  netmask 64

EOF
fi

cat >> "$network_interfaces_file"  << EOF
### Private NAT network
auto vmbr1
iface vmbr1 inet static
  address  10.10.10.1
  netmask  255.255.255.0
  bridge_ports none
  bridge_stp off
  bridge_fd 0
  post-up   iptables -t nat -A POSTROUTING -s '10.10.10.0/24' -o ${default_interface} -j MASQUERADE
  post-down iptables -t nat -D POSTROUTING -s '10.10.10.0/24' -o ${default_interface} -j MASQUERADE

EOF

cat >> "$network_interfaces_file"  << EOF
### Extra IP/IP Ranges ###
# Use addiprange.sh script to add ip/ip ranges or edit the examples below
#
## Example add IP range 176.9.216.192/27
# up route add -net 94.130.239.192 netmask 255.255.255.192 gw ${default_v4gateway} dev ${default_interface}
## Example add IP 176.9.123.158
# up route add -net 176.9.123.158 netmask 255.255.255.255 gw ${default_v4gateway} dev ${default_interface}

EOF
