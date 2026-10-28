#!/bin/bash
set -e

DEVICE="/dev/ttyACM0"
RULES_FILE="/etc/udev/rules.d/80-snap.snapd.rules"
TARGET_LINK="/dev/ttyUSBDebugModule"

# 1. Bind vendor/product ID to cdc_acm driver
echo "Binding device 04e2:1411 to cdc_acm..."
echo "04e2 1411" | tee /sys/bus/usb/drivers/cdc_acm/new_id > /dev/null

# 2. Wait for device node /dev/ttyACM0 to appear
echo "Waiting for ${DEVICE}..."
for i in {1..10}; do
    if [ -c "$DEVICE" ]; then
        break
    fi
    sleep 1
done

if [ ! -c "$DEVICE" ]; then
    echo "Error: ${DEVICE} was not found after binding." >&2
    exit 1
fi

# 3. Wait and extract ID_PATH_TAG from udevadm info
ID_PATH_TAG=""
for i in {1..10}; do
    ID_PATH_TAG=$(udevadm info "$DEVICE" | grep "E: ID_PATH_TAG=" | cut -d'=' -f2)
    if [ -n "$ID_PATH_TAG" ]; then
        break
    fi
    sleep 0.5
done

if [ -z "$ID_PATH_TAG" ]; then
    echo "Error: Could not extract ID_PATH_TAG from udevadm output." >&2
    exit 1
fi

echo "Extracted ID_PATH_TAG: ${ID_PATH_TAG}"

# 4. Construct the udev rule
RULE="SUBSYSTEM==\"tty\", ENV{ID_USB_DRIVER}==\"cdc_acm\", ENV{ID_PATH_TAG}==\"${ID_PATH_TAG}\", SYMLINK+=\"ttyUSBDebugModule\""

# 5. Append the rule to the rules file
echo "Adding rule to ${RULES_FILE}..."
echo "$RULE" | tee -a "$RULES_FILE" > /dev/null

# 6. Reload udev rules and trigger
echo "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger

# 7. Check if symlink is created
echo "Verifying ${TARGET_LINK}..."
for i in {1..5}; do
    if [ -L "$TARGET_LINK" ] || [ -e "$TARGET_LINK" ]; then
        break
    fi
    sleep 0.5
done

if [ -L "$TARGET_LINK" ] || [ -e "$TARGET_LINK" ]; then
    echo "----------------------------------------"
    echo "Success: All done! ${TARGET_LINK} is now available."
    echo "----------------------------------------"
else
    echo "Warning: Script finished, but ${TARGET_LINK} was not found yet."
fi
