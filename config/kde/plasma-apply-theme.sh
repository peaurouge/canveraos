#!/usr/bin/env bash
# =============================================================================
# CanveraOS — KDE Plasma Theme Application Script
# Installs and activates the complete CanveraOS visual identity:
#   - Custom CanveraOS color schemes (true macOS Tahoe palette)
#   - Custom CanveraOS Look and Feel package (Global Theme)
#   - Custom CanveraOS icon theme (wrapper over WhiteSur macOS icons)
#   - Custom CanveraOS Plasma shell theme (renamed from WhiteSur)
#   - Kvantum glassmorphism widget style
#   - ONE top menu bar (macOS-style), NO bottom taskbar
#   - Plank dock (macOS-style bottom dock)
#   - Window buttons LEFT (traffic lights): Close Minimize Maximize
#   - Inter font system-wide
# =============================================================================
set -euo pipefail

log() { echo -e "\033[0;36m[THEME]\033[0m $*"; }
ok()  { echo -e "\033[0;32m[  OK  ]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[ WARN ]\033[0m $*"; }

THEME_DIR="/canvera-theme"
SKEL="/etc/skel"

# ─── 1. Install wallpapers FIRST ─────────────────────────────────────────────
log "Installing CanveraOS wallpapers..."
mkdir -p /usr/share/wallpapers/CanveraOS
cp "${THEME_DIR}/wallpapers/canvera-dark.png"  /usr/share/wallpapers/CanveraOS/ 2>/dev/null \
    || warn "Dark wallpaper missing"
cp "${THEME_DIR}/wallpapers/canvera-light.png" /usr/share/wallpapers/CanveraOS/ 2>/dev/null \
    || warn "Light wallpaper missing"
cp "${THEME_DIR}/wallpapers/canvera-dark.png"  /usr/share/backgrounds/ 2>/dev/null || true
cp "${THEME_DIR}/wallpapers/canvera-light.png" /usr/share/backgrounds/ 2>/dev/null || true
ok "Wallpapers installed."

# ─── 2. Install Kvantum glassmorphism theme ───────────────────────────────────
log "Installing CanveraOS Kvantum theme (frosted glass)..."
mkdir -p /usr/share/Kvantum/CanveraOS
cp "${THEME_DIR}/kvantum/CanveraOS.kvconfig" /usr/share/Kvantum/CanveraOS/ \
    || warn "CanveraOS.kvconfig missing"
cp "${THEME_DIR}/kvantum/CanveraOS.svg"      /usr/share/Kvantum/CanveraOS/ \
    || warn "CanveraOS.svg missing"
ok "Kvantum theme installed."

# ─── 3. Install CanveraOS color schemes ──────────────────────────────────────
log "Installing CanveraOS color schemes (true macOS Tahoe palette)..."
mkdir -p /usr/share/color-schemes
# These appear in System Settings → Appearance → Colors as "CanveraOS Dark/Light"
cp "${THEME_DIR}/plasma/CanveraOS.colors"     /usr/share/color-schemes/ \
    || warn "CanveraOS.colors missing"
cp "${THEME_DIR}/plasma/CanveraOSDark.colors" /usr/share/color-schemes/ \
    || warn "CanveraOSDark.colors missing"
ok "Color schemes installed."

# ─── 4. Install CanveraOS Look and Feel package ───────────────────────────────
log "Installing CanveraOS Global Theme (Look and Feel package)..."
# This makes System Settings → Appearance → Global Theme show "CanveraOS"
mkdir -p /usr/share/plasma/look-and-feel/
cp -r "${THEME_DIR}/plasma/look-and-feel/org.canveraos.canveraos" \
      /usr/share/plasma/look-and-feel/ \
    || warn "Look and Feel package missing — System Settings won't show CanveraOS theme"
ok "CanveraOS Global Theme installed."

# ─── 5. Install CanveraOS icon theme ──────────────────────────────────────────
log "Installing CanveraOS icon theme (macOS Tahoe-style rounded icons)..."
mkdir -p /usr/share/icons/CanveraOS
cp "${THEME_DIR}/icons/CanveraOS/index.theme" /usr/share/icons/CanveraOS/ \
    || warn "CanveraOS icon index.theme missing"
# Generate icon theme cache
gtk-update-icon-cache -f /usr/share/icons/CanveraOS 2>/dev/null || true
ok "CanveraOS icon theme installed."

# ─── 6. Install WhiteSur macOS-style icons (base for CanveraOS icons) ─────────
log "Installing WhiteSur icon theme (macOS Tahoe-style icons base)..."
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git \
    /tmp/whitesur-icons 2>/dev/null && {
    cd /tmp/whitesur-icons
    bash install.sh -t default -d /usr/share/icons 2>/dev/null || true
    bash install.sh -t dark   -d /usr/share/icons 2>/dev/null || true
    cd / && rm -rf /tmp/whitesur-icons
    # Regenerate CanveraOS icon cache after WhiteSur is installed
    gtk-update-icon-cache -f /usr/share/icons/CanveraOS 2>/dev/null || true
    ok "WhiteSur icon theme installed (CanveraOS icons inherit from it)."
} || warn "WhiteSur icon theme download failed — icons will fall back to Papirus."

# Papirus as secondary fallback (also macOS-style, available in repos)
apt-get install -y papirus-icon-theme 2>/dev/null || true

# ─── 7. Install WhiteSur Plasma shell + rename to CanveraOS ───────────────────
log "Installing WhiteSur Plasma shell theme + renaming to CanveraOS..."
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-kde.git \
    /tmp/whitesur-kde 2>/dev/null && {
    cd /tmp/whitesur-kde
    bash install.sh 2>/dev/null || true
    cd / && rm -rf /tmp/whitesur-kde
    ok "WhiteSur Plasma theme installed."
} || warn "WhiteSur Plasma theme download failed."

# Rename WhiteSur-dark Plasma shell theme → CanveraOS
# This makes System Settings → Appearance → Plasma Style show "CanveraOS"
if [[ -d /usr/share/plasma/desktoptheme/WhiteSur-dark ]]; then
    cp -r /usr/share/plasma/desktoptheme/WhiteSur-dark \
           /usr/share/plasma/desktoptheme/CanveraOS 2>/dev/null || true
    # Update the metadata so System Settings shows "CanveraOS" not "WhiteSur Dark"
    python3 -c "
import json, sys
metafile = '/usr/share/plasma/desktoptheme/CanveraOS/metadata.json'
try:
    with open(metafile) as f:
        m = json.load(f)
    m.setdefault('KPlugin', {})
    m['KPlugin']['Name'] = 'CanveraOS'
    m['KPlugin']['Description'] = 'macOS Tahoe-inspired Plasma shell theme'
    m['KPlugin']['Id'] = 'CanveraOS'
    with open(metafile, 'w') as f:
        json.dump(m, f, indent=4)
except Exception as e:
    sys.exit(0)
" 2>/dev/null || true
    # Override Plasma theme colors with true macOS Tahoe palette
    printf '[Colors:Window]\nBackgroundNormal=28,28,30\nForegroundNormal=255,255,255\n\n[Colors:Button]\nBackgroundNormal=58,58,60\nForegroundNormal=255,255,255\n\n[Colors:Selection]\nBackgroundNormal=10,132,255\nForegroundNormal=255,255,255\n\n[Colors:View]\nBackgroundNormal=44,44,46\nForegroundNormal=255,255,255\n\n[Colors:Tooltip]\nBackgroundNormal=58,58,60\nForegroundNormal=255,255,255\n\n[Colors:Complementary]\nBackgroundNormal=17,17,19\nForegroundNormal=255,255,255\n' \
        > /usr/share/plasma/desktoptheme/CanveraOS/colors 2>/dev/null || true
    ok "CanveraOS Plasma shell theme created."
else
    warn "WhiteSur-dark not found — CanveraOS Plasma shell will use default."
fi

# ─── 8. Install window decoration (Klassy — macOS traffic lights) ─────────────
log "Installing Klassy window decoration..."
apt-get install -y klassy 2>/dev/null || {
    warn "Klassy not in repos — building from source..."
    apt-get install -y cmake extra-cmake-modules kdecoration-dev \
                       kf6-kirigami-dev libkf6coreaddons-dev 2>/dev/null || true
    git clone --depth=1 https://github.com/paulmcauley/klassy.git \
        /tmp/klassy 2>/dev/null && {
        cd /tmp/klassy
        cmake -B build -DCMAKE_BUILD_TYPE=Release \
              -DCMAKE_INSTALL_PREFIX=/usr 2>/dev/null || true
        cmake --build build -j$(nproc) 2>/dev/null || true
        cmake --install build 2>/dev/null || true
        cd / && rm -rf /tmp/klassy
    } || warn "Klassy build failed — window buttons will use Breeze decoration."
}
ok "Window decoration step complete."

# ─── 9. Write KDE configuration files to /etc/skel ───────────────────────────
log "Writing CanveraOS KDE configuration to /etc/skel..."
mkdir -p "${SKEL}/.config"
mkdir -p "${SKEL}/.local/share/plasma/plasmoids"

# ── kdeglobals: fonts, colors, icons, widget style ───────────────────────────
printf '[General]
ColorScheme=CanveraOSDark
Name=CanveraOS Dark
shadeSortColumn=true
XftAntialias=true
XftHintStyle=hintslight
XftSubPixel=rgb
fixed=JetBrains Mono,10,-1,5,400,0,0,0,0,0
font=Inter,13,-1,5,400,0,0,0,0,0
menuFont=Inter,13,-1,5,400,0,0,0,0,0
smallestReadableFont=Inter,11,-1,5,400,0,0,0,0,0
taskbarFont=Inter,13,-1,5,400,0,0,0,0,0
toolBarFont=Inter,12,-1,5,400,0,0,0,0,0

[Icons]
Theme=CanveraOS

[KDE]
LookAndFeelPackage=org.canveraos.canveraos
SingleClick=false
AnimationDurationFactor=0.5
widgetStyle=kvantum-dark

[WM]
activeFont=Inter,13,-1,5,600,0,0,0,0,0
' > "${SKEL}/.config/kdeglobals"

# ── kwinrc: window manager — macOS-style behavior + smooth animations ─────────
# CRITICAL: ButtonsOnLeft=XIA = Close(X) Minimize(I) Maximize(A) on LEFT
printf '[Compositing]
AnimationSpeed=3
Backend=OpenGL
Enabled=true
GLCore=true
HiddenPreviews=5
OpenGLIsUnsafe=false
WindowsBlockCompositing=false

[Desktops]
Number=1
Rows=1

[Effect-Blur]
BlurStrength=10
NoiseStrength=1

[Effect-Fade]
InDuration=120
OutDuration=120

[Effect-Scale]
Duration=120

[Plugins]
blurEnabled=true
contrastEnabled=true
kwin4_effect_fadeEnabled=true
kwin4_effect_fadedesktopEnabled=true
kwin4_effect_scaleEnabled=true
magiclampEnabled=true
slideEnabled=true
wobblywindowsEnabled=false

[TabBox]
LayoutName=thumbnail_grid

[Windows]
FocusPolicy=ClickToFocus
TitlebarDoubleClickCommand=Maximize

[org.kde.kdecoration2]
ButtonsOnLeft=XIA
ButtonsOnRight=
library=org.kde.klassy
theme=CanveraOS
' > "${SKEL}/.config/kwinrc"

# ── Plasma panel layout: macOS Tahoe (top bar only, no bottom taskbar) ────────
log "Writing macOS Tahoe panel layout (top bar only)..."
printf '[ActionPlugins][0]
RightButton;NoModifier=org.kde.contextmenu

[Containments][1]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=3
plugin=org.kde.panel
wallpaperplugin=org.kde.image

[Containments][1][Applets][2]
immutability=1
plugin=org.kde.plasma.kickoff

[Containments][1][Applets][2][Configuration]
PreloadWeight=100

[Containments][1][Applets][2][Configuration][General]
icon=canvera-logo
showActionButtonCaptions=false

[Containments][1][Applets][3]
immutability=1
plugin=org.kde.plasma.appmenu

[Containments][1][Applets][3][Configuration][General]
compactView=false

[Containments][1][Applets][4]
immutability=1
plugin=org.kde.plasma.panelspacer

[Containments][1][Applets][5]
immutability=1
plugin=org.kde.plasma.digitalclock

[Containments][1][Applets][5][Configuration][Appearance]
showDate=true
dateFormat=custom
customDateFormat=ddd MMM d
use12hFormat=2
showSeconds=false

[Containments][1][Applets][6]
immutability=1
plugin=org.kde.plasma.panelspacer

[Containments][1][Applets][7]
immutability=1
plugin=org.kde.plasma.systemtray

[Containments][1][General]
AppletOrder=2;3;4;5;6;7

[Containments][2]
activityId=
formfactor=0
immutability=1
lastScreen=0
location=0
plugin=org.kde.plasma.desktop
wallpaperplugin=org.kde.image

[Containments][2][Wallpaper][org.kde.image][General]
Image=/usr/share/wallpapers/CanveraOS/canvera-dark.png
FillMode=2

[ScreenMapping]
itemsOnDisabledScreens=
' > "${SKEL}/.config/plasma-org.kde.plasma.desktop-appletsrc"

# ── plasmashellrc: panel dimensions ──────────────────────────────────────────
printf '[PlasmaViews][Panel 1]
floating=0
panelOpacity=2
thickness=28
' > "${SKEL}/.config/plasmashellrc"

# ── Plasma theme selection ────────────────────────────────────────────────────
printf '[Theme]
name=CanveraOS
' > "${SKEL}/.config/plasmarc"

# ── GTK2 settings ────────────────────────────────────────────────────────────
mkdir -p "${SKEL}/.config/gtk-2.0"
printf 'gtk-theme-name="WhiteSur-Dark"
gtk-icon-theme-name="CanveraOS"
gtk-font-name="Inter 13"
gtk-cursor-theme-name="Breeze"
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-button-images=0
gtk-menu-images=0
' > "${SKEL}/.config/gtk-2.0/gtkrc"

# ── GTK3 settings ────────────────────────────────────────────────────────────
mkdir -p "${SKEL}/.config/gtk-3.0"
printf '[Settings]
gtk-theme-name=WhiteSur-Dark
gtk-icon-theme-name=CanveraOS
gtk-font-name=Inter 13
gtk-cursor-theme-name=Breeze
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
' > "${SKEL}/.config/gtk-3.0/settings.ini"

# ── GTK4 settings ────────────────────────────────────────────────────────────
mkdir -p "${SKEL}/.config/gtk-4.0"
printf '[Settings]
gtk-application-prefer-dark-theme=1
gtk-icon-theme-name=CanveraOS
gtk-font-name=Inter 13
gtk-cursor-theme-name=Breeze
gtk-cursor-theme-size=24
' > "${SKEL}/.config/gtk-4.0/settings.ini"

# ── GTK Global Menu environment (GTK apps show menus in top bar) ──────────────
mkdir -p "${SKEL}/.config/environment.d"
printf 'GTK_MODULES=appmenu-gtk-module
UBUNTU_MENUPROXY=libappmenu.so
' > "${SKEL}/.config/environment.d/canvera-globalmenu.conf"

# ── Kvantum: set CanveraOS as active theme ────────────────────────────────────
mkdir -p "${SKEL}/.config/Kvantum"
printf '[General]
theme=CanveraOS
' > "${SKEL}/.config/Kvantum/kvantum.kvconfig"

ok "KDE CanveraOS configuration written."

# ─── 10. Configure Plank dock ─────────────────────────────────────────────────
log "Configuring Plank dock (macOS-style)..."
mkdir -p "${SKEL}/.config/plank/dock1/launchers"

printf '[PlankDockPreferences]
Theme=Transparent
Position=3
IconSize=56
Offset=0
ZoomEnabled=true
ZoomPercent=150
HideMode=0
Monitor=
PressureSensitivity=5
UnhideDelay=0
HideDelay=0
LockItems=false
ShowDockItem=false
' > "${SKEL}/.config/plank/dock1/settings"

for app in org.kde.dolphin.desktop org.kde.konsole.desktop firefox.desktop \
           code.desktop chromium-browser.desktop; do
    printf '[PlankDockItemPreferences]\nLauncher=file:///usr/share/applications/%s\n' \
        "$app" > "${SKEL}/.config/plank/dock1/launchers/${app}"
done

mkdir -p "${SKEL}/.config/autostart"
printf '[Desktop Entry]
Type=Application
Name=Plank
Exec=plank
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Comment=macOS-style dock for CanveraOS
' > "${SKEL}/.config/autostart/plank.desktop"

ok "Plank dock configured."

# ─── 11. Configure SDDM login theme ──────────────────────────────────────────
log "Configuring SDDM login screen..."
git clone --depth=1 https://framagit.org/MarianArlt/sddm-sugar-candy.git \
    /usr/share/sddm/themes/canvera-login 2>/dev/null && {

    printf '[General]
Background="Background.png"
FullBlur=true
BlurRadius=60
FormPosition="center"
MainColor="#ffffff"
AccentColor="#0A84FF"
BackgroundColor="#1C1C1E"
RoundCorners=20
Font="Inter"
FontSize="15"
HeaderText="CanveraOS"
HourFormat="hh:mm AP"
DateFormat="dddd, MMMM d"
' > /usr/share/sddm/themes/canvera-login/theme.conf

    mkdir -p /usr/share/sddm/themes/canvera-login/Backgrounds
    cp "${THEME_DIR}/wallpapers/canvera-dark.png" \
       /usr/share/sddm/themes/canvera-login/Backgrounds/Background.png 2>/dev/null || \
    cp "${THEME_DIR}/wallpapers/canvera-dark.png" \
       /usr/share/sddm/themes/canvera-login/Background.png 2>/dev/null || \
       warn "SDDM wallpaper copy failed."

    printf '[Theme]\nCurrent=canvera-login\nFont=Inter\n' \
        > /etc/sddm.conf.d/canvera-theme.conf
    ok "SDDM CanveraOS login screen configured."
} || {
    warn "SDDM Sugar Candy theme download failed — using breeze SDDM."
    printf '[Theme]\nCurrent=breeze\n' > /etc/sddm.conf.d/canvera-theme.conf
}

# ─── 12. Configure KWin window rules ─────────────────────────────────────────
log "Configuring window management rules..."
cp /canvera-config/window-manager/kwinrules "${SKEL}/.config/kwinrules" \
    2>/dev/null || warn "kwinrules not found — using KWin defaults."
ok "Window rules step complete."

# ─── 13. Dark mode defaults ───────────────────────────────────────────────────
log "Configuring dark mode defaults..."
mkdir -p "${SKEL}/.config/canvera"
printf '[DarkMode]\nenabled=true\ndark_start=19:00\nlight_start=07:00\ncurrent_mode=dark\n' \
    > "${SKEL}/.config/canvera/dark-mode.conf"
ok "Dark mode defaults configured."

# ─── 14. Configure Dolphin (Finder-style) ────────────────────────────────────
log "Pre-configuring Dolphin (Finder-style)..."
cp /canvera-config/apps/dolphin/dolphinrc "${SKEL}/.config/dolphinrc" \
    2>/dev/null || warn "dolphinrc not found."
ok "Dolphin configured."

# ─── 15. Apply Look and Feel package (activate CanveraOS Global Theme) ────────
log "Activating CanveraOS Global Theme..."
# plasma-apply-lookandfeel applies the LnF package — sets all defaults
plasma-apply-lookandfeel -a org.canveraos.canveraos 2>/dev/null || \
    warn "plasma-apply-lookandfeel failed (normal in chroot — will activate on first boot)."
ok "CanveraOS Global Theme activation attempted."

log "Theme application complete — CanveraOS is fully themed."
