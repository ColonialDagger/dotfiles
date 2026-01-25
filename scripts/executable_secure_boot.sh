#!/usr/bin/env bash

sudo pacman -S --noconfirm sbctl

sbctl create-keys

# Detect Windows EFI installation
if [ -d /efi/EFI/Microsoft/Boot ]; then
    echo "Windows installation detected — enrolling keys with -m"
    sbctl enroll-keys -m
else
    echo "No Windows installation detected — enrolling keys normally"
    sbctl enroll-keys
fi

# Sign all unsigned files
sudo sbctl verify 2>&1 \
    | awk '/is not signed/ {print $2}' \
    | xargs -I{} sudo sbctl sign -s {}
