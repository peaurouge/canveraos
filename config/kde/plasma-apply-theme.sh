#!/usr/bin/env bash
# =============================================================================
# CanveraOS — KDE Plasma Theme Application Script
# Applies the full macOS Tahoe-inspired visual theme to KDE Plasma.
# This runs inside the chroot during build — sets system-wide defaults.
# =============================================================================
set -euo pipefail

log() { echo -e "\033[0;36m[THEME]\033[0m $*"; }
ok()  { echo -e "\033[0;32m[  OK  ]\033[0m $*"; }

THEME_DIR="/canvera-theme"
CONFIG_DIR="/canvera-config/kde"
SKEL="/etc/skel"  # Copied to every new user's home directory

# ─── Install Kvantum theme engine ─────────────────────────────────────────────
log "Configuring Kvantum theme engine (glassmorphism)..."
mkdir -p /usr/share/Kvantum/CanveraOS
cp "${THEME_DIR}/kvantum/CanveraOS.kvconfig" /usr/share/Kvantum/CanveraOS/
cp "${THEME_DIR}/kvantum/CanveraOS.svg"      /usr/share/Kvantum/CanveraOS/
ok "Kvantum theme installed."

# ─── Install color schemes ────────────────────────────────────────────────────
log "Installing CanveraOS color schemes (light + dark)..."
mkdir -p /usr/share/color-schemes
cp "${THEME_DIR}/plasma/CanveraOS.colors"     /usr/share/color-schemes/
cp "${THEME_DIR}/plasma/CanveraOSDark.colors" /usr/share/color-schemes/
ok "Color schemes installed."

# ─── Install window decoration (Klassy with macOS traffic lights) ─────────────
log "Installing Klassy window decoration..."
apt-get install -y klassy 2>/dev/null || {
    # Build from source if not in repos
    apt-get install -y cmake extra-cmake-modules kdecoration-dev \
                       kf6-kirigami-dev kwin-dev libkf6coreaddons-dev
    git clone --depth=1 https://github.com/paulmcauley/klassy.git /tmp/klassy
    cd /tmp/klassy
    cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
    cmake --build build -j$(nproc)
    cmake --install build
    cd / && rm -rf /tmp/klassy
}
ok "Klassy window decoration installed."

# ─── Install icon theme (Cupertino / macOS Tahoe style) ───────────────────────
log "Installing macOS Tahoe-style icon theme..."
# WhiteSur icon theme (closest to macOS Tahoe, MIT licensed)
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git /tmp/whitesur-icons
cd /tmp/whitesur-icons
bash install.sh -t default -d /usr/share/icons
cd / && rm -rf /tmp/whitesur-icons
ok "Icon theme installed."

# ─── Install WhiteSur Plasma theme ────────────────────────────────────────────
log "Installing WhiteSur Plasma theme (macOS Tahoe inspired)..."
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-kde.git /tmp/whitesur-kde
cd /tmp/whitesur-kde
bash install.sh
cd / && rm -rf /tmp/whitesur-kde
ok "WhiteSur Plasma theme installed."

# ─── Configure system-wide KDE defaults ──────────────────────────────────────
log "Writing KDE global configuration..."
mkdir -p "${SKEL}/.config"
mkdir -p "${SKEL}/.local/share/plasma/plasmoids"

# kdeglobals — fonts, colors, icons, widget style
cat > "${SKEL}/.config/kdeglobals" << 'EOF'
[General]
ColorScheme=CanveraOSDark
Name=CanveraOS Dark
shadeSortColumn=true
XftAntialias=true
XftHintStyle=hintslight
XftSubPixel=rgb

[Icons]
Theme=WhiteSur-dark

[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
SingleClick=false
AnimationDurationFactor=0.5
widgetStyle=kvantum-dark

[WM]
activeFont=Inter,13,-1,5,50,0,0,0,0,0
EOF

# kwinrc — window manager settings (macOS-style behavior)
cat > "${SKEL}/.config/kwinrc" << 'EOF'
[Compositing]
Backend=OpenGL
GLCore=true
HiddenPreviews=5
OpenGLIsUnsafe=false
WindowsBlockCompositing=false

[Desktops]
Number=1
Rows=1

[Effect-Blur]
BlurStrength=12
NoiseStrength=2

[Effect-wobblywindows]
Drag=85
Stiffness=10
WobbleFactor=15

[ElectricBorders]
Bottom=None
BottomLeft=None
BottomRight=None
Left=None
Right=None
Top=None
TopLeft=None
TopRight=None

[MouseBindings]
CommandActiveTitlebar2=Minimize
CommandActiveTitlebar3=Maximize

[Plugins]
blurEnabled=true
contrastEnabled=true
kwin4_effect_fadeEnabled=true
wobblywindowsEnabled=true
kwin4_effect_dimscreenEnabled=false
diminactiveEnabled=false
slideEnabled=true
minimizeanimationEnabled=true
scaleEnabled=false

[Script-quartertilingEnabled]
enabled=true

[TabBox]
LayoutName=thumbnail_grid

[Windows]
ElectricBorderCornerRatio=0.1
ElectricBorderDelay=150
ElectricBorderMaximize=true
ElectricBorderTiling=true
FocusPolicy=ClickToFocus
RollOverDesktops=false
TitlebarDoubleClickCommand=Maximize
EOF

# plasmashellrc — top bar + dock layout placeholder
# (Actual layout set by Latte Dock config below)
cat > "${SKEL}/.config/plasmashellrc" << 'EOF'
[PlasmaViews][Panel 1]
floating=0
thickness=28

[PlasmaViews][Panel 2]
thickness=72
EOF

ok "KDE configuration written to /etc/skel."

# ─── Configure Latte Dock ─────────────────────────────────────────────────────
log "Configuring Latte Dock (macOS-style dock + top bar)..."
mkdir -p "${SKEL}/.config/latte"

cat > "${SKEL}/.config/lattedockrc" << 'EOF'
[UniversalSettings]
currentLayout=CanveraOS
inAdvancedModeForEditSettings=false
isAvoidingScreenEdgeGaps=false
launchers=
memoryUsage=1
mouseSensitivity=2
version=2

[CanveraOSLayout]
lastUsedActivity=
EOF

# Latte layout file (top bar + bottom dock)
cat > "${SKEL}/.config/latte/CanveraOS.layout.latte" << 'EOF'
[ActionPlugins][0][RightButton;NoModifier]
RightButton;NoModifier=org.kde.contextmenu

[ActionPlugins][1][MiddleButton;NoModifier]
MiddleButton;NoModifier=org.kde.closewindow

[ActionPlugins][1][RightButton;NoModifier]
RightButton;NoModifier=org.kde.contextmenu

[Containments][1]
activityId=
byPassWM=false
dockWindowBehavior=false
enabledBorders=None
formfactor=2
immutability=1
isPreferredForShortcuts=false
lastScreen=0
location=3
maxLength=100
maximumLength=100
minimumLength=40
offset=0
onPrimary=true
plugin=org.kde.latte.containment
tilesHeight=32
view-type=dockView

[Containments][1][Applets][2]
immutability=1
plugin=org.kde.latte.spacer

[Containments][1][Applets][3]
immutability=1
plugin=org.kde.plasma.appmenu

[Containments][1][Applets][4]
immutability=1
plugin=org.kde.latte.spacer

[Containments][1][Applets][5]
immutability=1
plugin=org.kde.plasma.systemtray

[Containments][1][Applets][6]
immutability=1
plugin=org.kde.plasma.digitalclock

[Containments][1][General]
alignment=132
autoDecreaseIconSize=false
autoSizeEnabled=true
backgroundOnlyOnMaximized=true
blurEnabled=true
colorStyle=0
iconSize=22
maxIconSize=22
panelTransparency=80
plasmaBackgroundForPopups=false
screenEdgeMargin=-1
shadowOpacity=50
shadowSize=35
shadowColor=#ff000000
solidBackgroundForMaximized=true
visibilityMode=0

[Containments][2]
activityId=
byPassWM=false
dockWindowBehavior=false
enabledBorders=None
formfactor=2
immutability=1
isPreferredForShortcuts=true
lastScreen=0
location=4
maxLength=100
maximumLength=80
minimumLength=10
offset=0
onPrimary=true
plugin=org.kde.latte.containment
tilesHeight=72
view-type=dockView

[Containments][2][Applets][10]
immutability=1
plugin=org.kde.latte.plasmoid

[Containments][2][Applets][10][Configuration]
immutability=1

[Containments][2][General]
alignment=132
autoDecreaseIconSize=false
autoSizeEnabled=true
blurEnabled=true
colorStyle=0
iconSize=56
maxIconSize=72
panelTransparency=75
plasmaBackgroundForPopups=false
screenEdgeMargin=8
shadowOpacity=60
shadowSize=40
shadowColor=#ff000000
solidBackgroundForMaximized=false
visibilityMode=0
zoomLevel=20
EOF
ok "Latte Dock configured."

# ─── Configure SDDM login theme ───────────────────────────────────────────────
log "Configuring SDDM login screen..."
# Clone Sugar Candy SDDM theme (macOS-style login screen)
git clone --depth=1 https://framagit.org/MarianArlt/sddm-sugar-candy.git \
    /usr/share/sddm/themes/canvera-login

# Customize for CanveraOS
cat > /usr/share/sddm/themes/canvera-login/theme.conf << 'EOF'
[General]
Background="Background.png"
DimBackgroundImage=0.0
ScaleImageCropped=true
ScreenWidth=1920
ScreenHeight=1080
FullBlur=true
PartialBlur=false
BlurRadius=60
HaveFormBackground=false
FormPosition="center"
BackgroundImageHAlignment="center"
BackgroundImageVAlignment="center"
MainColor="#ffffff"
AccentColor="#4f8ef7"
BackgroundColor="#1a1a2e"
OverrideLoginButtonTextColor=""
InterfaceShadowSize=6
InterfaceShadowOpacity=16
RoundCorners=20
ScreenPadding=0
Font="Inter"
FontSize="15"
ForceHideCompletePassword=false
ForceRightToLeft=false
NumberModel="NoSpinner"
Locale=""
HourFormat="hh:mm AP"
DateFormat="dddd, MMMM d"
HeaderText="Welcome back"
TranslateMonth=true
TranslateToNativeLang=true
EOF

# Copy dark wallpaper as SDDM background
cp /canvera-theme/wallpapers/canvera-dark.png \
   /usr/share/sddm/themes/canvera-login/Backgrounds/Background.png

cat > /etc/sddm.conf.d/canvera-theme.conf << 'EOF'
[Theme]
Current=canvera-login
CursorTheme=WhiteSur-cursors
Font=Inter
EOF
ok "SDDM login screen configured."

# ─── Configure KWin window rules ──────────────────────────────────────────────
log "Configuring window management rules..."
cp /canvera-config/window-manager/kwinrules "${SKEL}/.config/kwinrules"
ok "Window rules configured."

# ─── Set up dark mode scheduler ──────────────────────────────────────────────
log "Configuring dark mode files..."
mkdir -p "${SKEL}/.config/canvera"
cat > "${SKEL}/.config/canvera/dark-mode.conf" << 'EOF'
[DarkMode]
enabled=true
dark_start=19:00
light_start=07:00
current_mode=dark
EOF
ok "Dark mode defaults configured."

# ─── Configure Dolphin file manager ──────────────────────────────────────────
log "Pre-configuring Dolphin (Finder-style)..."
mkdir -p "${SKEL}/.config"
cp /canvera-config/apps/dolphin/dolphinrc "${SKEL}/.config/dolphinrc"
ok "Dolphin configured."

log "Theme application complete."
