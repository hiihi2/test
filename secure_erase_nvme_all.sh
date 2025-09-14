#!/bin/bash

set -e

echo "=== Securely erasing all NVMe SSDs ==="
echo "Listing NVMe disks..."

# Find all NVMe disks
NVME_DISKS=$(lsblk -dpno NAME | grep -E '/dev/nvme[0-9]+n1$')

for DISK in $NVME_DISKS; do
    echo "Processing $DISK..."

    # Unmount all partitions
    PARTITIONS=$(lsblk -ln $DISK | awk '{print $1}' | grep -v "^$DISK" | sed "s|^|/dev/|")
    for PART in $PARTITIONS; do
        if mount | grep -q "^$PART "; then
            echo "Unmounting $PART..."
            sudo umount $PART || true
        fi
    done

    # Turn off swap on disk
    if grep -q "$DISK" /proc/swaps; then
        echo "Turning off swap on $DISK..."
        sudo swapoff $DISK || true
    fi

    # Deactivate LVM volumes if present
    if sudo pvs | grep -q "$DISK"; then
        LVM_VOLS=$(sudo lvs --noheadings -o lv_name,vg_name | awk '{print $2"/"$1}')
        for LV in $LVM_VOLS; do
            echo "Deactivating LVM volume $LV..."
            sudo lvchange -an $LV || true
        done
    fi

    # Perform secure erase
    echo "Running secure erase on $DISK..."
    sudo nvme format $DISK --ses=1 --force

    echo "$DISK erased."
done

echo "=== All NVMe disks have been securely erased! ==="