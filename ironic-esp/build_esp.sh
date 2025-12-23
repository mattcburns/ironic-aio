#!/bin/bash
set -e

# Install dependencies (quietly)
dnf install -y dosfstools mtools shim-x64 grub2-efi-x64

OUTPUT="/output/esp.img"
# Paths for CentOS 9 Stream packages
SRC_SHIM="/boot/efi/EFI/centos/shimx64.efi"
SRC_GRUB="/boot/efi/EFI/centos/grubx64.efi"

echo "Building ESP image..."
dd if=/dev/zero of=$OUTPUT bs=1M count=16 status=none
mkfs.msdos -F 12 -n 'ESP_IMAGE' $OUTPUT > /dev/null
mmd -i $OUTPUT ::EFI
mmd -i $OUTPUT ::EFI/BOOT
mcopy -i $OUTPUT $SRC_SHIM ::EFI/BOOT/BOOTX64.EFI
mcopy -i $OUTPUT $SRC_GRUB ::EFI/BOOT/grubx64.efi

echo "Done. Created $OUTPUT"
