#!/usr/bin/env bash
# =============================================================================
# CanveraOS — SquashFS Pack + ISO Creation Script
# Compresses the chroot into a squashfs filesystem, sets up GRUB for UEFI
# boot, and creates the final bootable ISO with Calamares installer.
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
# Find the correct kernel and initrd paths (names may vary)
VMLINUZ=$(ls "${CHROOT_DIR}/boot/vmlinuz-"* 2>/dev/null | sort -V | tail -1 || true)
INITRD=$(ls "${CHROOT_DIR}/boot/initrd.img-"* 2>/dev/null | sort -V | tail -1 || true)

# Fall back to symlinks if version-named files not found
[[ -z "$VMLINUZ" ]] && VMLINUZ="${CHROOT_DIR}/boot/vmlinuz"
[[ -z "$INITRD"  ]] && INITRD="${CHROOT_DIR}/boot/initrd.img"

cp "$VMLINUZ" "${ISO_DIR}/casper/vmlinuz"
cp "$INITRD"  "${ISO_DIR}/casper/initrd"
ok "Kernel and initrd copied."

# ─── Pack filesystem as SquashFS ──────────────────────────────────────────────
log "Packing filesystem with SquashFS (this takes 10-20 minutes)..."
log "  Compressing ~8GB of data with xz compression..."

# Write excludes file (avoids heredoc)
EXCLUDES_FILE=$(mktemp)
printf 'proc/*\nsys/*\ndev/*\nrun/*\ntmp/*\nvar/cache/apt/archives/*.deb\nboot/grub\nhome/*/.cache\n' > "$EXCLUDES_FILE"

# -Xdict-size must be <= block size (default block=128K, so use 50% = 64K max)
# Using gzip instead of xz for reliability; still produces good compression
mksquashfs \
    "${CHROOT_DIR}" \
    "${ISO_DIR}/casper/filesystem.squashfs" \
    -comp xz \
    -b 1048576 \
    -Xdict-size 1048576 \
    -noappend \
    -wildcards \
    -ef "$EXCLUDES_FILE"

rm -f "$EXCLUDES_FILE"

FSSIZE=$(du -sx --block-size=1 "${CHROOT_DIR}" | cut -f1)
echo "${FSSIZE}" > "${ISO_DIR}/casper/filesystem.size"
ok "SquashFS created ($(du -sh "${ISO_DIR}/casper/filesystem.squashfs" | cut -f1))."

# ─── Copy Calamares installer config ─────────────────────────────────────────
log "Copying Calamares installer configuration..."
if [[ -d "${PROJECT_ROOT}/installer/calamares" ]]; then
    cp -r "${PROJECT_ROOT}/installer/calamares" "${ISO_DIR}/calamares-config"
    ok "Calamares config copied."
else
    warn "Calamares config not found at ${PROJECT_ROOT}/installer/calamares — skipping."
fi

# ─── Set up GRUB bootloader ───────────────────────────────────────────────────
log "Configuring GRUB bootloader (UEFI)..."
mkdir -p "${ISO_DIR}/boot/grub"
mkdir -p "${ISO_DIR}/EFI/BOOT"

# GRUB config (using printf to avoid heredoc issues)
printf '# CanveraOS GRUB Boot Configuration\nset default=0\nset timeout=5\n\nmenuentry "Install CanveraOS" --class canvera --class gnu-linux --class os {\n    linux   /casper/vmlinuz boot=casper only-ubiquity quiet splash console=tty1 loglevel=3 systemd.show_status=false\n    initrd  /casper/initrd\n}\n\nmenuentry "CanveraOS (Safe Graphics)" --class canvera {\n    linux   /casper/vmlinuz boot=casper only-ubiquity quiet splash nomodeset\n    initrd  /casper/initrd\n}\n\nmenuentry "Try CanveraOS without installing" --class canvera {\n    linux   /casper/vmlinuz boot=casper quiet splash\n    initrd  /casper/initrd\n}\n' \
    > "${ISO_DIR}/boot/grub/grub.cfg"

# Create GRUB EFI image
grub-mkstandalone \
    --format=x86_64-efi \
    --output="${ISO_DIR}/EFI/BOOT/BOOTx64.EFI" \
    --modules="part_gpt part_msdos fat iso9660 normal boot linux echo configfile search_label search_fs_file search ls reboot halt" \
    "boot/grub/grub.cfg=${ISO_DIR}/boot/grub/grub.cfg"

# Create BIOS boot image (for legacy BIOS fallback)
grub-mkstandalone \
    --format=i386-pc \
    --output="${ISO_DIR}/boot/grub/core.img" \
    --install-modules="linux normal iso9660 biosdisk memdisk search tar ls" \
    --modules="linux normal iso9660 biosdisk search" \
    "boot/grub/grub.cfg=${ISO_DIR}/boot/grub/grub.cfg" 2>/dev/null || \
    warn "BIOS GRUB image creation failed — UEFI boot only."

if [[ -f /usr/lib/grub/i386-pc/cdboot.img && -f "${ISO_DIR}/boot/grub/core.img" ]]; then
    cat /usr/lib/grub/i386-pc/cdboot.img "${ISO_DIR}/boot/grub/core.img" > \
        "${ISO_DIR}/boot/grub/bios.img"
fi

ok "GRUB configured."

# ─── Create EFI system partition image ───────────────────────────────────────
log "Creating EFI system partition image..."
dd if=/dev/zero of="${ISO_DIR}/boot/grub/efi.img" bs=1M count=10 status=none
mkfs.vfat "${ISO_DIR}/boot/grub/efi.img"
mmd  -i "${ISO_DIR}/boot/grub/efi.img" ::EFI
mmd  -i "${ISO_DIR}/boot/grub/efi.img" ::EFI/BOOT
mcopy -i "${ISO_DIR}/boot/grub/efi.img" \
    "${ISO_DIR}/EFI/BOOT/BOOTx64.EFI" ::EFI/BOOT/
ok "EFI partition image created."

# ─── Write filesystem manifest ────────────────────────────────────────────────
log "Writing filesystem manifest..."
chroot "${CHROOT_DIR}" dpkg-query -W --showformat='${Package} ${Version}\n' > \
    "${ISO_DIR}/casper/filesystem.manifest" 2>/dev/null || true
cp "${ISO_DIR}/casper/filesystem.manifest" \
   "${ISO_DIR}/casper/filesystem.manifest-desktop" 2>/dev/null || true
ok "Manifest written."

# ─── Copy installer assets ───────────────────────────────────────────────────
log "Copying installer branding and assets..."
mkdir -p "${ISO_DIR}/.disk"
echo 'CanveraOS 1.0.0 "Aurora" - Release amd64' > "${ISO_DIR}/.disk/info"
echo "http://canveraos.io"                        > "${ISO_DIR}/.disk/release_notes_url"
touch "${ISO_DIR}/.disk/base_installable"

# ─── Build the ISO ────────────────────────────────────────────────────────────
log "Building bootable ISO with xorriso..."

# Build ISO command — adapt based on whether BIOS image exists
if [[ -f "${ISO_DIR}/boot/grub/bios.img" ]]; then
    # Full BIOS + UEFI hybrid ISO
    xorriso \
        -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "CANVERAOS_1_0" \
        -appid "CanveraOS 1.0.0" \
        -publisher "CanveraOS Project" \
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
        "${ISO_DIR}" ; XORRISO_RC=$?
else
    # UEFI-only ISO
    xorriso \
        -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "CANVERAOS_1_0" \
        -appid "CanveraOS 1.0.0" \
        -publisher "CanveraOS Project" \
        -eltorito-alt-boot \
        -e boot/grub/efi.img \
        -no-emul-boot \
        -append_partition 2 0xef "${ISO_DIR}/boot/grub/efi.img" \
        -output "${OUTPUT_ISO}" \
        -graft-points \
        "${ISO_DIR}" ; XORRISO_RC=$?
fi

# xorriso exit code 32 = MISHAP (non-fatal warning, ISO still created OK)
# Only fail on other non-zero exit codes
if [[ $XORRISO_RC -ne 0 && $XORRISO_RC -ne 32 ]]; then
    echo "ERROR: xorriso failed with exit code $XORRISO_RC"
    exit $XORRISO_RC
elif [[ $XORRISO_RC -eq 32 ]]; then
    warn "xorriso MISHAP (non-fatal) — ISO created successfully despite warning."
fi

# Verify the ISO was actually created
if [[ ! -f "${OUTPUT_ISO}" ]]; then
    echo "ERROR: ISO file not found at ${OUTPUT_ISO}"
    exit 1
fi

ok "ISO created: ${OUTPUT_ISO}"
ISO_SIZE=$(du -sh "${OUTPUT_ISO}" | cut -f1)
log "ISO size: ${ISO_SIZE}"

# ─── Generate checksums ───────────────────────────────────────────────────────
log "Generating checksums..."
sha256sum "${OUTPUT_ISO}" > "${OUTPUT_ISO}.sha256"
md5sum    "${OUTPUT_ISO}" > "${OUTPUT_ISO}.md5"
ok "Checksums saved."
