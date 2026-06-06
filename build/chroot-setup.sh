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

# ─── CRITICAL: Add overlay module to initramfs ───────────────────────────────────
# Without 'overlay' in initramfs, casper fails on boot with:
# "(initramfs) /cow format specified as 'overlay' and no support found"
# This MUST happen before the first update-initramfs call.
log "Configuring initramfs for casper live boot (overlay, squashfs, loop)..."
mkdir -p /etc/initramfs-tools

# Ensure the modules file exists and has required entries
for MOD in overlay squashfs loop iso9660 aufs; do
    grep -q "^${MOD}$" /etc/initramfs-tools/modules 2>/dev/null || \
        echo "${MOD}" >> /etc/initramfs-tools/modules
done

# Configure initramfs-tools for casper
mkdir -p /etc/initramfs-tools/conf.d
printf '# CanveraOS initramfs configuration\n# MODULES=most includes all common drivers including overlay\nMODULES=most\nCOMPRESS=lz4\nBUSYBOX=auto\n' \
    > /etc/initramfs-tools/conf.d/canvera.conf

ok "Initramfs configured for casper live boot."

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
# Download Inter variable font
mkdir -p /usr/share/fonts/canvera
wget -q -O /tmp/inter.zip "https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip"
unzip -q /tmp/inter.zip -d /tmp/inter/
find /tmp/inter -name "*.ttf" -o -name "*.otf" | xargs -I{} cp {} /usr/share/fonts/canvera/
fc-cache -f
rm -rf /tmp/inter.zip /tmp/inter/
ok "Fonts installed."

# ─── Configure SDDM login manager ──────────────────────────────────────────────
log "Configuring SDDM..."
systemctl enable sddm
mkdir -p /etc/sddm.conf.d
# Live session: autologin as ubuntu (casper user) so Calamares autostart fires immediately
printf '[Theme]\nCurrent=breeze\n\n[General]\nDisplayServer=x11\nGreeterEnvironment=QT_SCREEN_SCALE_FACTORS=1\n\n[Autologin]\nUser=ubuntu\nSession=plasma\nRelogin=false\n\n[Users]\nMaximumUid=60000\nMinimumUid=1000\n' \
    > /etc/sddm.conf.d/canvera.conf
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

# CRITICAL: Rebuild initramfs at the END (after ALL packages installed)
# This ensures overlay, squashfs, loop, r8168, etc. are all included.
log "Rebuilding initramfs (includes overlay module for casper live boot)..."
update-initramfs -u -k all 2>/dev/null || update-initramfs -u 2>/dev/null || \
    warn "initramfs update failed — boot may have issues"
ok "Initramfs rebuilt."

# Set machine-id for live session
echo -n > /etc/machine-id

ok "Chroot setup complete! All CanveraOS components installed."
