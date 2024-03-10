#!/usr/bin/env bash
set -e

# Archlinux
if [ -f "/etc/arch-release" ]; then
    sudo pacman -Su ansible
fi
