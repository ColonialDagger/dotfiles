#!/usr/bin/bash

# Require a Windows mount point argument
if [ -z "$1" ]; then
    echo "Usage: $0 <windows_mount_point>"
    exit 1
fi

WINDOWS_MOUNT="$1"
SYSTEM_HIVE_PATH="$WINDOWS_MOUNT/Windows/System32/config/SYSTEM"

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

# Run bt-keys-sync with arguments
bash -c "$(curl -fsSL https://raw.githubusercontent.com/KeyofBlueS/bt-keys-sync/refs/heads/main/bt-keys-sync.sh)" -- \
    --path "$SYSTEM_HIVE_PATH" \
    --windows-keys
