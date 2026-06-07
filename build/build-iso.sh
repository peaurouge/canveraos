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
CANVERA_VERSION="${CANVERA_VERSION:-1.0.0}"   # Read from env var (set by GitHub Actions) or default
UBUNTU_CODENAME="noble"          # Ubuntu 24.04 LTS codename
ARCH="amd64"
BUILD_DIR="$(pwd)/build-workspace"
CHROOT_DIR="${BUILD_DIR}/chroot"
ISO_DIR="${BUILD_DIR}/iso"
OUTPUT_ISO="$(pwd)/CanveraOS-${CANVERA_VERSION}-${ARCH}.iso"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# ─── Dependency check ─────────────────────────────────────────────────────────
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

# ─── Root check ───────────────────────────────────────────────────────────────
# In GitHub Actions the runner uses passwordless sudo and may not be EUID 0.
# When called via 'sudo bash build/build-iso.sh' this check passes correctly.
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
log "  This downloads ~200MB. Please wait..."

debootstrap \
    --arch="${ARCH}" \
    --include=sudo,curl,wget,ca-certificates,gnupg,lsb-release \
    "${UBUNTU_CODENAME}" \
    "${CHROOT_DIR}" \
    http://archive.ubuntu.com/ubuntu/
ok "Ubuntu 24.04 base system bootstrapped."

# ─── Step 3: Mount filesystems for chroot ─────────────────────────────────────
log "STEP 3/8 — Mounting filesystems for chroot..."
mount --bind /dev  "${CHROOT_DIR}/dev"
mount --bind /run  "${CHROOT_DIR}/run"
mount -t proc  proc   "${CHROOT_DIR}/proc"
mount -t sysfs sysfs  "${CHROOT_DIR}/sys"
mount -t devpts devpts "${CHROOT_DIR}/dev/pts"

# Cleanup trap — always unmount on exit
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
cp "${PROJECT_ROOT}/build/chroot-setup.sh"  "${CHROOT_DIR}/chroot-setup.sh"
cp "${PROJECT_ROOT}/build/codecs-install.sh" "${CHROOT_DIR}/codecs-install.sh"
cp "${PROJECT_ROOT}/build/apps-install.sh"   "${CHROOT_DIR}/apps-install.sh"
chmod +x "${CHROOT_DIR}/chroot-setup.sh" \
         "${CHROOT_DIR}/codecs-install.sh" \
         "${CHROOT_DIR}/apps-install.sh"
ok "Files copied."

# ─── Step 5: Run chroot setup ────────────────────────────────────────────────
log "Installing LIVE boot infrastructure inside chroot..."

# Universe ve Multiverse depolarını aktif ediyoruz
cat <<EOF > "${CHROOT_DIR}/etc/apt/sources.list"
deb http://archive.ubuntu.com/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse
EOF

chroot "${CHROOT_DIR}" apt-get update

chroot "${CHROOT_DIR}" apt-get install -y \
    casper \
    live-boot \
    live-config \
    initramfs-tools \
    linux-image-generic \
    squashfs-tools

ok "Live boot packages installed."

log "Enabling overlay support..."
echo overlay >> "${CHROOT_DIR}/etc/initramfs-tools/modules"
ok "Overlay module enabled."

log "STEP 5/8 — Running chroot setup (KDE, themes, apps, codecs)..."
log "  This will take 30–60 minutes depending on internet speed."
chroot "${CHROOT_DIR}" /bin/bash /chroot-setup.sh
ok "Chroot setup complete."

log "Rebuilding initramfs with overlay support..."
chroot "${CHROOT_DIR}" update-initramfs -u -k all
ok "Initramfs rebuilt."

# ─── Step 6: Clean up chroot ──────────────────────────────────────────────────
log "STEP 6/8 — Cleaning up chroot..."
chroot "${CHROOT_DIR}" apt-get autoremove -y --purge
chroot "${CHROOT_DIR}" apt-get clean
chroot "${CHROOT_DIR}" rm -rf /tmp/* /var/tmp/*
chroot "${CHROOT_DIR}" rm -f /chroot-setup.sh /codecs-install.sh /apps-install.sh
chroot "${CHROOT_DIR}" rm -rf /canvera-config /canvera-theme /canvera-scripts /canvera-installer
ok "Chroot cleanup complete."

# ─── Step 7: Build ISO filesystem ─────────────────────────────────────────────
log "STEP 7/8 — Building ISO filesystem..."
mkdir -p "${ISO_DIR}/casper"

# Copy kernel and initramfs
cp "${CHROOT_DIR}/boot/vmlinuz" "${ISO_DIR}/casper/vmlinuz"
cp "${CHROOT_DIR}/boot/initrd.img" "${ISO_DIR}/casper/initrd"

# Squash the chroot
log "Compressing filesystem (this takes time)..."
mksquashfs "${CHROOT_DIR}" "${ISO_DIR}/casper/filesystem.squashfs" -comp xz -b 1M -Xdict-size 100% -e boot

# Create GRUB config (Direct Install option included)
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
