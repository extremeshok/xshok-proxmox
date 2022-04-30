#!/usr/bin/env bash
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
#
# Also installs and properly configures the isc-dhcp-server to allow for DHCP on the vmbr1 (NAT)
#
# ROUTED (vmbr0):
#   All traffic is routed via the main IP address and uses the MAC address of the physical interface.
#   VM's can have multiple IP addresses and they do NOT require a MAC to be set for the IP via service provider
#
# NAT (vmbr1):
#   Allows a VM to have internet connectivity without requiring its own IP address
#   Assignes 10.10.10.100 - 10.10.10.200 via DHCP
#
# Public IP's can be assigned via DHCP, adding a host define to the /etc/dhcp/hosts.public file
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

# Set the local
export LANG="en_US.UTF-8"
export LC_ALL="C"

network_interfaces_file="/etc/network/interfaces"

#Detect and install dependencies
if ! type "dhcpd" >& /dev/null; then
  /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install isc-dhcp-server
fi

if ! [ -f "network-addiprange.sh" ]; then
  echo "Downloading network-addiprange.sh script"
  curl -O https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/networking/network-addiprange.sh && chmod +x network-addiprange.sh
fi
if ! grep -q '#!/usr/bin/env bash' "network-addiprange.sh"; then
  echo "ERROR: network-addiprange.sh is invalid"
fi

if ! [ -f "/etc/sysctl.d/99-networking.conf" ]; then
  echo "Creating /etc/sysctl.d/99-networking.conf"
cat > /etc/sysctl.d/99-networking.conf <<EOF
net.ipv4.ip_forward=1
net.ipv4.conf.eth0.send_redirects=0
net.ipv6.conf.all.forwarding=1
EOF
fi

# Auto detect the existing network settings... this is all for ipv4
echo "Auto detecting existing network settings"
# Detect primary interface using the default route
default_interface="$(ip -o route get 8/32 | grep -o 'dev [^ ]*' | xargs | cut -d' ' -f 2)"
if [[ $default_interface == eth* ]] ; then
  # Search for the alt name, ie enp0s1 instead of eth0
  default_interface_altname="$(ip link show "${default_interface}" | grep -o 'altname [^ ]*' | xargs | cut -d' ' -f 2)"
  # Assign the alt name if present
  if [ -n "$default_interface_altname" ] && [ "$default_interface_altname" != " " ]; then
    default_interface="$default_interface_altname"
  fi
fi

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
if [ "$default_v4mask" == "$default_v4ip" ] ;then
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

# Generate an array containing parts of the default_v4ip
IFS='.' read -r -a default_v4ip_array <<< "$default_v4ip"

cp "$network_interfaces_file" "${network_interfaces_file}.$(date +"%Y-%m-%d_%H-%M-%S")"

cat > "$network_interfaces_file" <<EOF
###### eXtremeSHOK.com

### LOOPBACK ###
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

### VM-Bridge used by Proxmox
auto vmbr0
iface vmbr0 inet static
  address ${default_v4ip}
  netmask ${default_v4netmask}
  bridge_ports none
  bridge_stp off
  bridge_fd 0
  bridge_maxwait 0

### Private NAT used by Proxmox
auto vmbr1
iface vmbr1 inet static
  address  10.10.10.1
  netmask  255.255.255.0
  bridge_ports none
  bridge_stp off
  bridge_fd 0
  bridge_maxwait 0
  post-up   iptables -t nat -A POSTROUTING -s '10.10.10.0/24' -o ${default_interface} -j MASQUERADE
  post-down iptables -t nat -D POSTROUTING -s '10.10.10.0/24' -o ${default_interface} -j MASQUERADE

### Fast Private LAN
#iface enp28s0 inet manual
#auto vmbr2
#iface vmbr2 inet static
#  address  10.10.3.2
#  netmask  255.255.255.0
#  bridge_ports enp28s0
#  bridge_stp off
#  bridge_fd 0
#  pre-up ip link set enp28s0 mtu 8192
#
## ## Run the following to enable migrations via the Fast Private LAN:
## echo "migration: insecure,network=10.10.3.0/24" >> /etc/pve/datacenter.cfg

### Load extra files, ie for extra gateways
source /etc/network/interfaces.d/*

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
### Extra IP/IP Ranges ###
# Use ./network-addiprange.sh script to add ip/ip ranges or edit the examples below
#
## Example add IP range 176.9.216.192/27
# up route add -net 94.130.239.192 netmask 255.255.255.192 dev vmbr0
## Example add IP 176.9.123.158
# up route add -net 176.9.123.158 netmask 255.255.255.255 dev vmbr0

EOF


# Configure isc-dhcp-server
if [ -f "/etc/default/isc-dhcp-server" ] ; then
  cp /etc/default/isc-dhcp-server "/etc/default/isc-dhcp-server.$(date +"%Y-%m-%d_%H-%M-%S")"
fi
if [ -f "/etc/dhcp/dhcpd.conf" ] ; then
  cp /etc/dhcp/dhcpd.conf "/etc/dhcp/dhcpd.conf.$(date +"%Y-%m-%d_%H-%M-%S")"
fi

cat > /etc/default/isc-dhcp-server <<EOF
# Defaults for isc-dhcp-server (sourced by /etc/init.d/isc-dhcp-server)

# Path to dhcpd's config file (default: /etc/dhcp/dhcpd.conf).
#DHCPDv4_CONF=/etc/dhcp/dhcpd.conf
#DHCPDv6_CONF=/etc/dhcp/dhcpd6.conf

# Path to dhcpd's PID file (default: /var/run/dhcpd.pid).
#DHCPDv4_PID=/var/run/dhcpd.pid
#DHCPDv6_PID=/var/run/dhcpd6.pid

# Additional options to start dhcpd with.
#       Don't use options -cf or -pf here; use DHCPD_CONF/ DHCPD_PID instead
#OPTIONS=""

# On what interfaces should the DHCP server (dhcpd) serve DHCP requests?
#       Separate multiple interfaces with spaces, e.g. "eth0 eth1".
INTERFACESv4="vmbr0 vmbr1"
#INTERFACESv6="vmbr0"
EOF

cat > /etc/dhcp/dhcpd.conf <<EOF
### eXtremeSHOK.com
# https://linux.die.net/man/5/dhcpd.conf

ddns-update-style none;
default-lease-time 600;
max-lease-time 7200;
log-facility local7;

option rfc3442-classless-static-routes code 121 = array of integer 8;
option ms-classless-static-routes code 249 = array of integer 8;

option domain-name-servers 1.1.1.1,8.8.8.8;

### Default to private NAT network
subnet 0.0.0.0 netmask 0.0.0.0 {
  range 10.10.10.100 10.10.10.200 ;
  authoritative;
  default-lease-time 600;
  max-lease-time 432000000;
  option routers 10.10.10.1;
  option subnet-mask 255.255.255.0;
  option time-offset -18000;
  option broadcast-address 10.10.10.255;
  option rfc3442-classless-static-routes 32, 10, 10, 10, 1, 0, 0, 0, 0, 0, 10, 10, 10, 1;
  option ms-classless-static-routes 32, 10, 10, 10, 1, 0, 0, 0, 0, 0, 10, 10, 10, 1;
}

### vmbr0 ; Public Network
group public {
  authoritative;
  default-lease-time 21600000;
  max-lease-time 432000000;
  option routers ${default_v4ip};
  option subnet-mask 255.255.255.255;
  option rfc3442-classless-static-routes 32, ${default_v4ip_array[0]}, ${default_v4ip_array[1]}, ${default_v4ip_array[2]}, ${default_v4ip_array[3]}, 0, 0, 0, 0, 0, ${default_v4ip_array[0]}, ${default_v4ip_array[1]}, ${default_v4ip_array[2]}, ${default_v4ip_array[3]};
  option ms-classless-static-routes 32, ${default_v4ip_array[0]}, ${default_v4ip_array[1]}, ${default_v4ip_array[2]}, ${default_v4ip_array[3]}, 0, 0, 0, 0, 0, ${default_v4ip_array[0]}, ${default_v4ip_array[1]}, ${default_v4ip_array[2]}, ${default_v4ip_array[3]};
  # Add your host defines to the /etc/dhcp/hosts.public file
  include "/etc/dhcp/hosts.public";
}
#end group public

EOF
if [ ! -f "/etc/dhcp/hosts.public" ] ; then
cat > "/etc/dhcp/hosts.public" <<EOF
###########
## EXAMPLE client /etc/network/interfaces
# auto lo
# iface lo inet loopback
# auto eth0
# iface eth0 inet dhcp
###########
## Alpine linux dhcp requires:
# apk add dhclient
###########

## Assign a specific IP to a VM/CT with MAC 9E:94:13:7D:F3:0E to the IP 11.22.33.44 for host my.example.com
## set the bridge to vmbr0 and the MAC address will need to match the "hardware ethernet" MAC
#  host my.example.com {
#    hardware ethernet AA:BB:CC:DD:EE:00;
#    fixed-address 11.22.33.44;
#  }
#  host another.examle.com {
#    option host-name "another.example.com"
#    hardware ethernet 00:EE:DD:CC:BB:AA;
#    fixed-address 44.33.22.11;
#  }
#
#
#
EOF
fi

systemctl enable isc-dhcp-server

## Script Finish
echo -e '\033[1;33m Finished....please restart the system \033[0m'
