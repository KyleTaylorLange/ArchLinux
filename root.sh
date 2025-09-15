#!/usr/bin/env bash

pacman -S steam --noconfirm --needed
pacman -S flatpak --noconfirm --needed
pacman -S firefox vlc --noconfirm --needed
# Developer apps
pacman -S git nano vim neovim
pacman -S gcc rustup npm clang cmake dotnet-runtime --noconfirm --needed
# Virtualization packages
pacman -S qemu-full libvirt virt-manager --noconfirm --needed
# Extra KDE programs
pacman -S partitionmanager kcalc gwenview --noconfirm --needed
pacman -S konquest ksudoku kspaceduel pingus

# Install and enable Plymouth
pacman -S plymouth --noconfirm --needed
sed -i 's|udev autodetect|udev plymouth autodetect|g' /etc/mkinitcpio.conf
sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"|GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash"|g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

## Init kernel
mkinitcpio -p linux
mkinitcpio -p linux-lts
