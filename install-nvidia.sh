xserver-xorg-dev dkms
libgtk-3-0

#!/bin/bash
apt-get install build-essential pve-headers-$(uname -r) pkg-config 
update-grub
reboot



wget https://us.download.nvidia.com/XFree86/Linux-x86_64/455.38/NVIDIA-Linux-x86_64-455.38.run
chmod +x NVIDIA-Linux-x86_64-455.38.run
./NVIDIA-Linux-x86_64-455.38.run

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

# Add the package repositories
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | \
  apt-key add -
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  tee /etc/apt/sources.list.d/nvidia-docker.list
apt-get update

# Install nvidia-docker2 and reload the Docker daemon configuration
apt-get install -y nvidia-docker2
pkill -SIGHUP dockerd
             
             
Unlock card with
sudo nvidia-xconfig -a --cool-bits=31 --allow-empty-initial-configuration
nvidia-smi -pl 200 -i 0

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