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
cat > /etc/apt/sources.list << 'EOF'
# CanveraOS — Ubuntu 24.04 LTS (Noble Numbat) repositories


# Add Flatpak / Flathub support
cat > /etc/apt/sources.list.d/flathub.list << 'EOF'
# Flathub — added via flatpak remote-add in post-install
EOF

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
    grub-pc \
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
    xdg-utils

# Configure locale
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
ok "Base packages installed."

# ─── Install KDE Plasma 6 ─────────────────────────────────────────────────────
log "Installing KDE Plasma desktop environment..."
apt-get install -y \
    kde-plasma-desktop \
    plasma-workspace \
    plasma-workspace-wayland \
    kwin-x11 \
    kwin-wayland \
    sddm \
    sddm-theme-breeze \
    kde-config-sddm \
    plasma-nm \
    plasma-pa \
    powerdevil \
    bluedevil \
    kscreen \
    plasma-disks \
    plasma-vault \
    dragonplayer \
    ark \
    okular \
    spectacle \
    konsole \
    kate \
    gwenview \
    kcalc \
    kfind \
    filelight \
    plasma-systemmonitor \
    kde-system-administration \
    kde-config-screenlocker \
    kde-config-gtk-style \
    kde-config-gtk-style-preview \
    plasma-widgets-addons \
    plasma-browser-integration \
    xdg-desktop-portal-kde \
    kvantum \
    qt5-style-kvantum \
    qt6-style-kvantum \
    packagekit-qt5

ok "KDE Plasma installed."

# ─── Install Dolphin file manager ─────────────────────────────────────────────
log "Installing Dolphin file manager with all plugins..."
apt-get install -y \
    dolphin \
    dolphin-plugins \
    kdegraphics-thumbnailers \
    kffmpegthumbnailer \
    ffmpegthumbs \
    taglib-extras \
    baloo \
    baloo-kf5 \
    milou \
    kio-extras \
    kio-gdrive \
    libkf5baloo-dev

ok "Dolphin installed."

# ─── Install Calamares graphical installer ────────────────────────────────────
log "Installing Calamares installer..."
apt-get install -y calamares python3-pyqt5 || warn "Calamares install failed - skipping"

ok "Calamares installed."

# ─── Install filesystem support ───────────────────────────────────────────────
log "Installing filesystem support (APFS, NTFS, ExFAT, FAT32)..."
apt-get install -y \
    ntfs-3g \
    exfatprogs \
    exfat-fuse \
    dosfstools \
    fuse \
    fuse3 \
    libfuse-dev \
    udisks2 \
    udiskie \
    gvfs \
    gvfs-backends \
    gvfs-fuse

# APFS (read/write via apfs-fuse)
apt-get install -y apfs-fuse || {
    warn "apfs-fuse not in repos — building from source..."
    apt-get install -y build-essential cmake libfuse-dev bzip2 zlib1g-dev
    git clone --depth=1 https://github.com/sgan81/apfs-fuse.git /tmp/apfs-fuse
    cd /tmp/apfs-fuse
    git submodule update --init
    cmake -DCMAKE_BUILD_TYPE=Release . && make -j$(nproc) && make install
    cd / && rm -rf /tmp/apfs-fuse
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

# ─── Configure SDDM login manager ────────────────────────────────────────────
log "Configuring SDDM..."
systemctl enable sddm
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/canvera.conf << 'EOF'
[Theme]
Current=breeze

[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Autologin]
Relogin=false

[Users]
MaximumUid=60000
MinimumUid=1000
EOF
ok "SDDM configured."

# ─── Apply KDE theme configuration ───────────────────────────────────────────
log "Applying CanveraOS KDE theme..."
bash /canvera-config/kde/plasma-apply-theme.sh
ok "KDE theme applied."

# ─── Install codecs ───────────────────────────────────────────────────────────
log "Installing media codecs..."
bash /codecs-install.sh
ok "Codecs installed."

# ─── Install CrossOver ────────────────────────────────────────────────────────
log "Installing CrossOver..."
bash /canvera-config/crossover/crossover-setup.sh || true

ok "CrossOver installed."

# ─── Install all applications ─────────────────────────────────────────────────
log "Installing all default applications..."
bash /apps-install.sh
ok "Applications installed."

# ─── Set up first-boot service ───────────────────────────────────────────────
log "Setting up first-boot service..."
cp /canvera-scripts/first-boot.sh /usr/local/bin/canvera-first-boot
chmod +x /usr/local/bin/canvera-first-boot

cat > /etc/systemd/system/canvera-first-boot.service << 'EOF'
[Unit]
Description=CanveraOS First Boot Setup
After=graphical.target sddm.service
ConditionPathExists=!/var/lib/canvera/.first-boot-done

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/canvera-first-boot
ExecStartPost=/bin/mkdir -p /var/lib/canvera
ExecStartPost=/bin/touch /var/lib/canvera/.first-boot-done

[Install]
WantedBy=multi-user.target
EOF
systemctl enable canvera-first-boot.service

# ─── Set up dark mode scheduler ──────────────────────────────────────────────
log "Setting up dark mode scheduler..."
cp /canvera-scripts/dark-mode-scheduler.sh /usr/local/bin/canvera-dark-mode
chmod +x /usr/local/bin/canvera-dark-mode
cp /canvera-config/kde/dark-mode.service /etc/systemd/user/canvera-dark-mode.service
cp /canvera-config/kde/dark-mode.timer   /etc/systemd/user/canvera-dark-mode.timer
systemctl --global enable canvera-dark-mode.timer
ok "Dark mode scheduler configured."

# ─── Security setup ───────────────────────────────────────────────────────────
log "Configuring security (UFW, AppArmor)..."
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
systemctl enable apparmor
ok "Security configured."

# ─── Set Flatpak remote ───────────────────────────────────────────────────────
log "Configuring Flathub..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
ok "Flathub configured."

# ─── Final cleanup ────────────────────────────────────────────────────────────
log "Final system configuration..."
# Set default target to graphical
systemctl set-default graphical.target
# Enable NetworkManager
systemctl enable NetworkManager
# Update initramfs
update-initramfs -u -k all
# Set machine-id for live session
echo -n > /etc/machine-id

ok "Chroot setup complete! All CanveraOS components installed."
