#/usr/bin/bash

sudo systemctl start bluetooth.service
sudo systemctl enable bluetooth.service

# Comes from https://github.com/KeyofBlueS/bt-keys-sync
bash -c "$(curl -fsSL https://raw.githubusercontent.com/KeyofBlueS/bt-keys-sync/refs/heads/main/bt-keys-sync.sh)"
