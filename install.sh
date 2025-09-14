#!/usr/bin/env bash

# Quick WiFi connection for laptop
# iwctl
# station wlan0 connect Hazen
# exit (from iwctl)
# ip addr (to confirm IP for SSH)
# chpasswd root:archlinux (quick and dirty password)

# Can download and call a script now from GitHub or via SSH!
# curl https:/raw.githubusercontent.com/sandipsky/arch/main/arch/sh -o arch.sh
# scp /home/kyle/Documents/archlinux.sh root@192.168.86.72:~/testinstall.sh
# ls (to show file)
# sh arch.sh

# Alternatively, use this (but prompts don't work):
# ssh root@archlinux 'bash -s' < local_script.sh

# PARTITION INFO AND MOUNTING HERE
# fdisk /dev/nvme0n1
#    type: 44 for LVM

echo "Welcome to Kyle's Arch Linux install script!"
echo "This script assumes that the necessary partitions have already been created."
read -p "Username: " USERNAME
read -p "Password: " PASSWORD
read -p "Hostname: " HOSTNAME
read -p "Init and populate pacman keys (fixes pacstrap issue)? [y/n]: " BOOL_FIX_KEYS
read -p "Use LUKS encryption? [y/n]: " ENCRYPT_OPTION
read -p "Install extra KDE Applications? [y/n]: " KDE_APPS_OPTION
read -p "Install GNOME? [y/n]: " GNOME_OPTION
read -p "Install Hyprland? [y/n]: " HYPRLAND_OPTION
read -p "Enable openssh? [y/n]: " OPENSSH_OPTION
read -p "Install Bluetooth? [y/n]: " BLUETOOTH_OPTION
read -p "Install Steam and dependencies? [y/n]: " STEAM_OPTION
read -p "Install extra KDE games? [y/n]: " EXTRA_GAMES_OPTION
read -p "Press [enter] to continue!"
# Hardcoded for now to avoid fat fingering (same reason I called it called MAIN instead of ROOT).
BOOT_PARTITION=/dev/nvme0n1p6
MAIN_PARTITION=/dev/nvme0n1p7
#HOME_PARTITION=/dev/nvme0n1p8
#SWAP_PARTITION=/dev/nvme0n1p8

mkfs.fat -F32 $BOOT_PARTITION
mkfs.ext4 $MAIN_PARTITION

## Encrpyption commands from tutorial
if [ "$ENCRYPT_OPTION" != "n" ]; then
  cryptsetup luksFormat $MAIN_PARTITION
  echo "Enter password again to open partition:"
  cryptsetup open --type luks $MAIN_PARTITION lvm
  pvcreate /dev/mapper/lvm
  vgcreate volgroup0 /dev/mapper/lvm
  lvcreate -l 100%FREE volgroup0 -n lv_root
  #lvcreate -L 30GB volgroup0 -n lv_root
  #lvcreate -l 100%FREE volgroup0 -n lv_home
  #vgdisplay
  #lvdisplay
  modprobe dm_mod
  vgscan
  vgchange -ay
  mkfs.ext4 /dev/volgroup0/lv_root
  #mkfs.ext4 /dev/volgroup0/lv_home
  mount /dev/volgroup0/lv_root /mnt
  mount --mkdir /dev/volgroup0/lv_home /mnt/home
else
  mount $MAIN_PARTITION /mnt
fi
mount --mkdir $BOOT_PARTITION /mnt/boot

if [ -n "$SWAP_PARTITION" ]; then
  mkswap $SWAP_PARTITION
  swapon $SWAP_PARTITION
#else
  # Make Swap file?
fi

if [ "$BOOL_FIX_KEYS" != "n" ]; then
  pacman-key --init
  pacman-key --populate
fi

echo "Running Pacstrap"
# dosfstools and mtools are needed for dealing with FAT32 filesystems
# Can install both kernels, but at least one is needed:
#   Option 1: linux linux-headers
#   Option 2: linux-lts linux-lts-headers
pacstrap -K /mnt base base-devel linux linux-headers linux-lts linux-lts-headers linux-firmware nano vim git dosfstools mtools sudo

genfstab -U -p /mnt >> /mnt/etc/fstab

# Access machine with "arch-chroot /mnt"
#arch-chroot /mnt
cat <<CHROOT_SCRIPT > /mnt/next.sh
useradd -m -g users -G wheel $USERNAME
usermod -c "GiGaChAd"
echo "root:$PASSWORD" | chpasswd
echo "$USERNAME:$PASSWORD" | chpasswd


echo "$HOSTNAME" > /etc/hostname

echo "Uncomment line to allow wheel members to execute as root."
#nano /etc/sudoers
sed -i 's|^# %wheel ALL=(ALL:ALL) ALL|%wheel ALL=(ALL:ALL) ALL|' /etc/sudoers

# Add AMD/Intel/Nvidia drivers as needed
# AMD CPU
pacman -S amd-ucode --noconfirm
# lspci (to see PCI devices)
#Intel GPU
#pacman -S mesa (and intel-media-driver if Broadwell or newer)
#AMD GPU
pacman -S mesa libva-mesa-driver vulkan-radeon --noconfirm
#NVIDIA GPU (nvidia for regular kernel, nvidia-lts for the lts kernel)
pacman -S nvidia nvidia-lts nvidia-utils --noconfirm --needed

echo "Installing and enabling important drivers and SDDM"
pacman -S iwd networkmanager sddm pipewire pipewire-jack pipewire-pulse openrgb --noconfirm --needed
systemctl enable sddm.service
systemctl enable NetworkManager.service

if [ "$BLUETOOTH_OPTION" != "n" ]; then
  pacman -S bluez bluez-utils --noconfirm --needed
  systemctl enable bluetooth.service
fi

pacman -S phonon-qt6-vlc
echo "Installing KDE Plasma"
# kde-workspace may be optional
pacman -S plasma-meta konsole kate dolphin plasma-workspace
# Install Flatpak; it should automatically integrate with Discover
pacman -S flatpak

if [ "$KDE_APPS_OPTION" != "n" ]; then
  pacman -S kde-applications
fi

# Comes with KDE?
pacman -S partitionmanager kcalc --noconfirm --needed

if [ "$GNOME_OPTION" != "n" ]; then
  pacman -S gnome gnome-tweaks
fi

if [ "$HYPRLAND_OPTION" != "n" ]; then
  echo "Installing Hyprland"
  pacman -S hyprland kitty --noconfirm --needed
fi

if [ "$OPENSSH_OPTION" != "n" ]; then
  pacman -S openssh
  systemctl enable sshd
fi

# Other useful applications
pacman -S firefox vlc --noconfirm --needed
# Developer apps
pacman -S gcc rustup npm clang cmake dotnet-runtime --noconfirm --needed

if [ "$ENCRYPT_OPTION" != "n" ]; then
  pacman -S lvm2 --noconfirm
  echo "Add hooks for encryption (insert encrypt lvm2 after block)"
  #nano /etc/mkinitcpio.conf
  # Edit to: HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt lvm2 filesystems fsck)
  sed -i 's|block filesystems|block encrypt lvm2 filesystems|g' /etc/mkinitcpio.conf
fi

# Install Plymouth (splash screen between GRUB and SDDM)
pacman -S plymouth --noconfirm --needed
sed -i 's|udev autodetect|udev plymouth autodetect|g' /etc/mkinitcpio.conf

## Init kernel
mkinitcpio -p linux
mkinitcpio -p linux-lts

#echo "Uncomment US English (for Steam) and any other desired locales."
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

# us-acentos is the US International keyboard layout
echo "KEYMAP=us-acentos" >> /etc/vconsole.conf
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
hwclock --systohc

#echo "Installing GRUB"
mount --mkdir $BOOT_PARTITION /boot/efi
pacman -S grub efibootmgr os-prober --noconfirm --needed
grub-install --target=x86_64-efi --bootloader-id=GRUB
# TODO: TPM keys for GRUB?
# grub-install --target=x86_64-efi --efi-directory=esp --bootloader-id=GRUB --modules="tpm" --disable-shim-lock
# Add splash for Plymouth and cryptdevice if encryption is enabled.
sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"|GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash"|g' /etc/default/grub
if [ "$ENCRYPT_OPTION" != "n" ]; then
  sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet|GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 cryptdevice=$MAIN_PARTITION:volgroup0 quiet|g' /etc/default/grub
fi
# enable OS_PROBER for dual boot
sed -i 's|^#GRUB_DISABLE_OS_PROBER=false|GRUB_DISABLE_OS_PROBER=false|g' /etc/default/grub

cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
grub-mkconfig -o /boot/grub/grub.cfg

if [ "$EXTRA_GAMES_OPTION" != "n" ]; then
  pacman -S konquest ksudoku kspaceduel pingus --noconfirm --needed
fi

if [ "$STEAM_OPTION" != "n" ]; then
  echo "Installing Steam and dependencies."
  # TODO: The below could be done more cleanly with another command.
  # It currently adds a new Include line instead of uncommenting the exisitng one.
  sed -i 's|^#\[multilib\]|\[multilib\]\nInclude = /etc/pacman.d/mirrorlist/\n|g' /etc/pacman.conf
  pacman -Sy
  # Steam needs 32-bit graphics drivers
  pacman -S lib32-vulkan-radeon --noconfirm --needed
  pacman -S lib32-nvidia-utils --noconfirm --needed
  pacman -S steam --noconfirm --needed
fi

# == USER CONFIG ==
# TODO: add this to config for icon:
# icon=/usr/share/pixmaps/archlinux-logo.svg
# To this:
# [Containments][2][Applets][28][Configuration][General]
# favoritesPortedToKAstats=true
# HERE
# systemFavorites=suspend\\,hibernate\\,reboot\\,shutdown

mkdir /home/$USERNAME/Downloads
curl -o /home/$USERNAME/Downloads/user.sh https://raw.githubusercontent.com/KyleTaylorLange/ArchLinux/refs/heads/main/user.sh
# TO TRY: can this be run here?
# Command if user:
# sed -i 's/org.kde.plasma.kickoff/org.kde.plasmakickerdash/g' ~/.config/plasma-org.kde.plasma.desktop-appletsrc
# Can't do this, sadly.
# sed -i 's/org.kde.plasma.kickoff/org.kde.plasmakickerdash/g' /home/$USERNAME/.config/plasma-org.kde.plasma.desktop-appletsrc

# Remember to invert scrolling for KDE.

CHROOT_SCRIPT

arch-chroot /mnt sh next.sh

#exit

umount -a

#reboot

# Oh hey, maybe I can make use of aliases for commonly-used directories? We'll see!

