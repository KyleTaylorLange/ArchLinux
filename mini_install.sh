#!/usr/bin/env bash

# Prerequisites:
# - [multilib] uncommented from /etc/pacman.conf in ISO
# - Partitions made

SECONDS=0

# Values to change per install
HOSTNAME=archlinux-test-script
USERNAME=kyle
FULLNAME=Kyle
BOOT_PARTITION=/dev/?
MAIN_PARTITION=/dev/?
# Disk that the boot partition is on, e.g. /dev/sdb
EFI_DISK=/dev/?
# Partition number for the boot partition, e.g. 1
EFI_PART=?

wipefs --all $BOOT_PARTITION
wipefs --all $MAIN_PARTITION
mkfs.fat -F32 $BOOT_PARTITION
mkfs.btrfs $MAIN_PARTITION
mount $MAIN_PARTITION /mnt
mount --mkdir $BOOT_PARTITION /mnt/boot

# Fix keyring/NTP issue and update packages.
pacman-key --init
pacman-key --populate
pacman -Syy

# Core of system
pacstrap -C /etc/pacman.conf -K /mnt lvm2 --noconfirm --needed
pacstrap -C /etc/pacman.conf -K /mnt base sudo linux-firmware mkinitcpio linux linux-lts btrfs-progs amd-ucode --noconfirm --needed
# Old packages from original script; verify which are needed.
#pacstrap -K /mnt base-devel linux-headers linux-lts-headers dosfstools mtools

# Useful utils for any fresh install
pacstrap -C /etc/pacman.conf -K /mnt firefox nano vim git fastfetch flatpak --noconfirm --needed

# Generate fstab after mount but before any chroot commands
genfstab -U -p /mnt >> /mnt/etc/fstab

# From original script; needed for locale-gen?
# sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
arch-chroot -S /mnt locale-gen

# Plymouth
pacstrap -C /etc/pacman.conf -K plymouth --noconfirm --needed
arch-chroot -S /mnt plymouth-set-default-theme text
arch-chroot -S /mnt mkinitcpio -P

# Limine bootloader
pacstrap -C /etc/pacman.conf -K /mnt limine efibootmgr --noconfirm --needed
mkdir -p /mnt/boot/EFI/arch-limine
cp /mnt/usr/share/limine/BOOTX64.EFI /mnt/boot/EFI/arch-limine/
efibootmgr \
--create \
--disk $EFI_DISK \
--part $EFI_PART \
--label "Arch Linux" \
--loader '\EFI\arch-limine\BOOTX64.EFI' \
--unicode
# TODO: setup limine.conf in more detail
cat limine.conf > /mnt/boot/limine.conf

# Fonts
pacstrap -C /etc/pacman/conf -K /mnt noto-fonts noto-fonts-emoji noto-fonts-cjk ttf-liberation ttf-dejavu --noconfirm --needed

# Audio
pacstrap -C /etc/pacman.conf -K pipewire pipewire-alsa pipewire-jack pipewire-pulse gst-plugin-pipewire libpulse wireplumber --noconfirm --needed

# Network manager
pacstrap -C /etc/pacman.conf -K /mnt networkmanager --noconfirm --needed
systemctl --root=/mnt enable NetworkManager.service

# Bluetooth
pacstrap -C /etc/pacman.conf -K /mnt bluez bluez-utils --noconfirm --needed
systemctl --root=/mnt enable bluetooth.service

# Firewall
pacstrap -C /etc/pacman.conf -K /mnt ufw --noconfirm --needed
systemctl --root=/mnt enable ufw.service

# Plasma Desktop and Apps
pacstrap -C /etc/pacman.conf -K /mnt plasma-meta --noconfirm --needed
pacstrap -C /etc/pacman.conf -K /mnt konsole dolphin discover kcalc partitionmanager --noconfirm --needed

# Plasma Login Manager
pacstrap -C /etc/pacman.conf -K /mnt plasma-login-manager --noconfirm --needed
systemctl --root=/mnt enable plasmalogin

# OpenSSH
pacstrap -C /etc/pacman.conf -K /mnt openssh --noconfirm --needed
systemctl --root=/mnt enable sshd

# Time Zone
arch-chroot -S /mnt ln -s /usr/share/zoneinfo/US/Pacific /etc/localtime
systemctl --root=/mnt enable systemd-timesyncd

# Users
arch-chroot -S /mnt useradd -m -g users -G wheel $USERNAME
arch-chroot -S /mnt chfn -f "$FULLNAME" $USERNAME
# TODO: passwords
# Hostname
echo "$HOSTNAME" > /mnt/etc/hostname

# TODO: Graphics drivers for AMD (or NVIDIA)
# Need libva-mesa-driver xf86-video-amdgpu too?
pacstrap -C /etc/pacman.conf -K /mnt mesa vulkan-radeon --noconfirm --needed

# TODO: Steam
pacstrap -C /etc/pacman.conf -K /mnt steam --noconfirm --needed

# Extra KDE games for fun
pacstrap -C /etc/pacman.conf -K /mnt konquest ksudoku kspaceduel pingus --noconfirm --needed

#echo "Uncomment line to allow wheel members to execute as root."
#nano /etc/sudoers
#sed -i 's|^# %wheel ALL=(ALL:ALL) ALL|%wheel ALL=(ALL:ALL) ALL|' /etc/sudoers

# us-acentos is the US International keyboard layout
echo "KEYMAP=us-acentos" >> /mnt/etc/vconsole.conf
echo "LANG=en_US.UTF-8" >> /mnt/etc/locale.conf
# hwclock --systohc

echo "Install script finished in $SECONDS seconds!"
echo "TODO: set passwords, uncomment wheel from /etc/sudoers, verify EFI, umount before exit"
