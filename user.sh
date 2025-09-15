#!/usr/bin/env bash

# This file contains commands to be run after rebooting the computer after reinstall and logging in.
plasma-apply-lookandfeel -a org.kde.breezedark.desktop
flatpak install flathub com.discordapp.Discord -y
flatpak install flathub com.spotify.Client -y
flatpak install flathub org.gimp.GIMP -y
flatpak install flathub org.audacityteam.Audacity -y
flatpak install flathub org.libreoffice.LibreOffice -y
flatpak install flathub org.kde.kdenlive -y
