#!/bin/bash
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
# curl -O https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/tincvpn.sh && chmod +x tincvpn.sh
# ./tincvpn.sh -h
#
# Example for 3 node Cluster
# First Host (hostname: host1)
# ./tincvpn.sh -i 1 -c host2
# Second Host (hostname: host2)
# ./tincvpn.sh -i 2 -c host3
# Third Host (hostname: host3)
# ./tincvpn.sh -3 -c host1
#
# Example for 2 node Cluster
# First Host (hostname: host1)
# ./tincvpn.sh -i 1 -c host2
# Second Host (hostname: host2)
# ./tincvpn.sh -i 2 -c host1
#
################################################################################
#
#    THERE ARE  USER CONFIGURABLE OPTIONS IN THIS SCRIPT
#   ALL CONFIGURATION OPTIONS ARE LOCATED BELOW THIS MESSAGE
#
##############################################################
vpn_ip_last=1
vpn_connect_to=prx-b
vpn_port=655
my_address=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '192.168.' | grep -v '10.0' | grep -v '10.10.' | grep -v '127.0.0.1' | tail -n 1)
reset="no"

while getopts i:p:c:a:rh option
do
  case "${option}"
      in
    i) vpn_ip_last=${OPTARG} ;;
    p) vpn_port=${OPTARG} ;;
    c) vpn_connect_to=${OPTARG} ;;
    a) my_address=${OPTARG} ;;
    r) reset="yes" ;;
    *) echo "-i <last_ip_part 192.168.0.?> -p <vpn port if not 655> -c <vpn host file to connect to, prx_b> -a <public ip address, or will auto-detect> -r (reset/reinstall)" ; exit ;;
  esac
done

if [ "$my_address" == "" ] ; then
  echo "Error: address not detected, please use -a <public ip address>"
  exit
fi

if [ "$reset" == "yes" ] ; then
  echo "Resetting"
  systemctl stop tinc.service
  pkill -9 tincd
  rm -rf /etc/tinc/
fi


#Assign and Fix varibles
vpn_connect_to=${vpn_connect_to/-/_}
my_name=$(uname -n)
my_name=${my_name/-/_}

echo "Options:"
echo "VPN IP: 192.168.1.$vpn_ip_last"
echo "VPN PORT: vpn_port"
echo "VPN Connect to host: vpn_connect_to"
echo "Public Address: $my_address"

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
mkdir -p /etc/tinc/vpn/hosts
touch /etc/tinc/vpn/rsa_key.pub
touch /etc/tinc/vpn/rsa_key.priv

if [ "$(grep "BEGIN RSA PUBLIC KEY" /etc/tinc/vpn/rssa_key.pub 2> /dev/null)" != "" ] ; then
  if [ "$(grep "BEGIN RSA PRIVATE KEY" /etc/tinc/vpn/rssa_key.priv 2> /dev/null)" != "" ] ; then
    echo "Using Previous RSA Keys"
  else
    echo "Generating New RSA Keys"
    tincd -K4096 -c /etc/tinc/vpn </dev/null 2>/dev/null
  fi
else
  echo "Generating New RSA Keys"
  tincd -K4096 -c /etc/tinc/vpn </dev/null 2>/dev/null
fi

#Generate Configs
cat <<EOF > /etc/tinc/vpn/tinc.conf
Name = $my_name
AddressFamily = ipv4
Interface = Tun0
Mode = switch
ConnectTo = $vpn_connect_to
EOF

cat <<EOF > "/etc/tinc/vpn/hosts/$my_name"
Address = $my_address
Port = $vpn_port
Compression = 10 #LZO
EOF
cat /etc/tinc/vpn/rsa_key.pub >> "/etc/tinc/vpn/hosts/$my_name"

cat <<EOF > /etc/tinc/vpn/tinc-up
#!/bin/bash
ip link set \$INTERFACE up
ip addr add  192.168.0.$vpn_ip_last/24 dev \$INTERFACE
ip route add 192.168.0.0/24 dev \$INTERFACE

# Set a multicast route over interface
route add -net 224.0.0.0 netmask 240.0.0.0 dev \$INTERFACE

# To allow IP forwarding:
#echo 1 > /proc/sys/net/ipv4/ip_forward

# To limit the chance of Corosync Totem re-transmission issues:
#echo 0 > /sys/devices/virtual/net/\$INTERFACE/bridge/multicast_snooping
EOF

chmod 755 /etc/tinc/vpn/tinc-up

cat <<EOF > /etc/tinc/vpn/tinc-down
#!/bin/bash
ip route del 192.168.0.0/24 dev \$INTERFACE
ip addr del 192.168.0.$vpn_ip_last/24 dev \$INTERFACE
ip link set \$INTERFACE down

# Set a multicast route over interface
route del -net 224.0.0.0 netmask 240.0.0.0 dev \$INTERFACE

#echo 0 > /proc/sys/net/ipv4/ip_forward
EOF

chmod 755 /etc/tinc/vpn/tinc-down

# Set which VPN to start
echo "vpn" >> /etc/tinc/nets.boot

# Enable at Boot
systemctl enable tinc.service

# Add a Tun0 entry to /etc/network/interfaces to allow for ceph suport over the VPN
if [ "$(grep "iface Tun0" /etc/network/interfaces 2> /dev/null)" == "" ] ; then
  cat <<EOF >> /etc/network/interfaces

iface Tun0 inet static
        address 192.168.0.$vpn_ip_last
        netmask 255.255.255.0
        broadcast 0.0.0.0

EOF
fi


#Display the Host config for simple cpy-paste to another node
echo "Run the following on the other VPN nodes:"
echo "cat > /etc/tinc/vpn/hosts/$my_name << EOF"
cat "/etc/tinc/vpn/hosts/$my_name"
echo "EOF"
