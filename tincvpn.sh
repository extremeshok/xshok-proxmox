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
################################################################################
#
#    THERE ARE  USER CONFIGURABLE OPTIONS IN THIS SCRIPT
#   ALL CONFIGURATION OPTIONS ARE LOCATED BELOW THIS MESSAGE
#
##############################################################
vpn_ip_last=1
vpn_connect_to=prx-b
vpn_port=655
my_address=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | tail -n 1)


while getopts i:p:c:a:h option
do
  case "${option}"
    in
    i) vpn_ip_last=${OPTARG};;
    p) vpn_port=${OPTARG};;
    c) vpn_connect_to=${OPTARG};;
    a) my_address=${OPTARG};;
    *) echo "-i <last_ip_part 192.168.0.?> -p <vpn port if not 655> -c <vpn host file to connect to, prx_b> -a <public ip address, or will auto-detect>" ; exit;;
  esac
done

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
if [ "$(which tincd)" == "" ] ; then
  echo "Tinc not found, installing...."
  if [ "$(which yum)" != "" ] ; then
    yum install -y tinc
    elif [ "$(which apt-get)" != "" ] ; then
    apt-get install -y tinc
  fi
fi

#Create the DIR and key files
mkdir -p /etc/tinc/vpn/hosts
touch /etc/tinc/vpn/rsa_key.pub
touch /etc/tinc/vpn/rsa_key.priv

if [[ grep -q "BEGIN RSA PUBLIC KEY" "/etc/tinc/vpn/rsa_key.pub" ]] ; then
	if [[ grep -q "BEGIN RSA PRIVATE KEY" "/etc/tinc/vpn/rsa_key.priv" ]] ; then
		echo "Using Previous RSA Keys"
	else
		tincd -K4096 -c /etc/tinc/vpn </dev/null 2>/dev/null
	fi
else
	tincd -K4096 -c /etc/tinc/vpn </dev/null 2>/dev/null
fi

#Generate Configs
cat > /etc/tinc/vpn/tinc.conf <<EOF
Name = $my_name
AddressFamily = ipv4
Interfac = Tun0
Mode = switch
ConnectTo = $vpn_connect_to
EOF

cat > /etc/tinc/vpn/hosts/$my_name <<EOF
Address = $my_address
Port = $vpn_port
Compression = 10 #LZO
EOF
cat /etc/tinc/vpn/rsa_key.pub >> /etc/tinc/vpn/hosts/$my_name

cat > /etc/tinc/vpn/tinc-up <<EOF
#!/bin/bash
ip link set \$INTERFACE up
ip addr add  192.168.0.$vpn_ip_last/32 dev \$INTERFACE
ip route add 192.168.0.0/24 dev $INTERFACE

# Set a multicast route over interface
route add -net 224.0.0.0 netmask 240.0.0.0 dev \$INTERFACE

# To allow IP forwarding:
#echo 1 > /proc/sys/net/ipv4/ip_forward

# To limit the chance of Corosync Totem re-transmission issues:
#echo 0 > /sys/devices/virtual/net/\$INTERFACE/bridge/multicast_snooping
EOF

cat > /tmp/tinc-down <<EOF
#!/bin/bash
ip route del 192.168.0.0/24 dev \$INTERFACE
ip addr del 192.168.0.$vpn_ip_last/32 dev \$INTERFACE
ip link set \$INTERFACE down

# Set a multicast route over interface
route del -net 224.0.0.0 netmask 240.0.0.0 dev \$INTERFACE

#echo 0 > /proc/sys/net/ipv4/ip_forward
EOF

# Set which VPN to start
echo "vpn" >> /etc/tinc/nets.boot

# Enable at Boot
systemctl enable tinc.service

#Display the Host config for simple cpy-paste to another node
echo "Run the following on the other VPN nodes:"
echo "cat > /etc/tinc/vpn/hosts/$my_name << EOF"
cat /etc/tinc/vpn/hosts/$my_name
echo "EOF"
