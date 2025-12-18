#!/bin/bash

echo "Raspberry Pi aa-proxy/aa-proxy-rs Flashing Utility"

# Check latest version
echo "Grabbing latest version..."
VERSION=$(wget -qO- https://github.com/aa-proxy/aa-proxy-rs/releases/latest | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n 1)

# Define available images
IMAGES=(
    "raspberrypi0w-sdcard.img.xz"
    "raspberrypi3a-sdcard.img.xz"
    "raspberrypi4-sdcard.img.xz"
    "raspberrypizero2w-sdcard.img.xz"
)

# Display choices
echo "Available images:"
for i in "${!IMAGES[@]}"; do
    echo "    $((i+1)). ${IMAGES[i]}"
done

# Prompt user for image selection
read -p "Enter the number corresponding to the image you want to use: " IMAGE_INDEX

# Validate user input
if ! [[ "$IMAGE_INDEX" =~ ^[1-4]$ ]]; then
    echo "Invalid selection. Exiting."
    exit 1
fi

# Assign selected image
SELECTED_IMAGE="${IMAGES[$((IMAGE_INDEX-1))]}"
IMAGE_URL="https://github.com/aa-proxy/aa-proxy-rs/releases/download/$VERSION/$SELECTED_IMAGE"

# Prompt the user for the destination device
read -p "Enter the target device (e.g., /dev/sdc): " TARGET_DEVICE

# Ensure the user provided a device
if [ -z "$TARGET_DEVICE" ]; then
    echo "No device specified. Exiting."
    exit 1
fi

# Enter tmp directory
TMP_DIR="/tmp/wireless_auto"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# Download and extract the selected image file
wget -q --show-progress "$IMAGE_URL"
xz --decompress "$SELECTED_IMAGE"

# Remove the `.xz` extension for the extracted file name
EXTRACTED_IMAGE="${SELECTED_IMAGE%.xz}"

# Write the image to the specified device
sudo dd if="$EXTRACTED_IMAGE" of="$TARGET_DEVICE" status=progress

echo "Flashing complete!"
