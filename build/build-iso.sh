#!/usr/bin/env bash
# =============================================================================
# CanveraOS — Master ISO Build Script
# Run this on your Pop!_OS / Ubuntu 24.04 build machine as root.
# Usage: sudo bash build/build-iso.sh
# =============================================================================
set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()   { echo -e "${CYAN}[BUILD]${RESET} $*"; }
ok()    { echo -e "${GREEN}[  OK  ]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[ WARN ]${RESET} $*"; }
error() { echo -e "${RED}[ERROR ]${RESET} $*"; exit 1; }

# ─── Configuration ────────────────────────────────────────────────────────────
CANVERA_VERSION="${CANVERA_VERSION:-1.0.0}"
UBUNTU_CODENAME="noble"
ARCH="amd64"
BUILD_DIR="$(pwd)/build-workspace"
CHROOT_DIR="${BUILD_DIR}/chroot"
ISO_DIR="${BUILD_DIR}/iso"
OUTPUT_ISO="$(pwd)/CanveraOS-${CANVERA_VERSION}-${ARCH}.iso"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

check_deps() {
    log "Checking build dependencies..."
    local deps=(debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin \
                mtools dosfstools curl wget rsync python3 git)
    local missing=()
    for dep in "${deps[@]}"; do
        command -v "$dep" &>/dev/null || dpkg -l "$dep" &>/dev/null || missing+=("$dep")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Installing missing dependencies: ${missing[*]}"
        apt-get update -qq
        apt-get install -y "${missing[@]}"
    fi
    ok "All build dependencies satisfied."
}

[[ "$EUID" -ne 0 ]] && error "This script must be run as root. Use: sudo bash build/build-iso.sh"

echo -e "${BOLD}${BLUE}"
echo "  ██████╗ █████╗ ███╗   ██╗██╗   ██╗███████╗██████╗  █████╗  ██████╗ ███████╗"
echo " ██╔════╝██╔══██╗████╗  ██║██║   ██║██╔════╝██╔══██╗██╔══██╗██╔═══██╗██╔════╝"
echo " ██║     ███████║██╔██╗ ██║██║   ██║█████╗  ██████╔╝███████║██║   ██║███████╗"
echo " ██║     ██╔══██║██║╚██╗██║╚██╗ ██╔╝██╔══╝  ██╔══██╗██╔══██║██║   ██║╚════██║"
echo " ╚██████╗██║  ██║██║ ╚████║ ╚████╔╝ ███████╗██║  ██║██║  ██║╚██████╔╝███████║"
echo "  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝"
echo -e "${RESET}"
echo -e "${BOLD}  CanveraOS v${CANVERA_VERSION} — ISO Builder${RESET}"
echo -e "  Build started: $(date '+%Y-%m-%d %H:%M:%S')\n"

check_deps

# ─── Step 1: Prepare workspace ────────────────────────────────────────────────
log "STEP 1/8 — Preparing build workspace..."
rm -rf "${BUILD_DIR}"
mkdir -p "${CHROOT_DIR}" "${ISO_DIR}/boot/grub" "${ISO_DIR}/EFI/BOOT"
ok "Workspace ready at ${BUILD_DIR}"

# ─── Step 2: Debootstrap Ubuntu 24.04 ────────────────────────────────────────
log "STEP 2/8 — Bootstrapping Ubuntu 24.04 LTS (${UBUNTU_CODENAME})..."
debootstrap --arch="${ARCH}" --include=sudo,curl,wget,ca-certificates,gnupg,lsb-release "${UBUNTU_CODENAME}" "${CHROOT_DIR}" http://archive.ubuntu.com/ubuntu/
ok "Ubuntu 24.04 base system bootstrapped."

# ─── Step 3: Mount filesystems for chroot ─────────────────────────────────────
log "STEP 3/8 — Mounting filesystems for chroot..."
mount --bind /dev  "${CHROOT_DIR}/dev"
mount --bind /run  "${CHROOT_DIR}/run"
mount -t proc  proc   "${CHROOT_DIR}/proc"
mount -t sysfs sysfs  "${CHROOT_DIR}/sys"
mount -t devpts devpts "${CHROOT_DIR}/dev/pts"

cleanup() {
    log "Cleaning up mounts..."
    umount -lf "${CHROOT_DIR}/dev/pts" 2>/dev/null || true
    umount -lf "${CHROOT_DIR}/dev"     2>/dev/null || true
    umount -lf "${CHROOT_DIR}/run"     2>/dev/null || true
    umount -lf "${CHROOT_DIR}/proc"    2>/dev/null || true
    umount -lf "${CHROOT_DIR}/sys"     2>/dev/null || true
}
trap cleanup EXIT
ok "Filesystems mounted."

# ─── Step 4: Copy project files into chroot ───────────────────────────────────
log "STEP 4/8 — Copying CanveraOS files into chroot..."
cp -r "${PROJECT_ROOT}/config"    "${CHROOT_DIR}/canvera-config"
cp -r "${PROJECT_ROOT}/theme"     "${CHROOT_DIR}/canvera-theme"
cp -r "${PROJECT_ROOT}/scripts"   "${CHROOT_DIR}/canvera-scripts"
cp -r "${PROJECT_ROOT}/installer" "${CHROOT_DIR}/canvera-installer"
cp "${PROJECT_ROOT}/build/chroot-setup.sh"   "${CHROOT_DIR}/chroot-setup.sh"
cp "${PROJECT_ROOT}/build/codecs-install.sh" "${CHROOT_DIR}/codecs-install.sh"
cp "${PROJECT_ROOT}/build/apps-install.sh"   "${CHROOT_DIR}/apps-install.sh"
chmod +x "${CHROOT_DIR}/chroot-setup.sh" "${CHROOT_DIR}/codecs-install.sh" "${CHROOT_DIR}/apps-install.sh"
ok "Files copied."

# ─── Step 5: Run chroot setup ────────────────────────────────────────────────
log "STEP 5/8 — Running chroot setup (KDE, themes, apps, codecs)..."
cat <<EOF > "${CHROOT_DIR}/etc/apt/sources.list"
deb http://archive.ubuntu.com/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse
EOF

chroot "${CHROOT_DIR}" apt-get update

# linux-modules-extra-generic; overlay.ko Ubuntu 24.04'te bu pakette bulunur
chroot "${CHROOT_DIR}" apt-get install -y \
    casper initramfs-tools \
    linux-generic linux-modules-extra-generic \
    squashfs-tools overlayroot

chroot "${CHROOT_DIR}" /bin/bash /chroot-setup.sh
ok "Chroot setup complete."

# ─── Step 6: Fix Kernel Modules & Clean up ────────────────────────────────────
log "STEP 6/8 — Resolving Kernel Module Dependencies..."

KVER=$(ls -1 "${CHROOT_DIR}/boot"/vmlinuz-* | grep -v "\.old" | sort -V | tail -n 1 | sed 's/.*vmlinuz-//')
log "Target Kernel Detected: ${KVER}"

# overlay + overlayfs her ikisini de ekle (kernel versiyonuna göre isim farklı olabilir)
for mod in overlay overlayfs squashfs loop; do
    grep -q "^${mod}$" "${CHROOT_DIR}/etc/initramfs-tools/modules" || \
        echo "${mod}" >> "${CHROOT_DIR}/etc/initramfs-tools/modules"
done

# MODULES=most: initramfs'in çok minimal kalmasını engeller
sed -i 's/^MODULES=.*/MODULES=most/' "${CHROOT_DIR}/etc/initramfs-tools/initramfs.conf" || \
    echo "MODULES=most" >> "${CHROOT_DIR}/etc/initramfs-tools/initramfs.conf"

log "Rebuilding kernel module tree (depmod) for ${KVER}..."
chroot "${CHROOT_DIR}" depmod -a "${KVER}"

log "Generating bulletproof initramfs for ${KVER}..."
chroot "${CHROOT_DIR}" update-initramfs -c -k "${KVER}"

log "Cleaning up chroot..."
chroot "${CHROOT_DIR}" apt-get autoremove -y --purge
chroot "${CHROOT_DIR}" apt-get clean
chroot "${CHROOT_DIR}" rm -rf /tmp/* /var/tmp/* /chroot-setup.sh /codecs-install.sh /apps-install.sh /canvera-config /canvera-theme /canvera-scripts /canvera-installer
ok "Kernel fixed and chroot cleaned."

# ─── Step 6.5: Unmount virtual filesystems ────────────────────────────────────
log "STEP 6.5 — Unmounting virtual filesystems..."
umount -lf "${CHROOT_DIR}/dev/pts" 2>/dev/null || true
umount -lf "${CHROOT_DIR}/dev"     2>/dev/null || true
umount -lf "${CHROOT_DIR}/run"     2>/dev/null || true
umount -lf "${CHROOT_DIR}/proc"    2>/dev/null || true
umount -lf "${CHROOT_DIR}/sys"     2>/dev/null || true
ok "Virtual filesystems unmounted."

# ─── Step 7: Build ISO filesystem ─────────────────────────────────────────────
log "STEP 7/8 — Building ISO filesystem..."
mkdir -p "${ISO_DIR}/casper"

cp "${CHROOT_DIR}/boot/vmlinuz-${KVER}"    "${ISO_DIR}/casper/vmlinuz"
cp "${CHROOT_DIR}/boot/initrd.img-${KVER}" "${ISO_DIR}/casper/initrd"

log "Compressing filesystem (this takes time)..."
mksquashfs "${CHROOT_DIR}" "${ISO_DIR}/casper/filesystem.squashfs" \
    -comp xz -b 1M -Xdict-size 100% -e boot

# union=overlay parametresi Ubuntu 22.04+ casper'da kaldırıldı; casper overlay'i kendisi yönetir
cat <<EOF > "${ISO_DIR}/boot/grub/grub.cfg"
set timeout=5
set default=0
menuentry "Try CanveraOS" {
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}
menuentry "Install CanveraOS" {
    linux /casper/vmlinuz boot=casper quiet splash direct-install ---
    initrd /casper/initrd
}
EOF
ok "ISO filesystem built."

# ─── Step 8: Generate ISO with xorriso ────────────────────────────────────────
log "STEP 8/8 — Generating bootable ISO..."
grub-mkrescue -o "${OUTPUT_ISO}" "${ISO_DIR}"
ok "ISO Generation Complete: ${OUTPUT_ISO}"

echo -e "\n${BOLD}${GREEN}  ✔ CanveraOS-${CANVERA_VERSION}-${ARCH}.iso başarıyla oluşturuldu!${RESET}"
echo -e "  Çıktı: ${OUTPUT_ISO}\n"
