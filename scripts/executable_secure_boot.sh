#!/usr/bin/bash

sudo pacman -S sbctl

sbctl create-keys
sbctl enroll-keys -m
sudo sbctl verify 2>&1 | awk '/is not signed/ {print $2}' | xargs -I{} sudo sbctl sign -s {}
