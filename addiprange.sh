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
#    THERE ARE  USER CONFIGURABLE OPTIONS IN THIS SCRIPT
#   ALL CONFIGURATION OPTIONS ARE LOCATED BELOW THIS MESSAGE
#
##############################################################


### Functions
#!/bin/bash
# CIDR Netmask Calculator


#printf "$1\t" # x
#printf "$y\t" # y

#assign and check arguments
if [ $# -lt "1" ] ; then
  echo "ERROR: missing aguments"
  echo "Usage: $(basename "$0") ip/mask optional_gateway_interface"
  exit 1
else
	ipwithcidr=$1
fi
if ! [[ "$ipwithcidr" =~ "/" ]] ; then
  echo "ERROR: IP missing cidr, use xxx.xxx.xxx.xxx/xx format: $ipwithcidr"
  exit 1
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
	maxip=$((2**(32-cidr) )) # y = 2^(32-x), x = CIDR class
fi
if [ "$2" != "" ] ; then
	gatewaydev="$2"
else
	gatewaydev="$(route -4 | grep default | awk '{ print $NF }')"
fi

## Not used because this is slower than the if/else block
#cdr2mask () {
#   # Number of args to shift, 255..255, first non-255 byte, zeroes
#   set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
#	 if [[ "$1" -gt 1 ]] ; then shift "$1" ; else shift ; fi
#   echo "${1-0}.${2-0}.${3-0}.${4-0}"
#}
#netmask="$(cdr2mask ""$cidr")"
# get the netmask
if ! [ "$((maxip/256**0))" -gt "256" ]; then		# y
	netmask="255.255.255.$((256-(maxip/256**0) ))"	# 256-(maxip)
elif ! [ "$((maxip/256**1))" -gt "256" ]; then		# maxip/256
	netmask="255.255.$((256-(maxip/256**1) )).0"	# 256-(maxip/256)
elif ! [ "$((maxip/256**2))" -gt "256" ]; then		# maxip/256/256
	netmask="255.$((256-(maxip/256**2) )).0.0"		# 256-(maxip/256/256)
elif ! [ "$((maxip/256**3))" -gt "256" ]; then		# maxip/256/256/256
	netmask="$((256-(maxip/256**3) )).0.0.0"		# 256-(maxip/256/256/256)
fi

#information
echo "MaximumIP $maxip"
echo "Netmask $netmask"
echo "cidr $cidr"
echo "networkip $networkip"
echo "gatewaydev $gatewaydev"

#add the route, so we do not need to restart
echo "Activating the route until restart"
echo "route add -net $networkip netmask $netmask dev $gatewaydev"

if [ -f "/etc/network/interfaces" ] ; then
	if ! grep -q "up route add -net $networkip netmask $netmask dev $gatewaydev" /etc/network/interfaces ; then
		echo "Permantly adding the route"
		echo "up route add -net $networkip netmask $netmask dev $gatewaydev" >> "/etc/network/interfaces"
	fi
fi


#permantly add the route
#check the route is not added



exit

#ipwithcidr="${1}"
#cidr=$

ip="$(grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' < "$ip")"
echo "IP: $ip"
#networkdevice="${2}"


if [ "${#networkdevice}" -lt "3" ] ; then
  echo "ERROR: Network device is too short : $networkdevice"
  exit 1
fi


exit


for zfsdevice in "${zfsdevicearray[@]}" ; do
  if ! [[ "${2}" =~ "/" ]] ; then
    echo "ERROR: Invalid device specified: $zfsdevice"
    exit 1
  fi
  if ! [ -e "$zfsdevice" ]; then
    echo "ERROR: Device $zfsdevice does not exist"
    exit 1
  fi
  if grep -q "$zfsdevice" "/proc/mounts" ; then
    echo "ERROR: Device is mounted $zfsdevice"
    exit 1
  fi
done
$poolname
echo "Creating the array"
if [ "${#zfsdevicearray[@]}" -eq "1" ] ; then
  echo "Creating ZFS mirror (raid1)"
  zpool create -f -o ashift=12 -O compression=lz4 "$poolname""pool" "${zfsdevicearray[@]}"
  ret=$?
elif [ "${#zfsdevicearray[@]}" -eq "2" ] ; then
  echo "Creating ZFS mirror (raid1)"
  zpool create -f -o ashift=12 -O compression=lz4 "$poolname""pool" mirror "${zfsdevicearray[@]}"
  ret=$?
elif [ "${#zfsdevicearray[@]}" -ge "3" ] && [ "${#zfsdevicearray[@]}" -le "5" ] ; then
  echo "Creating ZFS raidz-1 (raid5)"
  zpool create -f -o ashift=12 -O compression=lz4 "$poolname""pool" raidz "${zfsdevicearray[@]}"
  ret=$?
elif [ "${#zfsdevicearray[@]}" -ge "6" ] && [ "${#zfsdevicearray[@]}" -lt "11" ] ; then
  echo "Creating ZFS raidz-2 (raid6)"
  zpool create -f -o ashift=12 -O compression=lz4 "$poolname""pool" raidz2 "${zfsdevicearray[@]}"
  ret=$?
elif [ "${#zfsdevicearray[@]}" -ge "11" ] ; then
  echo "Creating ZFS raidz-3 (raid7)"
  zpool create -f -o ashift=12 -O compression=lz4 "$poolname""pool" raidz3 "${zfsdevicearray[@]}"
  ret=$?
fi

if [ $ret != 0 ] ; then
	echo "ERROR: creating ZFS"
	exit 1
fi

echo "Creating Secondary ZFS Pools"
zfs create "$poolname""pool/vmdata"
zfs create -o mountpoint="/backup_""$poolname" "$poolname""pool/backup"
zpool export "$poolname""pool"

if type "pvesm" > /dev/null; then
  echo "Adding the ZFS storage pools to Proxmox GUI"
  pvesm add dir "$poolname""backup" "/backup_""$poolname"
  pvesm add zfspool "$poolname""vmdata" -pool "$poolname""pool/vmdata" -sparse true
fi

echo "Setting ZFS Optimisations"
zfspoolarray=("$poolname""pool" "$poolname""pool/vmdata" "$poolname""pool/backup")
for zfspool in "${zfspoolarray[@]}" ; do
  echo "Optimising $zfspool"
  zfs set compression=on "$zfspool"
  zfs set compression=lz4 "$zfspool"
  zfs set sync=disabled "$zfspool"
  zfs set primarycache=all "$zfspool"
  zfs set atime=off "$zfspool"
  zfs set checksum=off "$zfspool"
  zfs set dedup=off "$zfspool"
done

#script Finish
echo -e '\033[1;33m Finished....please restart the server \033[0m'
