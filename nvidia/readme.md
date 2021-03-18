# initial work by @88plug

xserver-xorg-dev dkms

#!/bin/bash
apt-get install build-essential pve-headers-$(uname -r) pkg-config libgtk-3-0 libglvnd-dev
update-grub
REBOOT


#Old Driver
#wget https://us.download.nvidia.com/XFree86/Linux-x86_64/455.38/NVIDIA-Linux-x86_64-455.38.run
#chmod +x NVIDIA-Linux-x86_64-455.38.run
#./NVIDIA-Linux-x86_64-455.38.run

wget https://us.download.nvidia.com/XFree86/Linux-x86_64/460.56/NVIDIA-Linux-x86_64-460.56.run
chmod +x NVIDIA-Linux-x86_64-460.56.run
./NVIDIA-Linux-x86_64-460.56.run

Installer will ask to create modeprobe file, say YES!
Reboot
Run ./NVIDIA-Linux-x86_64-455.38.run again

WARNING: nvidia-installer was forced to guess the X library path '/usr/lib' and X module path '/usr/lib/xorg/modules'; these paths were not queryable from the system.  If X fails to find the NVIDIA X driver module, please
           install the `pkg-config` utility and the X.Org SDK/development package for your distribution and reinstall the driver

           YES to 32 bit dependencies

             Would you like to run the nvidia-xconfig utility to automatically update your X configuration file so that the NVIDIA X driver will be used when you restart X?  Any pre-existing X configuration file will be backed up.

             NO


REBOOT
nvidia-smi!

Now run ./docker.sh to install nvidia-docker!

Unlock card with
sudo nvidia-xconfig -a --cool-bits=31 --allow-empty-initial-configuration
nvidia-smi -pl 200 -i 0

Now if you want to overclock you need a Xauthority/gdm

tasksel > install gnome desktop
then run this command
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
as gnome stupidly enables sleep by default!
finally reboot...you should now have a folder
/run/user/$SOMENUMBER/gdm/Xauthority

replace $SOMENUBMER in lines below! :)

DISPLAY=:0 XAUTHORITY=/run/user/121/gdm/Xauthority sudo nvidia-settings -a [gpu:0]/GPUFanControlState=1 -a [fan-0]/GPUTargetFanSpeed=80
sleep 3
DISPLAY=:0 XAUTHORITY=/run/user/121/gdm/Xauthority sudo nvidia-settings -a [gpu:1]/GPUFanControlState=1 -a [fan-1]/GPUTargetFanSpeed=80
sleep 3
DISPLAY=:0 XAUTHORITY=/run/user/121/gdm/Xauthority sudo nvidia-settings -a [gpu:2]/GPUFanControlState=1 -a [fan-2]/GPUTargetFanSpeed=80
sleep 3
DISPLAY=:0 XAUTHORITY=/run/user/121/gdm/Xauthority sudo nvidia-settings -a [gpu:3]/GPUFanControlState=1 -a [fan-3]/GPUTargetFanSpeed=85

DISPLAY=:0 XAUTHORITY=/run/user/121/gdm/Xauthority nvidia-settings -a '[gpu:0]/GPUGraphicsClockOffset[3]=150'
DISPLAY=:0 XAUTHORITY=/run/user/121/gdm/Xauthority nvidia-settings -a '[gpu:0]/GPUMemoryTransferRateOffset[3]=600'
DISPLAY=:0 XAUTHORITY=/run/user/121/gdm/Xauthority nvidia-settings -a '[gpu:1]/GPUGraphicsClockOffset[3]=150'
DISPLAY=:0 XAUTHORITY=/run/user/121/gdm/Xauthority nvidia-settings -a '[gpu:1]/GPUMemoryTransferRateOffset[3]=600'
DISPLAY=:0 XAUTHORITY=/run/user/121/gdm/Xauthority nvidia-settings -a '[gpu:2]/GPUGraphicsClockOffset[3]=150'
DISPLAY=:0 XAUTHORITY=/run/user/121/gdm/Xauthority nvidia-settings -a '[gpu:2]/GPUMemoryTransferRateOffset[3]=600'
DISPLAY=:0 XAUTHORITY=/run/user/121/gdm/Xauthority nvidia-settings -a '[gpu:3]/GPUGraphicsClockOffset[3]=150'
DISPLAY=:0 XAUTHORITY=/run/user/121/gdm/Xauthority nvidia-settings -a '[gpu:3]/GPUMemoryTransferRateOffset[3]=600'
