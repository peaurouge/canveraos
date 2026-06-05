#!/usr/bin/env bash
# =============================================================================
# CanveraOS — KDE Plasma Theme Application Script
# Applies the full macOS Tahoe-inspired visual theme to KDE Plasma.
# This runs inside the chroot during build — sets system-wide defaults.
# =============================================================================
set -euo pipefail

log() { echo -e "\033[0;36m[THEME]\033[0m $*"; }
ok()  { echo -e "\033[0;32m[  OK  ]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[ WARN ]\033[0m $*"; }

THEME_DIR="/canvera-theme"
CONFIG_DIR="/canvera-config/kde"
SKEL="/etc/skel"

# ─── Install Kvantum theme engine ─────────────────────────────────────────────
log "Configuring Kvantum theme engine (glassmorphism)..."
mkdir -p /usr/share/Kvantum/CanveraOS
cp "${THEME_DIR}/kvantum/CanveraOS.kvconfig" /usr/share/Kvantum/CanveraOS/ || warn "CanveraOS.kvconfig missing"
cp "${THEME_DIR}/kvantum/CanveraOS.svg"      /usr/share/Kvantum/CanveraOS/ || warn "CanveraOS.svg missing"
ok "Kvantum theme installed."

# ─── Install color schemes ────────────────────────────────────────────────────
log "Installing CanveraOS color schemes (light + dark)..."
mkdir -p /usr/share/color-schemes
cp "${THEME_DIR}/plasma/CanveraOS.colors"     /usr/share/color-schemes/ || warn "CanveraOS.colors missing"
cp "${THEME_DIR}/plasma/CanveraOSDark.colors" /usr/share/color-schemes/ || warn "CanveraOSDark.colors missing"
ok "Color schemes installed."

# ─── Install window decoration (Klassy with macOS traffic lights) ─────────────
log "Installing Klassy window decoration..."
apt-get install -y klassy 2>/dev/null || {
    warn "Klassy not in repos — building from source..."
    apt-get install -y cmake extra-cmake-modules kdecoration-dev \
                       kf6-kirigami-dev libkf6coreaddons-dev 2>/dev/null || true
    git clone --depth=1 https://github.com/paulmcauley/klassy.git /tmp/klassy 2>/dev/null && {
        cd /tmp/klassy
        cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr 2>/dev/null || true
        cmake --build build -j$(nproc) 2>/dev/null || true
        cmake --install build 2>/dev/null || true
        cd / && rm -rf /tmp/klassy
    } || warn "Klassy build failed — using default window decoration."
}
ok "Window decoration step complete."

# ─── Install WhiteSur icon + Plasma theme (macOS Tahoe style) ────────────────
log "Installing macOS Tahoe-style icon and Plasma theme..."
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git /tmp/whitesur-icons 2>/dev/null && {
    cd /tmp/whitesur-icons
    bash install.sh -t default -d /usr/share/icons 2>/dev/null || true
    cd / && rm -rf /tmp/whitesur-icons
    ok "WhiteSur icon theme installed."
} || warn "WhiteSur icon theme download failed — using breeze icons."

git clone --depth=1 https://github.com/vinceliuice/WhiteSur-kde.git /tmp/whitesur-kde 2>/dev/null && {
    cd /tmp/whitesur-kde
    bash install.sh 2>/dev/null || true
    cd / && rm -rf /tmp/whitesur-kde
    ok "WhiteSur Plasma theme installed."
} || warn "WhiteSur Plasma theme download failed — using Breeze Dark."

# ─── Configure system-wide KDE defaults ──────────────────────────────────────
log "Writing KDE global configuration..."
mkdir -p "${SKEL}/.config"
mkdir -p "${SKEL}/.local/share/plasma/plasmoids"

# kdeglobals — fonts, colors, icons, widget style
printf '[General]\nColorScheme=CanveraOSDark\nName=CanveraOS Dark\nshadeSortColumn=true\nXftAntialias=true\nXftHintStyle=hintslight\nXftSubPixel=rgb\n\n[Icons]\nTheme=WhiteSur-dark\n\n[KDE]\nLookAndFeelPackage=org.kde.breezedark.desktop\nSingleClick=false\nAnimationDurationFactor=0.5\nwidgetStyle=kvantum-dark\n\n[WM]\nactiveFont=Inter,13,-1,5,50,0,0,0,0,0\n' \
    > "${SKEL}/.config/kdeglobals"

# kwinrc — window manager settings (macOS-style behavior)
printf '[Compositing]\nBackend=OpenGL\nGLCore=true\nHiddenPreviews=5\nOpenGLIsUnsafe=false\nWindowsBlockCompositing=false\n\n[Desktops]\nNumber=1\nRows=1\n\n[Effect-Blur]\nBlurStrength=12\nNoiseStrength=2\n\n[Effect-wobblywindows]\nDrag=85\nStiffness=10\nWobbleFactor=15\n\n[Plugins]\nblurEnabled=true\ncontrastEnabled=true\nkwin4_effect_fadeEnabled=true\nwobblywindowsEnabled=true\nslideEnabled=true\nminimizeanimationEnabled=true\n\n[TabBox]\nLayoutName=thumbnail_grid\n\n[Windows]\nFocusPolicy=ClickToFocus\nTitlebarDoubleClickCommand=Maximize\n' \
    > "${SKEL}/.config/kwinrc"

# plasmashellrc — panel layout
printf '[PlasmaViews][Panel 1]\nfloating=0\nthickness=28\n\n[PlasmaViews][Panel 2]\nthickness=72\n' \
    > "${SKEL}/.config/plasmashellrc"

ok "KDE configuration written to /etc/skel."

# ─── Configure Plank Dock (macOS-style dock, replaces Latte Dock) ─────────────
log "Configuring Plank dock (macOS-style)..."
mkdir -p "${SKEL}/.config/plank/dock1/launchers"

# Plank preferences
printf '[PlankDockPreferences]\nTheme=Transparent\nPosition=3\nIconSize=56\nOffset=0\nZoomEnabled=true\nZoomPercent=150\nHideMode=0\nMonitor=\nPressureSensitivity=5\nUnhideDelay=0\nHideDelay=0\n' \
    > "${SKEL}/.config/plank/dock1/settings"

# Default dock launchers
for app in org.kde.dolphin.desktop org.kde.konsole.desktop firefox.desktop code.desktop; do
    printf '[PlankDockItemPreferences]\nLauncher=file:///usr/share/applications/%s\n' "$app" \
        > "${SKEL}/.config/plank/dock1/launchers/${app}"
done

# Autostart Plank on login
mkdir -p "${SKEL}/.config/autostart"
printf '[Desktop Entry]\nType=Application\nName=Plank\nExec=plank\nHidden=false\nNoDisplay=false\nX-GNOME-Autostart-enabled=true\nComment=macOS-style dock\n' \
    > "${SKEL}/.config/autostart/plank.desktop"

ok "Plank dock configured."

# ─── Configure SDDM login theme ───────────────────────────────────────────────
log "Configuring SDDM login screen..."
git clone --depth=1 https://framagit.org/MarianArlt/sddm-sugar-candy.git \
    /usr/share/sddm/themes/canvera-login 2>/dev/null && {

    printf '[General]\nBackground="Background.png"\nFullBlur=true\nBlurRadius=60\nFormPosition="center"\nMainColor="#ffffff"\nAccentColor="#4f8ef7"\nBackgroundColor="#1a1a2e"\nRoundCorners=20\nFont="Inter"\nFontSize="15"\nHeaderText="Welcome back"\nHourFormat="hh:mm AP"\nDateFormat="dddd, MMMM d"\n' \
        > /usr/share/sddm/themes/canvera-login/theme.conf

    # Copy wallpaper as login background
    mkdir -p /usr/share/sddm/themes/canvera-login/Backgrounds
    cp "${THEME_DIR}/wallpapers/canvera-dark.png" \
       /usr/share/sddm/themes/canvera-login/Backgrounds/Background.png 2>/dev/null || \
       cp "${THEME_DIR}/wallpapers/canvera-dark.png" \
          /usr/share/sddm/themes/canvera-login/Background.png 2>/dev/null || \
       warn "Wallpaper copy failed — SDDM will use default background."

    printf '[Theme]\nCurrent=canvera-login\nFont=Inter\n' \
        > /etc/sddm.conf.d/canvera-theme.conf

    ok "SDDM login screen configured."
} || {
    warn "SDDM Sugar Candy theme download failed — using breeze SDDM theme."
    printf '[Theme]\nCurrent=breeze\nFont=Inter\n' \
        > /etc/sddm.conf.d/canvera-theme.conf
}

# ─── Configure KWin window rules ──────────────────────────────────────────────
log "Configuring window management rules..."
cp /canvera-config/window-manager/kwinrules "${SKEL}/.config/kwinrules" || \
    warn "kwinrules not found — using KWin defaults."
ok "Window rules step complete."

# ─── Dark mode scheduler defaults ────────────────────────────────────────────
log "Configuring dark mode defaults..."
mkdir -p "${SKEL}/.config/canvera"
printf '[DarkMode]\nenabled=true\ndark_start=19:00\nlight_start=07:00\ncurrent_mode=dark\n' \
    > "${SKEL}/.config/canvera/dark-mode.conf"
ok "Dark mode defaults configured."

# ─── Configure Dolphin file manager ──────────────────────────────────────────
log "Pre-configuring Dolphin (Finder-style)..."
mkdir -p "${SKEL}/.config"
cp /canvera-config/apps/dolphin/dolphinrc "${SKEL}/.config/dolphinrc" || \
    warn "dolphinrc not found — using Dolphin defaults."
ok "Dolphin configured."

# ─── Copy wallpapers to system directory ──────────────────────────────────────
log "Installing CanveraOS wallpapers..."
mkdir -p /usr/share/wallpapers/CanveraOS
cp "${THEME_DIR}/wallpapers/canvera-dark.png"  /usr/share/wallpapers/CanveraOS/ 2>/dev/null || warn "Dark wallpaper missing"
cp "${THEME_DIR}/wallpapers/canvera-light.png" /usr/share/wallpapers/CanveraOS/ 2>/dev/null || warn "Light wallpaper missing"
ok "Wallpapers installed."

log "Theme application complete."
