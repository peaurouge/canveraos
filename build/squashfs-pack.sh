#!/usr/bin/env bash
# =============================================================================
# CanveraOS — SquashFS Pack + ISO Creation Script
# Compresses the chroot into a squashfs filesystem, sets up GRUB for BIOS
# and UEFI boot, and creates the final bootable ISO with Calamares installer.
# =============================================================================
set -euo pipefail

CHROOT_DIR="$1"
ISO_DIR="$2"
OUTPUT_ISO="$3"
PROJECT_ROOT="$4"

log()  { echo -e "\033[0;36m[ ISO ]\033[0m $*"; }
ok()   { echo -e "\033[0;32m[  OK  ]\033[0m $*"; }
warn() { echo -e "\033[1;33m[ WARN ]\033[0m $*"; }

# ─── Copy kernel and initrd ───────────────────────────────────────────────────
log "Copying kernel and initramfs..."
mkdir -p "${ISO_DIR}/casper"
cp "${CHROOT_DIR}/boot/vmlinuz"     "${ISO_DIR}/casper/vmlinuz"
cp "${CHROOT_DIR}/boot/initrd.img"  "${ISO_DIR}/casper/initrd"
ok "Kernel and initrd copied."

# ─── Pack filesystem as SquashFS ──────────────────────────────────────────────
log "Packing filesystem with SquashFS (this takes 10–20 minutes)..."
log "  Compressing ~8GB of data with xz compression..."
mksquashfs \
    "${CHROOT_DIR}" \
    "${ISO_DIR}/casper/filesystem.squashfs" \
    -comp xz \
    -Xbcj x86 \
    -Xdict-size 1M \
    -noappend \
    -wildcards \
    -ef /dev/stdin << 'EXCLUDES'
proc/*
sys/*
dev/*
run/*
tmp/*
var/cache/apt/archives/*.deb
boot/grub
home/*/.cache
EXCLUDES

FSSIZE=$(du -sx --block-size=1 "${CHROOT_DIR}" | cut -f1)
echo "${FSSIZE}" > "${ISO_DIR}/casper/filesystem.size"
ok "SquashFS created ($(du -sh "${ISO_DIR}/casper/filesystem.squashfs" | cut -f1))."

# ─── Copy Calamares installer config ─────────────────────────────────────────
log "Copying Calamares installer configuration..."
cp -r "${PROJECT_ROOT}/installer/calamares" "${ISO_DIR}/calamares-config"
ok "Calamares config copied."

# ─── Set up GRUB bootloader ───────────────────────────────────────────────────
log "Configuring GRUB bootloader (BIOS + UEFI)..."
mkdir -p "${ISO_DIR}/boot/grub"
mkdir -p "${ISO_DIR}/EFI/BOOT"

cat > "${ISO_DIR}/boot/grub/grub.cfg" << 'EOF'
# CanveraOS — GRUB Boot Configuration
set default=0
set timeout=5

# Theme
set theme=/boot/grub/canvera-theme/theme.txt
load_env
if [ -s $prefix/grubenv ]; then
    load_env
fi

# Set locale
set locale_dir=$prefix/locale
set lang=en_US

menuentry "Install CanveraOS" --class canvera --class gnu-linux --class os {
    linux   /casper/vmlinuz \
            boot=casper \
            only-ubiquity \
            quiet \
            splash \
            console=tty1 \
            loglevel=3 \
            systemd.show_status=false \
            rd.udev.log_level=3 \
            CANVERA_INSTALL=1
    initrd  /casper/initrd
}

menuentry "CanveraOS Installation (Safe Graphics)" --class canvera {
    linux   /casper/vmlinuz \
            boot=casper \
            only-ubiquity \
            quiet \
            splash \
            nomodeset \
            xforcevesa \
            CANVERA_INSTALL=1
    initrd  /casper/initrd
}

menuentry "Memory Test (memtest86+)" {
    linux   /boot/memtest86+/memtest86+.bin
}
EOF

# ─── Create GRUB theme ────────────────────────────────────────────────────────
mkdir -p "${ISO_DIR}/boot/grub/canvera-theme"
cat > "${ISO_DIR}/boot/grub/canvera-theme/theme.txt" << 'EOF'
# CanveraOS GRUB Theme
desktop-color: "#0d0d1a"
title-color: "#ffffff"
title-font: "Inter Regular 16"
message-color: "#ccccdd"
message-bg-color: "#1a1a2e"
terminal-box: "terminal_box*.png"
terminal-font: "Inter Regular 13"

+ boot_menu {
    left = 50%-300
    top = 50%-80
    width = 600
    height = 160
    item_font = "Inter Regular 14"
    item_color = "#ccccdd"
    selected_item_color = "#ffffff"
    selected_item_pixmap_style = "select_*.png"
    item_height = 36
    item_padding = 16
    item_spacing = 4
    scroll_tab_color = "#4a4a6a"
}

+ label {
    top = 50%+100
    left = 50%-200
    width = 400
    align = center
    id = "__timeout__"
    text = "Install will begin in %d seconds"
    color = "#8888aa"
    font = "Inter Regular 12"
}
EOF

# Create minimal GRUB EFI image
grub-mkstandalone \
    --format=x86_64-efi \
    --output="${ISO_DIR}/EFI/BOOT/BOOTx64.EFI" \
    --modules="part_gpt part_msdos fat iso9660 normal boot linux echo configfile search_label search_fs_file search ls reboot halt" \
    "boot/grub/grub.cfg=${ISO_DIR}/boot/grub/grub.cfg"

# Create BIOS boot image
grub-mkstandalone \
    --format=i386-pc \
    --output="${ISO_DIR}/boot/grub/core.img" \
    --install-modules="linux normal iso9660 biosdisk memdisk search tar ls" \
    --modules="linux normal iso9660 biosdisk search" \
    "boot/grub/grub.cfg=${ISO_DIR}/boot/grub/grub.cfg"

cat /usr/lib/grub/i386-pc/cdboot.img "${ISO_DIR}/boot/grub/core.img" > \
    "${ISO_DIR}/boot/grub/bios.img"

ok "GRUB configured for BIOS and UEFI."

# ─── Create EFI system partition image ───────────────────────────────────────
log "Creating EFI system partition image..."
dd if=/dev/zero of="${ISO_DIR}/boot/grub/efi.img" bs=1M count=10 status=none
mkfs.vfat "${ISO_DIR}/boot/grub/efi.img"
mmd -i "${ISO_DIR}/boot/grub/efi.img" ::EFI
mmd -i "${ISO_DIR}/boot/grub/efi.img" ::EFI/BOOT
mcopy -i "${ISO_DIR}/boot/grub/efi.img" \
    "${ISO_DIR}/EFI/BOOT/BOOTx64.EFI" ::EFI/BOOT/
ok "EFI partition image created."

# ─── Write filesystem manifest ────────────────────────────────────────────────
log "Writing filesystem manifest..."
chroot "${CHROOT_DIR}" dpkg-query -W --showformat='${Package} ${Version}\n' > \
    "${ISO_DIR}/casper/filesystem.manifest"
cp "${ISO_DIR}/casper/filesystem.manifest" \
   "${ISO_DIR}/casper/filesystem.manifest-desktop"
ok "Manifest written."

# ─── Copy installer assets ───────────────────────────────────────────────────
log "Copying installer branding and assets..."
mkdir -p "${ISO_DIR}/.disk"
echo "CanveraOS 1.0.0 \"Aurora\" - Release amd64" > "${ISO_DIR}/.disk/info"
echo "http://canveraos.io" > "${ISO_DIR}/.disk/release_notes_url"
touch "${ISO_DIR}/.disk/base_installable"

# ─── Build the ISO ────────────────────────────────────────────────────────────
log "Building bootable ISO with xorriso..."
xorriso \
    -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "CANVERAOS_1_0" \
    -appid "CanveraOS 1.0.0" \
    -publisher "CanveraOS Project" \
    -preparer "CanveraOS Build System" \
    -eltorito-boot boot/grub/bios.img \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    --eltorito-catalog boot/grub/boot.catalog \
    --grub2-boot-info \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -append_partition 2 0xef "${ISO_DIR}/boot/grub/efi.img" \
    -output "${OUTPUT_ISO}" \
    -graft-points \
    "${ISO_DIR}" \
    /boot/grub/bios.img="${ISO_DIR}/boot/grub/bios.img"

ok "ISO created: ${OUTPUT_ISO}"
ISO_SIZE=$(du -sh "${OUTPUT_ISO}" | cut -f1)
log "ISO size: ${ISO_SIZE}"

# ─── Generate checksums ───────────────────────────────────────────────────────
log "Generating checksums..."
sha256sum "${OUTPUT_ISO}" > "${OUTPUT_ISO}.sha256"
md5sum    "${OUTPUT_ISO}" > "${OUTPUT_ISO}.md5"
ok "Checksums saved."
