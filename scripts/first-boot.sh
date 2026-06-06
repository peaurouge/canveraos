#!/usr/bin/env bash
# =============================================================================
# CanveraOS — First Boot Setup Script
# Runs ONCE on first user login after installation.
# Handles: CrossOver license, workspace setup, initial wallpaper,
# dock population, keyboard shortcut configuration.
# Completely GUI-based. Zero terminal for user.
# =============================================================================
set -euo pipefail

FIRST_BOOT_MARKER="${HOME}/.config/canvera/.first-boot-done"
LOG="${HOME}/.local/share/canvera/first-boot.log"

mkdir -p "$(dirname "${LOG}")" "$(dirname "${FIRST_BOOT_MARKER}")"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "${LOG}"; }

[[ -f "${FIRST_BOOT_MARKER}" ]] && exit 0

log "Starting CanveraOS first boot setup..."

# ─── Wait for desktop to be ready ─────────────────────────────────────────────
sleep 5

# ─── Welcome dialog ───────────────────────────────────────────────────────────
zenity --info \
    --title="Welcome to CanveraOS" \
    --text="<b>Welcome to CanveraOS!</b>\n\nWe'll take a moment to finish setting up your creative workspace.\n\nThis will only take a minute." \
    --width=420 --height=200 \
    --ok-label="Let's Go" \
    2>/dev/null || true

# ─── Copy wallpapers to backgrounds ──────────────────────────────────────────
log "Installing wallpapers..."
# Wallpapers installed at /usr/share/wallpapers/CanveraOS/ by plasma-apply-theme.sh
sudo cp /usr/share/wallpapers/CanveraOS/canvera-dark.png \
        /usr/share/backgrounds/canvera-dark.png 2>/dev/null || true
sudo cp /usr/share/wallpapers/CanveraOS/canvera-light.png \
        /usr/share/backgrounds/canvera-light.png 2>/dev/null || true

# ─── Set wallpaper based on current mode ──────────────────────────────────────
HOUR=$(date +%H)
if [[ ${HOUR} -ge 19 || ${HOUR} -lt 7 ]]; then
    plasma-apply-wallpaperimage /usr/share/backgrounds/canvera-dark.png 2>/dev/null || true
else
    plasma-apply-wallpaperimage /usr/share/backgrounds/canvera-light.png 2>/dev/null || true
fi

# ─── Configure macOS keyboard shortcuts ───────────────────────────────────────
log "Configuring macOS-compatible keyboard shortcuts..."
# Map Super key to behave like macOS Command key
kwriteconfig5 --file kglobalshortcutsrc --group plasmashell \
    --key "_launch0" "Meta+Space,none,Open Krunner"
kwriteconfig5 --file kglobalshortcutsrc --group kwin \
    --key "Walk Through Windows" "Meta+Tab,Alt+Tab,Walk Through Windows"
kwriteconfig5 --file kglobalshortcutsrc --group kwin \
    --key "Walk Through Windows (Reverse)" "Meta+Shift+Tab,Alt+Shift+Tab,Walk Through Windows (Reverse)"
kwriteconfig5 --file kglobalshortcutsrc --group kwin \
    --key "Window Close" "Meta+W,Alt+F4,Close Window"
kwriteconfig5 --file kglobalshortcutsrc --group kwin \
    --key "Window Minimize" "Meta+M,none,Minimize Window"
kwriteconfig5 --file kglobalshortcutsrc --group kwin \
    --key "Window Maximize" "Meta+Ctrl+F,none,Maximize Window"
kwriteconfig5 --file kglobalshortcutsrc --group kwin \
    --key "Switch One Desktop to the Left" "Meta+Ctrl+Left,Ctrl+F3,Switch One Desktop to the Left"
kwriteconfig5 --file kglobalshortcutsrc --group kwin \
    --key "Switch One Desktop to the Right" "Meta+Ctrl+Right,Ctrl+F4,Switch One Desktop to the Right"

# Screenshot shortcuts (like macOS)
kwriteconfig5 --file kglobalshortcutsrc --group org.kde.spectacle.desktop \
    --key "_launch" "Meta+Shift+3,Print,Take Full Screenshot"
kwriteconfig5 --file kglobalshortcutsrc --group org.kde.spectacle.desktop \
    --key "RectangularRegionScreenGrab" "Meta+Shift+4,none,Capture Rectangular Region"
kwriteconfig5 --file kglobalshortcutsrc --group org.kde.spectacle.desktop \
    --key "ActiveWindowScreenGrab" "Meta+Shift+5,none,Capture Active Window"

# Lock screen
kwriteconfig5 --file kglobalshortcutsrc --group ksmserver \
    --key "Lock Session" "Meta+Ctrl+Q,Ctrl+Alt+L,Lock Session"

# Clipboard manager (CopyQ)
kwriteconfig5 --file kglobalshortcutsrc --group copyq \
    --key "toggle_main_window" "Meta+Shift+V,none,Toggle CopyQ"

# Command Palette / Spotlight-like search
kwriteconfig5 --file krunnerrc --group "Plugins" \
    --key "krunner_applicationsEnabled" "true"
kwriteconfig5 --file krunnerrc --group "Plugins" \
    --key "krunner_filesEnabled" "true"
kwriteconfig5 --file krunnerrc --group "Plugins" \
    --key "krunner_bookmarksrunnerEnabled" "true"
kwriteconfig5 --file krunnerrc --group "Plugins" \
    --key "krunner_recentdocumentsEnabled" "true"

log "Keyboard shortcuts configured."

# ─── Start Plank Dock ────────────────────────────────────────────────────────
log "Starting Plank dock..."
plank & 2>/dev/null || true
sleep 2

# ─── Start CopyQ in background ────────────────────────────────────────────────
log "Starting CopyQ clipboard manager..."
mkdir -p "${HOME}/.config/autostart"
printf '[Desktop Entry]\nName=CopyQ Clipboard Manager\nExec=copyq\nIcon=copyq\nTerminal=false\nType=Application\nX-KDE-autostart-after=panel\n' \
    > "${HOME}/.config/autostart/copyq.desktop"
copyq & 2>/dev/null || true

# ─── Configure dark mode scheduler as user service ────────────────────────────
log "Enabling dark mode scheduler..."
systemctl --user enable canvera-dark-mode.timer
systemctl --user start canvera-dark-mode.timer

# ─── CrossOver license setup ─────────────────────────────────────────────────
log "Prompting CrossOver license setup..."
NEEDS_LICENSE=$(zenity --question \
    --title="CrossOver License" \
    --text="<b>Activate CrossOver</b>\n\nCrossOver enables Adobe Photoshop, Illustrator, Premiere Pro, After Effects, and Lightroom on CanveraOS.\n\nDo you have a CrossOver license key to enter now?" \
    --ok-label="Yes, Enter License" \
    --cancel-label="Skip for Now" \
    --width=420 --height=220 \
    2>/dev/null; echo $?)

if [[ "${NEEDS_LICENSE}" == "0" ]]; then
    /usr/local/bin/canvera-crossover-license
fi

# ─── Baloo file indexer ───────────────────────────────────────────────────────
log "Starting file indexer for instant search..."
balooctl enable
balooctl start

# ─── Loupedeck CT — add user to plugdev group ─────────────────────────────────
log "Configuring Loupedeck CT device permissions..."
# Loupedeck CT requires plugdev group membership for USB HID access
if ! groups "$(whoami)" | grep -q plugdev; then
    pkexec usermod -aG plugdev "$(whoami)" 2>/dev/null && \
        log "Added user to plugdev group for Loupedeck CT access." || \
        log "Could not add to plugdev (will be prompted at first Loupedeck launch)."
fi

# ─── Done ─────────────────────────────────────────────────────────────────────
touch "${FIRST_BOOT_MARKER}"
log "First boot setup complete."

zenity --info \
    --title="CanveraOS is Ready" \
    --text="<b>You're all set!</b>\n\nCanveraOS is fully configured and ready to use.\n\n🎨 Adobe apps are ready — click any Adobe icon to install and log in.\n🎬 DaVinci Resolve can be installed from the dock.\n⌨️ Press <b>Super+Space</b> to open the Command Palette.\n📋 Press <b>Super+Shift+V</b> for the Clipboard Manager.\n🎛️ <b>Loupedeck CT</b> — permissions configured; connect via USB, then open from Applications.\n\nEnjoy creating with CanveraOS!" \
    --width=460 --height=300 \
    --ok-label="Start Creating" \
    2>/dev/null || true
