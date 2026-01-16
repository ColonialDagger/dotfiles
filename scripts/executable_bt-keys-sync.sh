#!/usr/bin/bash

# Check if bluetooth.service is enabled
if ! systemctl is-enabled --quiet bluetooth.service; then
    echo "Bluetooth is not enabled. Enable and start it now? [y/N]"
    read -r answer

    case "$answer" in
        [yY]|[yY][eE][sS])
            sudo systemctl enable bluetooth.service
            sudo systemctl start bluetooth.service
            ;;
        *)
            echo "Bluetooth will not be enabled."
            exit 0
            ;;
    esac
else
    echo "Bluetooth service is already enabled."
fi

# Run bt-keys-sync script
bash -c "$(curl -fsSL https://raw.githubusercontent.com/KeyofBlueS/bt-keys-sync/refs/heads/main/bt-keys-sync.sh)"
