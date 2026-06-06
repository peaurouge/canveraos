#!/usr/bin/env bash
# =============================================================================
# CanveraOS — First Boot Setup Script
# Runs ONCE on first user login after installation.
# Handles: wallpaper, keyboard shortcuts, dock, Dolphin, clipboard manager.
# Completely GUI-based. Zero terminal for end user.
#
# IMPORTANT: Do NOT use 'set -euo pipefail' here.
# Many commands are optional/UI and can fail gracefully.
# Using set -e here would prevent the FIRST_BOOT_MARKER from being written
# if any optional command fails, causing infinite re-runs on every login.
# =============================================================================

FIRST_BOOT_MARKER="${HOME}/.config/canvera/.first-boot-done"
LOG="${HOME}/.local/share/canvera/first-boot.log"

mkdir -p "$(dirname "${LOG}")" "$(dirname "${FIRST_BOOT_MARKER}")"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "${LOG}"; }

# Exit immediately if already completed
[[ -f "${FIRST_BOOT_MARKER}" ]] && exit 0

log "Starting CanveraOS first boot setup..."

# ─── KDE command compatibility (Plasma 5 vs 6) ────────────────────────────────
# KDE6 uses kwriteconfig6 and balooctl6; KDE5 uses kwriteconfig5 and balooctl.
# This wrapper tries both and silently succeeds either way.
kwriteconfig() {
    if command -v kwriteconfig6 &>/dev/null; then
        kwriteconfig6 "$@" 2>/dev/null || true
    elif command -v kwriteconfig5 &>/dev/null; then
        kwriteconfig5 "$@" 2>/dev/null || true
    fi
}

balooctl_cmd() {
    if command -v balooctl6 &>/dev/null; then
        balooctl6 "$@" 2>/dev/null || true
    elif command -v balooctl &>/dev/null; then
        balooctl "$@" 2>/dev/null || true
    fi
}

# ─── Wait for desktop to be ready ─────────────────────────────────────────────
sleep 5

# ─── Welcome dialog ───────────────────────────────────────────────────────────
zenity --info \
    --title="Welcome to CanveraOS" \
    --text="<b>Welcome to CanveraOS!</b>\n\nWe'll take a moment to finish setting up your creative workspace.\n\nThis will only take a minute." \
    --width=420 --height=200 \
    --ok-label="Let's Go" \
    2>/dev/null || true

# ─── Dolphin — Finder-style sidebar (remove system disks) ──────────────────────────
log "Configuring Dolphin sidebar (macOS Finder style)..."
mkdir -p "${HOME}/.config"
# Use /etc/skel/.config/dolphinrc (permanent, installed during build)
# Do NOT use /canvera-config/ — that directory is DELETED during ISO build cleanup
if [[ -f /etc/skel/.config/dolphinrc ]]; then
    cp /etc/skel/.config/dolphinrc "${HOME}/.config/dolphinrc"
fi
# Setup Dolphin places (hides system partitions, shows Finder-style locations)
bash /usr/local/bin/canvera-setup-dolphin-places 2>/dev/null || true

# ─── Apply wallpaper ──────────────────────────────────────────────────────────
# Wallpapers are already at /usr/share/wallpapers/CanveraOS/ from the build.
# No sudo needed — plasma-apply-wallpaperimage works as the current user.
log "Applying wallpaper..."
HOUR=$(date +%H)
if [[ ${HOUR} -ge 19 || ${HOUR} -lt 7 ]]; then
    plasma-apply-wallpaperimage "/usr/share/wallpapers/CanveraOS/canvera-dark.png" 2>/dev/null || true
else
    plasma-apply-wallpaperimage "/usr/share/wallpapers/CanveraOS/canvera-light.png" 2>/dev/null || true
fi

# ─── Configure macOS keyboard shortcuts ───────────────────────────────────────
log "Configuring macOS-compatible keyboard shortcuts..."

# Spotlight / Command Palette
kwriteconfig --file kglobalshortcutsrc --group plasmashell \
    --key "_launch0" "Meta+Space,none,Open Krunner"

# Window management
kwriteconfig --file kglobalshortcutsrc --group kwin \
    --key "Walk Through Windows" "Meta+Tab,Alt+Tab,Walk Through Windows"
kwriteconfig --file kglobalshortcutsrc --group kwin \
    --key "Walk Through Windows (Reverse)" "Meta+Shift+Tab,Alt+Shift+Tab,Walk Through Windows (Reverse)"
kwriteconfig --file kglobalshortcutsrc --group kwin \
    --key "Window Close" "Meta+W,Alt+F4,Close Window"
kwriteconfig --file kglobalshortcutsrc --group kwin \
    --key "Window Minimize" "Meta+M,none,Minimize Window"
kwriteconfig --file kglobalshortcutsrc --group kwin \
    --key "Window Maximize" "Meta+Ctrl+F,none,Maximize Window"

# Virtual desktops (Mission Control equivalent)
kwriteconfig --file kglobalshortcutsrc --group kwin \
    --key "Switch One Desktop to the Left" "Meta+Ctrl+Left,Ctrl+F3,Switch One Desktop to the Left"
kwriteconfig --file kglobalshortcutsrc --group kwin \
    --key "Switch One Desktop to the Right" "Meta+Ctrl+Right,Ctrl+F4,Switch One Desktop to the Right"

# Screenshot (macOS-style)
kwriteconfig --file kglobalshortcutsrc --group org.kde.spectacle.desktop \
    --key "_launch" "Meta+Shift+3,Print,Take Full Screenshot"
kwriteconfig --file kglobalshortcutsrc --group org.kde.spectacle.desktop \
    --key "RectangularRegionScreenGrab" "Meta+Shift+4,none,Capture Rectangular Region"
kwriteconfig --file kglobalshortcutsrc --group org.kde.spectacle.desktop \
    --key "ActiveWindowScreenGrab" "Meta+Shift+5,none,Capture Active Window"

# Lock screen
kwriteconfig --file kglobalshortcutsrc --group ksmserver \
    --key "Lock Session" "Meta+Ctrl+Q,Ctrl+Alt+L,Lock Session"

# Clipboard manager (CopyQ)
kwriteconfig --file kglobalshortcutsrc --group copyq \
    --key "toggle_main_window" "Meta+Shift+V,none,Toggle CopyQ"

# KRunner plugins
kwriteconfig --file krunnerrc --group "Plugins" \
    --key "krunner_applicationsEnabled" "true"
kwriteconfig --file krunnerrc --group "Plugins" \
    --key "krunner_filesEnabled" "true"
kwriteconfig --file krunnerrc --group "Plugins" \
    --key "krunner_bookmarksrunnerEnabled" "true"
kwriteconfig --file krunnerrc --group "Plugins" \
    --key "krunner_recentdocumentsEnabled" "true"

log "Keyboard shortcuts configured."

# ─── Start CopyQ clipboard manager ────────────────────────────────────────────
log "Starting CopyQ clipboard manager..."
mkdir -p "${HOME}/.config/autostart"
printf '[Desktop Entry]\nName=CopyQ Clipboard Manager\nExec=copyq\nIcon=copyq\nTerminal=false\nType=Application\nX-KDE-autostart-after=panel\n' \
    > "${HOME}/.config/autostart/copyq.desktop"
copyq 2>/dev/null &

# ─── Start Plank Dock ─────────────────────────────────────────────────────────
log "Starting Plank dock..."
plank 2>/dev/null &
sleep 2

# ─── Configure dark mode scheduler as user service ────────────────────────────
log "Enabling dark mode scheduler..."
systemctl --user enable canvera-dark-mode.timer 2>/dev/null || true
systemctl --user start canvera-dark-mode.timer 2>/dev/null || true

# ─── Enable Baloo file indexer (instant search) ───────────────────────────────
log "Starting file indexer for instant search..."
balooctl_cmd enable
balooctl_cmd start

# ─── Multi-monitor setup ──────────────────────────────────────────────────────
log "Configuring multi-monitor panel, dock, and refresh rates..."
if [[ -f /usr/local/bin/canvera-multimonitor ]]; then
    bash /usr/local/bin/canvera-multimonitor 2>/dev/null &
fi

# Autostart for future logins
mkdir -p "${HOME}/.config/autostart"
printf '[Desktop Entry]\nName=CanveraOS Multi-Monitor\nComment=Configure panels and dock on all connected monitors\nExec=/usr/local/bin/canvera-multimonitor\nTerminal=false\nType=Application\nX-GNOME-Autostart-enabled=true\nX-GNOME-Autostart-Delay=15\n' \
    > "${HOME}/.config/autostart/canvera-multimonitor.desktop"

# ─── Set up Flathub (system-wide, done here since chroot couldn't) ────────────
log "Setting up Flathub remote..."
# System-wide Flathub (needs root / pkexec — skip silently if not available)
sudo flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
# User Flathub (always works without root)
flatpak remote-add --user --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

# ─── Install Flatpak apps (Telegram, WhatsApp, Organic Maps) ──────────────────
# Run after 60 sec delay to ensure network is fully up
log "Scheduling Flatpak apps installation (60 second delay for network)..."
( sleep 60 && /usr/local/bin/canvera-install-flatpak-apps ) 2>/dev/null &

# ─── Loupedeck CT — add user to plugdev group ─────────────────────────────────
log "Configuring Loupedeck CT device permissions..."
if ! groups "$(whoami)" | grep -q plugdev; then
    pkexec usermod -aG plugdev "$(whoami)" 2>/dev/null && \
        log "Added user to plugdev group for Loupedeck CT access." || \
        log "Could not add to plugdev (will be prompted at first Loupedeck launch)."
fi

# ─── CrossOver license setup ─────────────────────────────────────────────────
log "Prompting CrossOver license setup..."
NEEDS_LICENSE=$(zenity --question \
    --title="CrossOver License" \
    --text="<b>Activate CrossOver</b>\n\nCrossOver enables Adobe apps (Photoshop, Illustrator, Premiere Pro) on CanveraOS.\n\nDo you have a CrossOver license key to enter now?" \
    --ok-label="Yes, Enter License" \
    --cancel-label="Skip for Now" \
    --width=420 --height=220 \
    2>/dev/null; echo $?)

if [[ "${NEEDS_LICENSE}" == "0" ]]; then
    /usr/local/bin/canvera-crossover-license 2>/dev/null || true
fi

# ─── Done ─────────────────────────────────────────────────────────────────────
# Write marker BEFORE showing final dialog so crashes during dialog don't re-run setup
touch "${FIRST_BOOT_MARKER}"
log "First boot setup complete."

zenity --info \
    --title="CanveraOS is Ready" \
    --text="<b>You're all set!</b>\n\nCanveraOS is fully configured and ready to use.\n\n🎨 Adobe apps — click any Adobe icon to install and log in.\n🎬 DaVinci Resolve — install from the dock or Applications.\n⌨️ Press <b>Super+Space</b> for Command Palette (like Spotlight).\n📋 Press <b>Super+Shift+V</b> for Clipboard Manager.\n🎛️ <b>Loupedeck CT</b> — connect via USB, then open from Applications.\n\nEnjoy creating with CanveraOS!" \
    --width=460 --height=300 \
    --ok-label="Start Creating" \
    2>/dev/null || true
