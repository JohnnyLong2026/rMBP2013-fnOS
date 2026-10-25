ssh-keygen -R 192.168.1.4

#开启SSH
sudo apt update
sudo apt install openssh-server
sudo systemctl enable --now ssh
sudo systemctl status ssh
sudo ufw allow ssh
ip a

#修改镜像
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo nano /etc/apt/sources.list
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble-security main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble-security main restricted universe multiverse
sudo apt update
#sudo cp /etc/apt/sources.list.bak /etc/apt/sources.list

uname -r
安装 6.8.0-107 内核
sudo apt update
sudo apt install linux-image-6.8.0-107-generic linux-headers-6.8.0-107-generic

sudo nano /etc/default/grub
找到 GRUB_DEFAULT=0，将其改为：
GRUB_DEFAULT="Advanced options for Ubuntu>Ubuntu, with Linux 6.8.0-107-generic"
sudo update-grub

sudo reboot
删除旧内核
sudo apt purge linux-image-6.17.0-20-generic linux-headers-6.17.0-20-generic
sudo apt autoremove --purge
sudo update-grub

1. 安装缺失的内核模块包
sudo apt update
sudo apt install linux-modules-$(uname -r) linux-modules-extra-$(uname -r)
sudo apt install linux-image-$(uname -r) linux-modules-$(uname -r) linux-modules-extra-$(uname -r)
ls /lib/modules/$(uname -r)/kernel/net/wireless/cfg80211.ko*
sudo depmod -a
sudo modprobe cfg80211
sudo modprobe wl
iwconfig
echo "blacklist b43" | sudo tee /etc/modprobe.d/blacklist-broadcom.conf
echo "blacklist bcma" | sudo tee -a /etc/modprobe.d/blacklist-broadcom.conf
echo "blacklist ssb" | sudo tee -a /etc/modprobe.d/blacklist-broadcom.conf
echo "wl" | sudo tee /etc/modules-load.d/wl.conf
sudo update-initramfs -u
sudo reboot
