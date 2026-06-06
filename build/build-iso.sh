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

# IMPORTANT: Keep --include MINIMAL here.
# Packages like casper, linux-image-generic, laptop-detect, os-prober
# need a fully configured chroot with /dev, /proc, /sys mounted to run
# their post-install scripts. They are installed in chroot-setup.sh (Step 5).
# Only include packages that safely configure in a minimal bootstrap context.
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
cp -r "${PROJECT_ROOT}/config"  "${CHROOT_DIR}/canvera-config"
cp -r "${PROJECT_ROOT}/theme"   "${CHROOT_DIR}/canvera-theme"
cp -r "${PROJECT_ROOT}/scripts" "${CHROOT_DIR}/canvera-scripts"
cp "${PROJECT_ROOT}/build/chroot-setup.sh"  "${CHROOT_DIR}/chroot-setup.sh"
cp "${PROJECT_ROOT}/build/codecs-install.sh" "${CHROOT_DIR}/codecs-install.sh"
cp "${PROJECT_ROOT}/build/apps-install.sh"   "${CHROOT_DIR}/apps-install.sh"
chmod +x "${CHROOT_DIR}/chroot-setup.sh" \
         "${CHROOT_DIR}/codecs-install.sh" \
         "${CHROOT_DIR}/apps-install.sh"
ok "Files copied."

# ─── Step 5: Run chroot setup ─────────────────────────────────────────────────
log "STEP 5/8 — Running chroot setup (KDE, themes, apps, codecs)..."
log "  This will take 30–60 minutes depending on internet speed."
chroot "${CHROOT_DIR}" /bin/bash /chroot-setup.sh
ok "Chroot setup complete."

# ─── Step 6: Clean up chroot ──────────────────────────────────────────────────
log "STEP 6/8 — Cleaning up chroot..."
chroot "${CHROOT_DIR}" apt-get autoremove -y --purge
chroot "${CHROOT_DIR}" apt-get clean
chroot "${CHROOT_DIR}" rm -rf /tmp/* /var/tmp/*
chroot "${CHROOT_DIR}" rm -f /chroot-setup.sh /codecs-install.sh /apps-install.sh
chroot "${CHROOT_DIR}" rm -rf /canvera-config /canvera-theme /canvera-scripts
ok "Chroot cleaned."

# ─── Step 7: Pack squashfs + build ISO ───────────────────────────────────────
log "STEP 7/8 — Packing filesystem and building ISO..."
bash "${PROJECT_ROOT}/build/squashfs-pack.sh" \
    "${CHROOT_DIR}" "${ISO_DIR}" "${OUTPUT_ISO}" "${PROJECT_ROOT}"
ok "ISO built."

# ─── Step 8: Verify ───────────────────────────────────────────────────────────
log "STEP 8/8 — Verifying output..."
if [[ -f "${OUTPUT_ISO}" ]]; then
    ISO_SIZE=$(du -sh "${OUTPUT_ISO}" | cut -f1)
    ISO_HASH=$(sha256sum "${OUTPUT_ISO}" | cut -d' ' -f1)
    echo -e "\n${GREEN}${BOLD}════════════════════════════════════════${RESET}"
    echo -e "${GREEN}${BOLD}  CanveraOS ISO build SUCCESSFUL!${RESET}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
    echo -e "  File:    ${OUTPUT_ISO}"
    echo -e "  Size:    ${ISO_SIZE}"
    echo -e "  SHA256:  ${ISO_HASH}"
    echo -e "  Built:   $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "\n  Flash with: sudo dd if=${OUTPUT_ISO} of=/dev/sdX bs=4M status=progress"
    echo -e "  Or use Balena Etcher for a GUI experience.\n"
else
    error "ISO file not found! Build may have failed. Check logs above."
fi
