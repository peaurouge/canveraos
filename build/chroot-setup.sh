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
log "Pre-configuring initramfs-tools (config + hook + modules — ALL before kernel)..."

mkdir -p /etc/initramfs-tools/conf.d
printf '# CanveraOS initramfs config\nMODULES=most\nCOMPRESS=gzip\nBUSYBOX=auto\n' \
    > /etc/initramfs-tools/conf.d/canvera.conf

mkdir -p /etc/initramfs-tools/hooks
cat > /etc/initramfs-tools/hooks/zz-canvera-live-modules << 'HOOKEOF'
#!/bin/sh
PREREQ=""
prereqs() { echo "$PREREQ"; }
case $1 in prereqs) prereqs; exit 0 ;; esac
. /usr/share/initramfs-tools/hook-functions

copy_modules_dir kernel/fs/overlayfs 2>/dev/null || true
copy_modules_dir kernel/fs/overlay   2>/dev/null || true
manual_add_modules overlay  2>/dev/null || true

if [ -n "${DESTDIR}" ] && [ -n "${MODULESDIR}" ]; then
    OVL=$(find "${MODULESDIR}" -name "overlay.ko*" -print -quit 2>/dev/null)
    if [ -n "${OVL}" ]; then
        REL="${OVL#${MODULESDIR}}"
        mkdir -p "${DESTDIR}/lib/modules/${version}/$(dirname "${REL}")"
        cp -f "${OVL}" "${DESTDIR}/lib/modules/${version}/${REL}" 2>/dev/null || true
    fi
fi

copy_modules_dir kernel/fs/squashfs 2>/dev/null || true
manual_add_modules squashfs 2>/dev/null || true
manual_add_modules loop     2>/dev/null || true
copy_modules_dir kernel/fs/isofs    2>/dev/null || true
manual_add_modules isofs    2>/dev/null || true

for mod in overlay squashfs loop; do
    echo "$mod" >> "${DESTDIR}/conf/modules" 2>/dev/null || true
done
exit 0
HOOKEOF
chmod 755 /etc/initramfs-tools/hooks/zz-canvera-live-modules

mkdir -p /etc/initramfs-tools
for MOD in overlay squashfs loop; do
    grep -q "^${MOD}$" /etc/initramfs-tools/modules 2>/dev/null || \
        echo "${MOD}" >> /etc/initramfs-tools/modules
done
ok "initramfs-tools FULLY pre-configured."

# ─── Install essential base packages ──────────────────────────────────────────
log "Installing base system packages..."
apt-get install -y --no-install-recommends \
    ubuntu-minimal ubuntu-standard linux-image-generic linux-headers-generic \
    linux-firmware casper laptop-detect os-prober grub-efi-amd64 \
    grub-efi-amd64-signed shim-signed locales language-pack-en tzdata \
    ca-certificates curl wget git gpg software-properties-common \
    apt-transport-https network-manager network-manager-gnome net-tools \
    wireless-tools wpasupplicant openssh-client ufw apparmor apparmor-utils \
    apparmor-profiles flatpak xdg-desktop-portal xdg-utils policykit-1 \
    libxss1 plymouth plymouth-themes

locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
ok "Base packages installed."

log "Re-enabling universe repository for KDE packages..."
add-apt-repository -y universe
apt-get update -qq

# ─── Install KDE Plasma 6 ─────────────────────────────────────────────────────
log "Installing KDE Plasma desktop environment..."
apt-get install -y \
    kde-plasma-desktop plasma-workspace plasma-workspace-wayland kwin-x11 \
    kwin-wayland sddm sddm-theme-breeze plasma-nm plasma-pa powerdevil \
    bluedevil kscreen ark okular konsole kate gwenview kcalc \
    plasma-systemmonitor xdg-desktop-portal-kde plank

apt-get install -y kde-config-sddm plasma-disks plasma-vault kde-spectacle kfind filelight kde-config-screenlocker kde-config-gtk-style kde-config-gtk-style-preview plasma-widgets-addons plasma-browser-integration dragonplayer qt5ct qt6ct qt5-style-kvantum qt5-style-kvantum-l10n appmenu-gtk3-module plymouth-theme-spinner plymouth-theme-breeze 2>/dev/null || true
ok "KDE Plasma installed."

# ─── Install Dolphin file manager & Service Menus ──────────────────────────────
log "Installing Dolphin file manager with all plugins..."
apt-get install -y dolphin kio-extras
apt-get install -y dolphin-plugins kdegraphics-thumbnailers ffmpegthumbs baloo baloo-kf5 milou kio-gdrive konqueror 2>/dev/null || true
ok "Dolphin installed."

log "Installing Dolphin configuration & Creative Quick Actions..."
mkdir -p /etc/skel/.config/
cp /canvera-config/apps/dolphin/dolphinrc /etc/skel/.config/dolphinrc 2>/dev/null || true
install -m 755 /canvera-config/apps/dolphin/setup-places.sh /usr/local/bin/canvera-setup-dolphin-places 2>/dev/null || true

# DOSYA 1 ENTEGRASYONU: Sağ Tık Hızlı Eylemler (WebP, PNG, Resize HD)
mkdir -p /usr/share/kio/servicemenus
cp /canvera-config/apps/dolphin/canvera-creative-actions.desktop /usr/share/kio/servicemenus/ 2>/dev/null || true
ok "Dolphin config and Creative Actions installed."

# ─── Install network hardware support ─────────────────────────────────────────
log "Installing network hardware support..."
apt-get install -y linux-firmware ethtool iproute2 network-manager network-manager-gnome plasma-nm wpasupplicant
apt-get install -y r8168-dkms r8125-dkms bcmwl-kernel-source 2>/dev/null || true

mkdir -p /etc/NetworkManager
printf '[main]\nplugins=ifupdown,keyfile\n\n[ifupdown]\nmanaged=true\n\n[connectivity]\nuri=http://connectivity-check.ubuntu.com/\ninterval=300\n' > /etc/NetworkManager/NetworkManager.conf
printf '# CanveraOS — NetworkManager manages all interfaces.\nauto lo\niface lo inet loopback\n' > /etc/network/interfaces
systemctl enable NetworkManager 2>/dev/null || true
ok "Network hardware support configured."

# ─── Install Calamares graphical installer ────────────────────────────────────
log "Installing Calamares installer..."
apt-get install -y calamares calamares-settings-ubuntu python3-pyqt5 || {
    apt-get install -y calamares python3-pyqt5 || warn "Calamares install failed"
}

log "Installing Calamares configuration files..."
mkdir -p /etc/calamares/modules /etc/calamares/branding/canvera
if [[ -d /canvera-installer/calamares ]]; then
    cp /canvera-installer/calamares/settings.conf /etc/calamares/ 2>/dev/null || true
    if [[ -d /canvera-installer/calamares/modules ]]; then
        cp /canvera-installer/calamares/modules/*.conf /etc/calamares/modules/ 2>/dev/null || true
    fi
    if [[ -d /canvera-installer/calamares/branding ]]; then
        cp -r /canvera-installer/calamares/branding/canvera/* /etc/calamares/branding/canvera/ 2>/dev/null || true
    fi
    if [[ -f /canvera-theme/canvera-logo.png ]]; then
        cp /canvera-theme/canvera-logo.png /etc/calamares/branding/canvera/canvera-logo.png 2>/dev/null || true
    fi
fi

log "Creating Calamares postinstall cleanup script..."
cat > /usr/local/bin/canvera-postinstall.sh << 'POSTINSTALL_EOF'
#!/bin/bash
set -x
touch /etc/canvera-installed
rm -f /etc/sddm.conf.d/90-canvera-live-autologin.conf
rm -f /etc/sddm.conf.d/canvera.conf
rm -f /etc/sudoers.d/90-canvera-live
rm -f /etc/skel/.config/autostart/canvera-installer.desktop
find /home -maxdepth 5 -name 'canvera-installer.desktop' -path '*/autostart/*' -delete 2>/dev/null || true
apt-get clean -y 2>/dev/null || true
POSTINSTALL_EOF
chmod +x /usr/local/bin/canvera-postinstall.sh
ok "Calamares installed and configured."

# ─── DOSYA 2 ENTEGRASYONU: Install Advanced Filesystem & APFS Support ────────
log "Installing advanced filesystem support (APFS, NTFS, ExFAT, FAT32)..."
apt-get install -y ntfs-3g exfatprogs exfat-fuse dosfstools fuse3 udisks2 gvfs gvfs-backends gvfs-fuse unzip udiskie

log "Building APFS native kernel module and fallback tools via DKMS..."
apt-get install -y dkms build-essential linux-headers-generic libfuse3-dev bzip2 libbz2-dev cmake

# linux-apfs-rw module
git clone https://github.com/linux-apfs/linux-apfs-rw.git /usr/src/apfs-1.0 2>/dev/null || true
dkms add -m apfs -v 1.0 2>/dev/null || true
dkms build -m apfs -v 1.0 2>/dev/null || true
dkms install -m apfs -v 1.0 2>/dev/null || true

# apfs-fuse fallback
git clone https://github.com/sgan81/apfs-fuse.git /tmp/apfs-fuse 2>/dev/null || true
(cd /tmp/apfs-fuse && git submodule init && git submodule update && mkdir build && cd build && cmake .. && make -j$(nproc) && make install) || warn "apfs-fuse build failed"
rm -rf /tmp/apfs-fuse
ok "Filesystem support (including APFS) successfully compiled and installed."

# ─── Core UI & Fonts ──────────────────────────────────────────────────────────
log "Installing CopyQ persistent clipboard manager..."
apt-get install -y copyq

log "Installing Inter font (SF Pro equivalent)..."
apt-get install -y fonts-inter fonts-noto fonts-noto-color-emoji fonts-liberation fonts-open-sans
mkdir -p /usr/share/fonts/canvera
{
    wget -q --timeout=30 -O /tmp/inter.zip "https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip" && \
    unzip -q /tmp/inter.zip -d /tmp/inter/ && \
    find /tmp/inter -name "*.ttf" -o -name "*.otf" | xargs -I{} cp {} /usr/share/fonts/canvera/ 2>/dev/null || true
    rm -rf /tmp/inter.zip /tmp/inter/
    fc-cache -f
} || true
ok "Fonts installed."

# ─── Configure SDDM login manager ──────────────────────────────────────────────
log "Configuring SDDM..."
systemctl enable sddm
mkdir -p /etc/sddm.conf.d
printf '[General]\nDisplayServer=x11\nHaltCommand=/usr/bin/systemctl poweroff\nRebootCommand=/usr/bin/systemctl reboot\nNumlock=on\n\n[Users]\nMaximumUid=60000\nMinimumUid=1000\n' > /etc/sddm.conf.d/10-canvera-display.conf
printf '[Autologin]\nUser=ubuntu\nSession=plasma\nRelogin=false\n' > /etc/sddm.conf.d/90-canvera-live-autologin.conf
ok "SDDM configured."

# ─── Configure casper live session ─────────────────────────────────────────────
log "Configuring casper live session..."
printf 'export USERNAME=ubuntu\nexport USERFULLNAME="Live Session"\nexport HOST=canveraos\nexport BUILD_SYSTEM=casper\nexport FLAVOUR=CanveraOS\n' > /etc/casper.conf
printf 'ubuntu ALL=(ALL) NOPASSWD: ALL\ncanvera ALL=(ALL) NOPASSWD: ALL\n%%sudo ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/90-canvera-live
chmod 440 /etc/sudoers.d/90-canvera-live

groupadd -f autologin; groupadd -f plugdev; groupadd -f netdev; groupadd -f bluetooth; groupadd -f lpadmin; groupadd -f scanner
ok "Live session configured."

# ─── Apply KDE theme & Install apps ────────────────────────────────────────────
log "Applying CanveraOS KDE theme..."
bash /canvera-config/kde/plasma-apply-theme.sh 2>/dev/null || true

log "Installing media codecs..."
bash /codecs-install.sh 2>/dev/null || true

log "Installing CrossOver..."
bash /canvera-config/crossover/crossover-setup.sh 2>/dev/null || true

log "Installing all default applications..."
bash /apps-install.sh 2>/dev/null || true

log "Setting up Loupedeck CT..."
bash /canvera-config/loupedeck/loupedeck-setup.sh 2>/dev/null || true

# ─── DOSYA 4 & 5 ENTEGRASYONU: GUI Installers (Resolve & Adobe) ────────────────
log "Integrating GUI Installers for DaVinci Resolve and Adobe CC..."
# DaVinci Resolve Installer
cp /canvera-scripts/canvera-install-resolve.sh /usr/local/bin/canvera-install-resolve 2>/dev/null || true
chmod +x /usr/local/bin/canvera-install-resolve 2>/dev/null || true

# Adobe CC Installer & Desktop Shortcut
cp /canvera-scripts/canvera-install-adobe.sh /usr/local/bin/canvera-install-adobe 2>/dev/null || true
chmod +x /usr/local/bin/canvera-install-adobe 2>/dev/null || true

printf '[Desktop Entry]\nName=Install Adobe CC\nComment=Install Photoshop, Illustrator via CrossOver\nExec=/usr/local/bin/canvera-install-adobe\nIcon=applications-graphics\nTerminal=false\nType=Application\nCategories=Graphics;\nStartupNotify=true\n' \
    > /usr/share/applications/canvera-install-adobe.desktop
ok "GUI Installers perfectly integrated."

# ─── Autostart & Splash Screen ────────────────────────────────────────────────
log "Setting up first-boot and installer autostart..."
cp /canvera-scripts/first-boot.sh /usr/local/bin/canvera-first-boot 2>/dev/null || true
chmod +x /usr/local/bin/canvera-first-boot 2>/dev/null || true
mkdir -p /etc/skel/.config/autostart
printf '[Desktop Entry]\nName=CanveraOS First Boot Setup\nExec=/usr/local/bin/canvera-first-boot\nTerminal=false\nType=Application\nX-GNOME-Autostart-Delay=5\nX-GNOME-Autostart-enabled=true\n' > /etc/skel/.config/autostart/canvera-first-boot.desktop

printf '#!/usr/bin/env bash\n[[ -f /etc/canvera-installed ]] && exit 0\nsleep 10\nif command -v calamares &>/dev/null; then sudo -E calamares 2>/tmp/calamares.log || pkexec calamares 2>>/tmp/calamares.log; fi\n' > /usr/local/bin/canvera-installer-launcher
chmod +x /usr/local/bin/canvera-installer-launcher
printf '[Desktop Entry]\nName=CanveraOS Installer\nExec=/usr/local/bin/canvera-installer-launcher\nTerminal=false\nType=Application\nNoDisplay=true\nX-GNOME-Autostart-enabled=true\nX-GNOME-Autostart-Delay=5\n' > /etc/skel/.config/autostart/canvera-installer.desktop

log "Installing custom CanveraOS Plymouth boot splash..."
mkdir -p /usr/share/plymouth/themes/canvera
cp /canvera-theme/canvera-logo.png /usr/share/plymouth/themes/canvera/logo.png 2>/dev/null || true
cp /canvera-theme/plymouth/canvera.plymouth /usr/share/plymouth/themes/canvera/ 2>/dev/null || true
cp /canvera-theme/plymouth/canvera.script /usr/share/plymouth/themes/canvera/ 2>/dev/null || true
plymouth-set-default-theme -R canvera 2>/dev/null || plymouth-set-default-theme -R spinner 2>/dev/null || true

# ─── Environment & Security ───────────────────────────────────────────────────
systemctl mask casper-md5check.service 2>/dev/null || true

cp /canvera-scripts/dark-mode-scheduler.sh /usr/local/bin/canvera-dark-mode 2>/dev/null || true
chmod +x /usr/local/bin/canvera-dark-mode 2>/dev/null || true
cp /canvera-config/kde/dark-mode.service /etc/systemd/user/canvera-dark-mode.service 2>/dev/null || true
cp /canvera-config/kde/dark-mode.timer   /etc/systemd/user/canvera-dark-mode.timer 2>/dev/null || true
systemctl --global enable canvera-dark-mode.timer 2>/dev/null || true

cp /canvera-scripts/multimonitor-setup.sh /usr/local/bin/canvera-multimonitor 2>/dev/null || true
chmod +x /usr/local/bin/canvera-multimonitor 2>/dev/null || true

mkdir -p /etc/X11/xorg.conf.d
cp /canvera-config/X11/99-canvera-display.conf /etc/X11/xorg.conf.d/ 2>/dev/null || true

ufw --force enable 2>/dev/null || true
ufw default deny incoming 2>/dev/null || true
ufw default allow outgoing 2>/dev/null || true
systemctl enable apparmor 2>/dev/null || true

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

# ─── Final cleanup & Initramfs Rebuild ────────────────────────────────────────
log "Final system configuration..."
systemctl set-default graphical.target
systemctl enable NetworkManager

log "Rebuilding initramfs from scratch (includes overlay hook)..."
update-initramfs -c -k all 2>&1 | tee /tmp/initramfs-build.log || update-initramfs -u -k all 2>&1 | tee -a /tmp/initramfs-build.log || true

for INITRD in /boot/initrd.img-*; do
    [[ -f "$INITRD" ]] || continue
    VERIFY_DIR=$(mktemp -d)
    if command -v unmkinitramfs &>/dev/null; then
        unmkinitramfs "$INITRD" "$VERIFY_DIR" 2>/dev/null || true
    else
        (cd "$VERIFY_DIR" && zcat "$INITRD" 2>/dev/null | cpio -id 2>/dev/null) || true
    fi
    
    if ! find "$VERIFY_DIR" -name "overlay.ko*" -print -quit 2>/dev/null | grep -q .; then
        KVER=$(basename "$INITRD" | sed 's/initrd.img-//')
        OVL_SRC=$(find /lib/modules/"$KVER" -name "overlay.ko*" -print -quit 2>/dev/null)
        if [[ -n "$OVL_SRC" ]]; then
            echo "overlay" >> /etc/initramfs-tools/modules
            update-initramfs -c -k "$KVER" 2>&1 || true
        fi
    fi
    rm -rf "$VERIFY_DIR"
done

echo -n > /etc/machine-id
ok "Chroot setup complete! CanveraOS is fully built and staged."