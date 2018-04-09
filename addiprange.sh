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
# Creates default routes to allow for extra ip ranges to be used.
# Tested on OVH servers with VLAN
#
# NOTE: WILL APPLY CHANGES TO /etc/network/interfaces
#
# Usage:
# curl -O https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/addiprange.sh && chmod +x addiprange.sh
# ./addiprange.sh ip.xx.xx.xx/cidr interface_optionakl
#
# If no interface is specified the default gateway interface will be used.
#
################################################################################
#
#    THERE ARE NO USER CONFIGURABLE OPTIONS IN THIS SCRIPT
#
##############################################################

#assign and check arguments
if [ $# -lt "1" ] ; then
  echo "ERROR: missing aguments"
  echo "Usage: $(basename "$0") ip/mask optional_gateway_interface"
  exit 1
else
	ipwithcidr=$1
fi
if ! [[ "$ipwithcidr" =~ "/" ]] ; then
  echo "Info: IP missing cidr, assigning default: 32"
  cidr="32"
else
	networkip=${ipwithcidr%/*}
	cidr=${ipwithcidr##*/}
fi
if ! [[ $networkip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
	echo "ERROR: Invaid IP, use xxx.xxx.xxx.xxx/xx format: $networkip"
	exit 1
fi
if ! [ "$cidr" -eq "$cidr" ] 2> /dev/null ; then
    echo "Error: Invalid CIDR must be an integer $cidr"
		exit 1

fi
if [ "$cidr" -lt "1" ] || [ "$cidr" -gt "32" ] ; then
	echo "ERROR: Invalid CIDR $cidr"
	exit 1
else
	totalip=$((2**(32-cidr) )) # y = 2^(32-x), x = CIDR class
fi
if [ "$2" != "" ] ; then
	gatewaydev="$2"
else
	gatewaydev="$(route -4 | grep default | awk '{ print $NF }')"
fi
usableip=$((totalip - 2))
if [ "$usableip" -eq "0" ] ; then
	echo "ERROR: No usable IP ($totalip - 2 = $usableip)"
	exit 1
fi
## Not used because this is slower than the if/else block
#cdr2mask () {
#   set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
#	  if [[ "$1" -gt 1 ]] ; then shift "$1" ; else shift ; fi ;  echo "${1-0}.${2-0}.${3-0}.${4-0}"
#}
#netmask="$(cdr2mask ""$cidr")"
# get the netmask
if ! [ "$((totalip/256**0))" -gt "256" ]; then		# y
	netmask="255.255.255.$((256-(totalip/256**0) ))"	# 256-(totalip)
elif ! [ "$((totalip/256**1))" -gt "256" ]; then		# totalip/256
	netmask="255.255.$((256-(totalip/256**1) )).0"	# 256-(totalip/256)
elif ! [ "$((totalip/256**2))" -gt "256" ]; then		# totalip/256/256
	netmask="255.$((256-(totalip/256**2) )).0.0"		# 256-(totalip/256/256)
elif ! [ "$((totalip/256**3))" -gt "256" ]; then		# totalip/256/256/256
	netmask="$((256-(totalip/256**3) )).0.0.0"		# 256-(totalip/256/256/256)
fi

#information
echo "UsableIP $usableip | TotalIP $totalip | Netmask $netmask | CIDR $cidr | NetworkIP $networkip | GatewayDev $gatewaydev"

# Check if the route is currently in use, otherwise add it.
res="$(route | grep "$networkip" | grep "$netmask" | grep "$gatewaydev")"
if [ "$res" == "" ] ; then
	echo "Activating the route until restart"
	myroute="$(which route)"
	$myroute add -net "$networkip" netmask "$netmask" dev "$gatewaydev"
else
	echo "Route is already active"
fi

if ! grep -q "source /etc/network/interfaces.d/*" ; then
	echo "Permantly added the route (/etc/network/interfaces.d/${networkip}_${cidr}_${gatewaydev})"
	echo "up route add -net $networkip netmask $netmask dev $gatewaydev" > "/etc/network/interfaces.d/${networkip}_${cidr}_${gatewaydev}"
else
	if [ -w "/etc/network/interfaces" ] ; then
		if ! grep -q "up route add -net $networkip netmask $netmask dev $gatewaydev" "/etc/network/interfaces" ; then
			echo "Permantly added the route"
			echo "up route add -net $networkip netmask $netmask dev $gatewaydev" >> "/etc/network/interfaces"
		else
			echo "Route is already permantly added"
		fi
	fi
fi
#script Finish
echo -e '\033[1;33m Finished \033[0m'
