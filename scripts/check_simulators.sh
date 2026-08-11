#!/bin/bash
# Checks every simulator's UDID against its backing folder on disk.
# Reports which ones are healthy vs broken (missing files) without
# having to manually boot each one.

DEVICES_DIR="$HOME/Library/Developer/CoreSimulator/Devices"

echo "Checking simulators..."
echo ""

xcrun simctl list devices | grep -E '\(' | while read -r line; do
    # Extract name and UDID from lines like:
    #   iPhone 15 Pro (7B98708E-...) (Shutdown)
    name=$(echo "$line" | sed -E 's/^ *(.*) \([A-F0-9-]+\) \(.*\)$/\1/')
    udid=$(echo "$line" | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}')

    if [ -z "$udid" ]; then
        continue
    fi

    if [ -d "$DEVICES_DIR/$udid" ]; then
        # Folder exists - check it actually has content (device.plist is the key file)
        if [ -f "$DEVICES_DIR/$udid/device.plist" ]; then
            echo "OK      $name  ($udid)"
        else
            echo "BROKEN  $name  ($udid)  <- folder exists but device.plist missing"
        fi
    else
        echo "BROKEN  $name  ($udid)  <- no folder on disk"
    fi
done

echo ""
echo "Done. Any line starting with BROKEN needs to be deleted."
echo "To delete a specific broken one:  xcrun simctl delete <UDID>"
echo "To delete ALL broken ones at once: xcrun simctl delete unavailable"
