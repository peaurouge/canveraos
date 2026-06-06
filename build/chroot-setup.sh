#!/usr/bin/env bash
# =============================================================================
# CanveraOS — Chroot Setup Script
# Runs INSIDE the chroot environment. Sets up KDE Plasma, themes, all apps.
# Called automatically by build-iso.sh — do not run directly.
# =============================================================================
set -euo pipefail

log()  { echo -e "\033[0;36m[CHROOT]\033[0m $*"; }
ok()   { echo -e "\033[0;32m[  OK  ]\033[0m $*"; }
warn() { echo -e "\033[1;33m[ WARN ]\033[0m $*"; }

export DEBIAN_FRONTEND=noninteractive
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# ─── Configure apt ────────────────────────────────────────────────────────────
log "Configuring apt repositories..."
truncate -s 0 /etc/apt/sources.list
echo "deb http://archive.ubuntu.com/ubuntu/ noble main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://archive.ubuntu.com/ubuntu/ noble-updates main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://archive.ubuntu.com/ubuntu/ noble-security main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://archive.ubuntu.com/ubuntu/ noble-backports main restricted universe multiverse" >> /etc/apt/sources.list
apt-get update -qq
ok "APT configured."

# ─── PRE-CONFIGURE initramfs-tools BEFORE any kernel install ──────────────────
# CRITICAL ORDERING: initramfs-tools config MUST exist BEFORE linux-image-generic
# is installed. Installing linux-image-generic triggers update-initramfs via dpkg.
# If MODULES=dep is set (or defaulted), update-initramfs tries to detect the root
# block device. In a chroot there IS no root device → "failed to determine device
# for /" → dpkg fails → entire build crashes with exit code 100.
# Setting MODULES=most BEFORE the kernel install prevents this completely.
log "Pre-configuring initramfs-tools (MODULES=most for chroot compatibility)..."
mkdir -p /etc/initramfs-tools/conf.d
printf '# CanveraOS initramfs configuration\n# MODULES=most: works in chroot + supports all hardware on live boot\nMODULES=most\nCOMPRESS=gzip\nBUSYBOX=auto\n' \
    > /etc/initramfs-tools/conf.d/canvera.conf
ok "initramfs-tools pre-configured (MODULES=most)."

# ─── Install essential base packages ──────────────────────────────────────────
log "Installing base system packages..."
apt-get install -y --no-install-recommends \
    ubuntu-minimal \
    ubuntu-standard \
    linux-image-generic \
    linux-headers-generic \
    linux-firmware \
    casper \
    laptop-detect \
    os-prober \
    grub-efi-amd64 \
    grub-efi-amd64-signed \
    shim-signed \
    locales \
    language-pack-en \
    tzdata \
    ca-certificates \
    curl \
    wget \
    git \
    gpg \
    software-properties-common \
    apt-transport-https \
    network-manager \
    network-manager-gnome \
    net-tools \
    wireless-tools \
    wpasupplicant \
    openssh-client \
    ufw \
    apparmor \
    apparmor-utils \
    apparmor-profiles \
    flatpak \
    xdg-desktop-portal \
    xdg-utils \
    policykit-1 \
    libxss1 \
    plymouth \
    plymouth-themes

# Configure locale
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
ok "Base packages installed."

# ─── CRITICAL: Force overlay module into initramfs for casper live boot ─────────────
# The error "(initramfs) /cow format specified as 'overlay' and no support found"
# means the overlay kernel module is NOT inside the initramfs cpio archive.
# casper tries: modprobe overlay -> if it fails, it panics with that message.
#
# ROOT CAUSES of previous failures:
# 1. 'aufs' in modules list -> Ubuntu 24.04 has NO aufs module -> update-initramfs
#    exits non-zero -> hidden by 2>/dev/null -> old/broken initramfs is kept
# 2. COMPRESS=lz4 -> lz4 not installed -> same silent failure
# 3. Using -u (update) instead of -c (create) -> might skip rebuild
#
# THE ONLY RELIABLE FIX: an initramfs HOOK using copy_modules_dir
# This is the Ubuntu-standard method used by casper/overlayroot packages.

log "Creating initramfs hook to force overlay module into initramfs..."
mkdir -p /etc/initramfs-tools/hooks
mkdir -p /etc/initramfs-tools/conf.d

# The hook is executed by update-initramfs when building the initramfs.
# copy_modules_dir physically copies the module files into the cpio archive.
# This works regardless of the MODULES= setting.
cat > /etc/initramfs-tools/hooks/zz-canvera-live-modules << 'HOOK_EOF'
#!/bin/sh
# =============================================================================
# CanveraOS initramfs hook — forces live-boot modules into the initramfs.
# Named 'zz-' so it runs LAST (after all other hooks).
#
# This fixes: "(initramfs) /cow format specified as 'overlay' and no support found"
# =============================================================================
PREREQ=""
prereqs() { echo "$PREREQ"; }
case $1 in prereqs) prereqs; exit 0 ;; esac

. /usr/share/initramfs-tools/hook-functions

# overlay: CRITICAL — casper uses this for copy-on-write layer on live boot
# Without this module in the initramfs, casper panics immediately at boot.
copy_modules_dir kernel/fs/overlay || manual_add_modules overlay

# squashfs: reads the compressed root filesystem from the ISO
copy_modules_dir kernel/fs/squashfs || manual_add_modules squashfs

# loop: mounts ISO and disk images as block devices
manual_add_modules loop

# iso9660: reads ISO 9660 filesystem (the USB/CD format)
copy_modules_dir kernel/fs/isofs || manual_add_modules isofs

# Ensure these are loaded early during boot (added to conf/modules in the initramfs)
for mod in overlay squashfs loop; do
    echo "$mod" >> "${DESTDIR}/conf/modules" 2>/dev/null || true
done

exit 0
HOOK_EOF
chmod 755 /etc/initramfs-tools/hooks/zz-canvera-live-modules

# Belt-and-suspenders: also add to the modules list
# NOTE: do NOT add 'aufs' — Ubuntu 24.04 kernel does NOT ship aufs.
mkdir -p /etc/initramfs-tools
for MOD in overlay squashfs loop; do
    grep -q "^${MOD}$" /etc/initramfs-tools/modules 2>/dev/null || \
        echo "${MOD}" >> /etc/initramfs-tools/modules
done

# initramfs conf.d/canvera.conf already written at top of script (before kernel install)
# to prevent "failed to determine device for /" during dpkg triggers.

ok "Initramfs hook and module config created."

# Re-ensure universe is available (ubuntu-minimal can reset apt sources)
log "Re-enabling universe repository for KDE packages..."
add-apt-repository -y universe
apt-get update -qq

# ─── Install KDE Plasma 6 ─────────────────────────────────────────────────────
log "Installing KDE Plasma desktop environment..."
# Core KDE Plasma (all exist in Ubuntu 24.04 Noble)
apt-get install -y \
    kde-plasma-desktop \
    plasma-workspace \
    plasma-workspace-wayland \
    kwin-x11 \
    kwin-wayland \
    sddm \
    sddm-theme-breeze \
    plasma-nm \
    plasma-pa \
    powerdevil \
    bluedevil \
    kscreen \
    ark \
    okular \
    konsole \
    kate \
    gwenview \
    kcalc \
    plasma-systemmonitor \
    xdg-desktop-portal-kde \
    plank

# Optional KDE packages (may not be available in all Noble variants)
apt-get install -y kde-config-sddm 2>/dev/null || true
apt-get install -y plasma-disks 2>/dev/null || true
apt-get install -y plasma-vault 2>/dev/null || true
apt-get install -y kde-spectacle 2>/dev/null || apt-get install -y spectacle 2>/dev/null || true
apt-get install -y kfind 2>/dev/null || true
apt-get install -y filelight 2>/dev/null || true
apt-get install -y kde-config-screenlocker 2>/dev/null || true
apt-get install -y kde-config-gtk-style kde-config-gtk-style-preview 2>/dev/null || true
apt-get install -y plasma-widgets-addons 2>/dev/null || true
apt-get install -y plasma-browser-integration 2>/dev/null || true
apt-get install -y dragonplayer 2>/dev/null || true
# Kvantum theming engine (correct package names for Noble)
apt-get install -y qt5ct qt6ct 2>/dev/null || true
apt-get install -y qt5-style-kvantum qt5-style-kvantum-l10n 2>/dev/null || true
# GTK Global Menu support (shows GTK app menus in KDE top bar, like macOS)
apt-get install -y appmenu-gtk3-module 2>/dev/null || true
# Plymouth extra themes
apt-get install -y plymouth-theme-spinner plymouth-theme-breeze 2>/dev/null || true

ok "KDE Plasma installed."

# ─── Install Dolphin file manager ─────────────────────────────────────────────
log "Installing Dolphin file manager with all plugins..."
apt-get install -y dolphin kio-extras
# Optional Dolphin plugins
apt-get install -y dolphin-plugins 2>/dev/null || true
apt-get install -y kdegraphics-thumbnailers 2>/dev/null || true
apt-get install -y ffmpegthumbs 2>/dev/null || true
apt-get install -y baloo baloo-kf5 milou 2>/dev/null || true
apt-get install -y kio-gdrive 2>/dev/null || true

# Konqueror — KDE file manager with TRUE Column View (Miller Columns)
# Dolphin does NOT support Column View, Konqueror does.
# Both are available: Dolphin for daily use, Konqueror for Column View mode.
apt-get install -y konqueror 2>/dev/null || warn "Konqueror install failed"

ok "Dolphin installed."

# Install Dolphin config to PERMANENT locations (survives build cleanup)
# /canvera-config/ is deleted after build — these copies persist in the squashfs
log "Installing Dolphin configuration to permanent locations..."
mkdir -p /etc/skel/.config/
# skel = applied to every new user's home directory automatically
cp /canvera-config/apps/dolphin/dolphinrc /etc/skel/.config/dolphinrc 2>/dev/null || \
    warn "dolphinrc not found at /canvera-config/apps/dolphin/"
# Install places setup script to /usr/local/bin/ (permanent, on PATH)
install -m 755 /canvera-config/apps/dolphin/setup-places.sh \
    /usr/local/bin/canvera-setup-dolphin-places 2>/dev/null || \
    warn "setup-places.sh not found"
ok "Dolphin config installed to /etc/skel/ and /usr/local/bin/."

# ─── Install network hardware support (ethernet firmware + drivers) ───────────
log "Installing network hardware support (ethernet firmware + drivers)..."

# Comprehensive firmware — covers Intel, Broadcom, Marvell, Realtek and more
apt-get install -y linux-firmware

# Realtek RTL8111/8168 — most common desktop/motherboard ethernet chip
# r8168-dkms provides better compatibility than the built-in r8169 kernel module
apt-get install -y r8168-dkms 2>/dev/null || \
    warn "r8168-dkms not found — falling back to built-in r8169 module"

# Realtek RTL8125 — 2.5GbE (newer motherboards: B450/B550/X570/B650 era)
apt-get install -y r8125-dkms 2>/dev/null || true

# Common network tools
apt-get install -y \
    ethtool \
    net-tools \
    iproute2 \
    network-manager \
    network-manager-gnome \
    plasma-nm \
    wpasupplicant

# Broadcom (some systems)
apt-get install -y bcmwl-kernel-source 2>/dev/null || true

# CRITICAL: Configure NetworkManager to manage ALL interfaces including ethernet.
# Without managed=true, NetworkManager ignores ethernet listed in /etc/network/interfaces.
# This is why ethernet appears "unmanaged" or doesn't show up in settings.
mkdir -p /etc/NetworkManager
printf '[main]\nplugins=ifupdown,keyfile\n\n[ifupdown]\nmanaged=true\n\n[connectivity]\nuri=http://connectivity-check.ubuntu.com/\ninterval=300\n' \
    > /etc/NetworkManager/NetworkManager.conf

# Clean /etc/network/interfaces — only keep loopback, let NetworkManager handle the rest
printf '# CanveraOS — NetworkManager manages all interfaces.\n# Only loopback defined here.\nauto lo\niface lo inet loopback\n' \
    > /etc/network/interfaces

# Enable NetworkManager on boot
systemctl enable NetworkManager 2>/dev/null || true
systemctl enable NetworkManager-wait-online 2>/dev/null || true

ok "Network hardware support configured."

# ─── Install Calamares graphical installer ───────────────────────────────────────
log "Installing Calamares installer..."
# Calamares is available in Ubuntu 24.04 universe repo directly (no PPA needed)
apt-get install -y calamares calamares-settings-ubuntu python3-pyqt5 || {
    warn "calamares-settings-ubuntu not found, installing calamares only..."
    apt-get install -y calamares python3-pyqt5 || warn "Calamares install failed — skipping"
}

# ─── Install Calamares configuration into /etc/calamares (İ CRITICAL) ──────────────
# Without this, Calamares has no settings.conf and silently crashes on launch.
log "Installing Calamares configuration files..."
mkdir -p /etc/calamares/modules /etc/calamares/branding/canvera

if [[ -d /canvera-installer/calamares ]]; then
    # Main settings file
    cp /canvera-installer/calamares/settings.conf /etc/calamares/ 2>/dev/null || \
        warn "settings.conf not found"
    # Module configs (.conf files — shellprocess, etc.)
    if [[ -d /canvera-installer/calamares/modules ]]; then
        cp /canvera-installer/calamares/modules/*.conf /etc/calamares/modules/ 2>/dev/null || true
        # DO NOT copy .py files — we use shellprocess modules, not Python modules
    fi
    # Branding
    if [[ -d /canvera-installer/calamares/branding ]]; then
        cp -r /canvera-installer/calamares/branding/canvera/* \
               /etc/calamares/branding/canvera/ 2>/dev/null || true
    fi
    # Copy CanveraOS logo into branding dir for installer UI
    if [[ -f /canvera-theme/canvera-logo.png ]]; then
        cp /canvera-theme/canvera-logo.png \
           /etc/calamares/branding/canvera/canvera-logo.png 2>/dev/null || true
        ok "CanveraOS logo copied to Calamares branding."
    fi
    ok "Calamares configuration installed."
else
    warn "Calamares config source not found at /canvera-installer/calamares"
fi

ok "Calamares installed."

# ─── Create Calamares postinstall script (CRITICAL) ──────────────────────────
# The shellprocess module executes FILE PATHS, not inline commands.
# Each entry in canvera_postinstall.conf is a PATH to an executable script.
# Inline commands like '- "-rm -f /something"' do NOT work — Calamares
# tries to run a script whose PATH IS the string "rm -f /something" (doesn't exist).
# Solution: create a REAL script file here, reference its path in the .conf.
# This script is included in the squashfs and run in the TARGET chroot by Calamares.
log "Creating Calamares postinstall cleanup script..."
cat > /usr/local/bin/canvera-postinstall.sh << 'POSTINSTALL_EOF'
#!/bin/bash
# =============================================================================
# CanveraOS — Post-Installation Cleanup Script
# Executed by Calamares shellprocess@canvera_postinstall inside the TARGET system.
# All paths here refer to the INSTALLED SYSTEM (not the live session).
# =============================================================================

set -x  # Log every command to systemd journal for debugging

# 1. Create installed marker
#    canvera-installer-launcher checks this before launching Calamares.
#    Without this, Calamares relaunches on every user login.
touch /etc/canvera-installed

# 2. CRITICAL: Remove live-session SDDM autologin config.
#    Without this, SDDM on the installed system tries to autologin as 'ubuntu'
#    (the casper live user). 'ubuntu' doesn't exist on the installed system.
#    Result: SDDM fails silently → blank screen → infinite login loop.
rm -f /etc/sddm.conf.d/90-canvera-live-autologin.conf
# Also remove legacy combined config (from earlier builds before the fix)
rm -f /etc/sddm.conf.d/canvera.conf

# 3. Remove NOPASSWD sudo rule (only needed for live session; security risk if kept)
rm -f /etc/sudoers.d/90-canvera-live

# 4. Remove installer autostart from /etc/skel
#    Future users created on the installed system won't get the installer autostart.
rm -f /etc/skel/.config/autostart/canvera-installer.desktop

# 5. Remove installer autostart from existing home directories
#    The Calamares 'users' module copies /etc/skel to the new user's home BEFORE
#    this postinstall script runs. So we must also delete it from the home dir.
find /home -maxdepth 5 \
    -name 'canvera-installer.desktop' \
    -path '*/autostart/*' \
    -delete 2>/dev/null || true

# 6. Cleanup
apt-get clean -y 2>/dev/null || true

echo "CanveraOS postinstall complete" > /var/log/canvera-postinstall.log
POSTINSTALL_EOF
chmod +x /usr/local/bin/canvera-postinstall.sh
ok "Postinstall script created at /usr/local/bin/canvera-postinstall.sh"

# ─── Install filesystem support ───────────────────────────────────────────────
log "Installing filesystem support (APFS, NTFS, ExFAT, FAT32)..."
apt-get install -y \
    ntfs-3g \
    exfatprogs \
    exfat-fuse \
    dosfstools \
    fuse3 \
    udisks2 \
    gvfs \
    gvfs-backends \
    gvfs-fuse \
    unzip

# Optional filesystem tools
apt-get install -y udiskie 2>/dev/null || true

# APFS (read-only via apfs-fuse — optional, non-fatal)
apt-get install -y apfs-fuse 2>/dev/null || {
    warn "apfs-fuse not in repos — skipping APFS support (optional feature)."
}
ok "Filesystem support installed."

# ─── Install CopyQ clipboard manager ─────────────────────────────────────────
log "Installing CopyQ persistent clipboard manager..."
apt-get install -y copyq
ok "CopyQ installed."

# ─── Install fonts ────────────────────────────────────────────────────────────
log "Installing Inter font (SF Pro equivalent)..."
apt-get install -y fonts-inter fonts-noto fonts-noto-color-emoji \
    fonts-liberation fonts-open-sans
# Download Inter variable font (optional — build-time internet required)
# CRITICAL: wrap in { ... } || warn so network failures don't kill the build.
# fonts-inter from apt above already provides Inter; this adds the variable/extended weights.
mkdir -p /usr/share/fonts/canvera
{
    wget -q --timeout=30 -O /tmp/inter.zip \
        "https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip" && \
    unzip -q /tmp/inter.zip -d /tmp/inter/ && \
    find /tmp/inter -name "*.ttf" -o -name "*.otf" | \
        xargs -I{} cp {} /usr/share/fonts/canvera/ 2>/dev/null || true
    rm -rf /tmp/inter.zip /tmp/inter/
    fc-cache -f
    ok "Inter variable font downloaded and installed."
} || {
    warn "Inter font download failed (network issue) — using fonts-inter from apt instead."
    rm -rf /tmp/inter.zip /tmp/inter/ 2>/dev/null || true
    fc-cache -f 2>/dev/null || true
}
ok "Fonts installed."


# ─── Configure SDDM login manager ──────────────────────────────────────────────
log "Configuring SDDM..."
systemctl enable sddm
mkdir -p /etc/sddm.conf.d
# Configure SDDM login manager — TWO files:
# 1. 10-canvera-display.conf — PERMANENT (survives Calamares installation)
# 2. 90-canvera-live-autologin.conf — LIVE SESSION ONLY (removed by canvera_postinstall)

# Permanent SDDM settings (theme, display server, user range)
mkdir -p /etc/sddm.conf.d
printf '[General]\nDisplayServer=x11\nHaltCommand=/usr/bin/systemctl poweroff\nRebootCommand=/usr/bin/systemctl reboot\nNumlock=on\n\n[Users]\nMaximumUid=60000\nMinimumUid=1000\n' \
    > /etc/sddm.conf.d/10-canvera-display.conf

# LIVE SESSION ONLY autologin — canvera_postinstall shellprocess REMOVES this file
# after Calamares completes. Without removal, installed system tries to autologin
# as 'ubuntu' (which doesn't exist on installed system) causing an infinite login loop.
printf '[Autologin]\nUser=ubuntu\nSession=plasma\nRelogin=false\n' \
    > /etc/sddm.conf.d/90-canvera-live-autologin.conf

ok "SDDM configured."

# ─── Configure casper live session ────────────────────────────────────────────────
log "Configuring casper live session (autologin, live user)..."
# casper creates the live user 'ubuntu' with no password
# This file tells casper the live session username and hostname
printf 'export USERNAME=ubuntu\nexport USERFULLNAME="Live Session"\nexport HOST=canveraos\nexport BUILD_SYSTEM=casper\nexport FLAVOUR=CanveraOS\n' \
    > /etc/casper.conf

# CRITICAL: Give live user NOPASSWD sudo so Calamares can launch as root
# Without this, 'sudo calamares' asks for a password that doesn't exist
printf 'ubuntu ALL=(ALL) NOPASSWD: ALL\ncanvera ALL=(ALL) NOPASSWD: ALL\n%%sudo ALL=(ALL) NOPASSWD: ALL\n' \
    > /etc/sudoers.d/90-canvera-live
chmod 440 /etc/sudoers.d/90-canvera-live

# Create system groups needed by Calamares users module and hardware access
# groupadd -f = succeed silently if group already exists
groupadd -f autologin   # needed by Calamares autologin feature
groupadd -f plugdev     # needed for Loupedeck CT, USB devices
groupadd -f netdev      # needed for NetworkManager user control
groupadd -f bluetooth   # needed for BlueDevil
groupadd -f lpadmin     # needed for CUPS printing
groupadd -f scanner     # needed for SANE scanners
ok "Live session configured."

# ─── Apply KDE theme configuration ───────────────────────────────────────────
log "Applying CanveraOS KDE theme..."
bash /canvera-config/kde/plasma-apply-theme.sh
ok "KDE theme applied."

# ─── Install codecs ───────────────────────────────────────────────────────────
log "Installing media codecs..."
bash /codecs-install.sh
ok "Codecs installed."

# ─── Install CrossOver (optional — requires internet at build time) ────────────────
log "Installing CrossOver..."
bash /canvera-config/crossover/crossover-setup.sh || {
    warn "CrossOver install failed or timed out — will be available for manual install."
    warn "Users can install CrossOver after booting CanveraOS."
}
ok "CrossOver step complete."

# ─── Install all applications ────────────────────────────────────────────────────
log "Installing all default applications..."
bash /apps-install.sh
ok "Applications installed."

# ─── Install Loupedeck CT support ────────────────────────────────────────────
log "Setting up Loupedeck CT (udev, drivers, software)..."
bash /canvera-config/loupedeck/loupedeck-setup.sh || \
    warn "Loupedeck setup failed — will be available for manual setup post-install."
ok "Loupedeck CT setup complete."

# ─── Set up first-boot autostart ─────────────────────────────────────────────
log "Setting up first-boot autostart..."
cp /canvera-scripts/first-boot.sh /usr/local/bin/canvera-first-boot
chmod +x /usr/local/bin/canvera-first-boot

# Use XDG autostart (NOT systemd system service) so it runs inside the user's
# graphical session — required for zenity, kwriteconfig5, plasma-apply-* etc.
mkdir -p /etc/skel/.config/autostart
printf '[Desktop Entry]\nName=CanveraOS First Boot Setup\nComment=Runs once on first login to configure CanveraOS\nExec=/usr/local/bin/canvera-first-boot\nTerminal=false\nType=Application\nX-GNOME-Autostart-Delay=5\nX-GNOME-Autostart-enabled=true\n' \
    > /etc/skel/.config/autostart/canvera-first-boot.desktop

# ─── Calamares installer auto-launch ─────────────────────────────────────────────
log "Setting up Calamares installer auto-launch..."
# Launches Calamares automatically when booted with 'automatic-ubiquity' kernel param
# Also handles direct launch if parameter is missing (for robustness)
printf '#!/usr/bin/env bash\n# CanveraOS Calamares auto-launcher\n# Runs on desktop autostart — launches installer if booting from ISO\n\n# Only run on live session (not after installation)\n# If /etc/canvera-installed exists, this is an installed system — skip\n[[ -f /etc/canvera-installed ]] && exit 0\n\n# Wait for KDE desktop to fully load\nsleep 10\n\n# Launch Calamares as root (NOPASSWD sudo configured for live user)\nif command -v calamares &>/dev/null; then\n    sudo -E calamares 2>/tmp/calamares-launch.log || {\n        # Fallback: try pkexec\n        pkexec calamares 2>>/tmp/calamares-launch.log || {\n            # Last resort: notify user\n            notify-send "CanveraOS Installer" \\\n                "Installer failed to launch. Check /tmp/calamares-launch.log" 2>/dev/null || true\n        }\n    }\nfi\n' \
    > /usr/local/bin/canvera-installer-launcher
chmod +x /usr/local/bin/canvera-installer-launcher

printf '[Desktop Entry]\nName=CanveraOS Installer\nExec=/usr/local/bin/canvera-installer-launcher\nTerminal=false\nType=Application\nNoDisplay=true\nX-GNOME-Autostart-enabled=true\nX-GNOME-Autostart-Delay=5\n' \
    > /etc/skel/.config/autostart/canvera-installer.desktop

# Mark installed systems so installer doesn't re-launch after installation
# Calamares will create this file via a postinstall hook
# (For now, Calamares removes the autostart file itself via the users module)
ok "Calamares autostart configured."

# ─── Plymouth boot splash — custom CanveraOS theme ───────────────────────────
log "Installing custom CanveraOS Plymouth boot splash..."

# Create the custom theme directory
mkdir -p /usr/share/plymouth/themes/canvera

# Copy the user's actual CanveraOS logo (theme/canvera-logo.png → logo.png)
if [[ -f /canvera-theme/canvera-logo.png ]]; then
    cp /canvera-theme/canvera-logo.png /usr/share/plymouth/themes/canvera/logo.png
    ok "CanveraOS logo copied to Plymouth theme."
else
    warn "canvera-logo.png not found at /canvera-theme/ — Plymouth may show no logo."
fi

# Copy theme descriptor and animation script
cp /canvera-theme/plymouth/canvera.plymouth \
   /usr/share/plymouth/themes/canvera/ 2>/dev/null || \
   warn "canvera.plymouth not found"
cp /canvera-theme/plymouth/canvera.script \
   /usr/share/plymouth/themes/canvera/ 2>/dev/null || \
   warn "canvera.script not found"

# Set CanveraOS as the default Plymouth theme and rebuild initramfs
plymouth-set-default-theme -R canvera 2>/dev/null || {
    warn "Could not set canvera as default Plymouth theme — trying fallbacks..."
    plymouth-set-default-theme -R spinner 2>/dev/null || true
}
ok "Plymouth boot splash configured (CanveraOS logo)."


# ─── Mask casper-md5check (causes shutdown errors) ────────────────────────────
log "Masking casper-md5check service..."
systemctl mask casper-md5check.service 2>/dev/null || true
ok "casper-md5check masked."

ok "First-boot autostart configured."

# ─── Set up dark mode scheduler ─────────────────────────────────────────────────────
log "Setting up dark mode scheduler..."
cp /canvera-scripts/dark-mode-scheduler.sh /usr/local/bin/canvera-dark-mode
chmod +x /usr/local/bin/canvera-dark-mode
cp /canvera-config/kde/dark-mode.service /etc/systemd/user/canvera-dark-mode.service
cp /canvera-config/kde/dark-mode.timer   /etc/systemd/user/canvera-dark-mode.timer
systemctl --global enable canvera-dark-mode.timer
ok "Dark mode scheduler configured."

# ─── Install multi-monitor setup script ─────────────────────────────────────────────
log "Installing multi-monitor support..."
cp /canvera-scripts/multimonitor-setup.sh /usr/local/bin/canvera-multimonitor
chmod +x /usr/local/bin/canvera-multimonitor
ok "Multi-monitor setup installed."

# ─── Install X11 display config (unlock all refresh rates from EDID) ─────────────
log "Installing X11 display config (unlock 120Hz/144Hz/160Hz)..."
mkdir -p /etc/X11/xorg.conf.d
cp /canvera-config/X11/99-canvera-display.conf /etc/X11/xorg.conf.d/ 2>/dev/null || \
    warn "X11 display config not found at /canvera-config/X11/"
ok "X11 display config installed."

# ─── Security setup ────────────────────────────────────────────────────────────
log "Configuring security (UFW, AppArmor)..."
# NOTE: UFW and AppArmor need a running kernel with netfilter — use || true in chroot
ufw --force enable 2>/dev/null || true
ufw default deny incoming  2>/dev/null || true
ufw default allow outgoing 2>/dev/null || true
ufw allow ssh              2>/dev/null || true
systemctl enable apparmor  2>/dev/null || true
ok "Security configured."

# ─── Set Flatpak remote ─────────────────────────────────────────────────────
log "Configuring Flathub..."
# NOTE: flatpak remote-add needs D-Bus, which is not available in chroot.
# Use || true to prevent build failure. Flathub is configured at first-boot instead.
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
ok "Flathub configured (may need first-boot to complete)."

# ─── Final cleanup ────────────────────────────────────────────────────────────
log "Final system configuration..."
# Set default target to graphical
systemctl set-default graphical.target
# Enable NetworkManager
systemctl enable NetworkManager

# CRITICAL: Rebuild initramfs at the END (after ALL packages and hooks installed)
# Use -c (CREATE fresh) not -u (update) to guarantee a clean rebuild.
# Do NOT use 2>/dev/null — we NEED to see errors to debug failures.
log "Rebuilding initramfs from scratch (includes overlay hook)..."

# Show what kernels we'll be building for
ls /boot/vmlinuz-* 2>/dev/null && log "Found kernel(s) above."

# Create fresh initramfs for all installed kernels
# If -c fails, fall back to -u, then just warn
update-initramfs -c -k all 2>&1 | tee /tmp/initramfs-build.log || \
update-initramfs -u -k all 2>&1 | tee -a /tmp/initramfs-build.log || {
    warn "initramfs rebuild had errors — check /tmp/initramfs-build.log"
    cat /tmp/initramfs-build.log >&2 || true
}

# VERIFY: confirm overlay module is actually inside the built initramfs
for INITRD in /boot/initrd.img-*; do
    [[ -f "$INITRD" ]] || continue
    log "Verifying overlay module in ${INITRD}..."
    if zcat "$INITRD" 2>/dev/null | cpio -t 2>/dev/null | grep -q "overlay.ko"; then
        ok "overlay.ko CONFIRMED inside ${INITRD}"
    elif lz4cat "$INITRD" 2>/dev/null | cpio -t 2>/dev/null | grep -q "overlay.ko"; then
        ok "overlay.ko CONFIRMED inside ${INITRD} (lz4)"
    else
        warn "WARNING: overlay.ko NOT found in ${INITRD} — live boot will fail!"
        warn "Attempting forced rebuild with explicit overlay inclusion..."
        # Last resort: manually copy overlay.ko into an existing initramfs
        # This is done by forcing a fresh create with the hook in place
        update-initramfs -c -k all 2>&1 || true
    fi
done

ok "Initramfs rebuild complete."

# Set machine-id for live session
echo -n > /etc/machine-id

ok "Chroot setup complete! All CanveraOS components installed."
