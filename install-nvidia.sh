xserver-xorg-dev dkms


#!/bin/bash
apt-get install build-essential pve-headers-$(uname -r)
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
             
