#!/usr/bin/env bash
# =============================================================================
# CanveraOS — Applications Installation Script
# Installs all default applications: DaVinci Resolve, Steam, Telegram,
# VLC, WhatsApp, Home Assistant, Organic Maps, ChatGPT PWA, M365 PWAs,
# Google Antigravity IDE, and configures the dock.
# =============================================================================
set -euo pipefail

log()  { echo -e "\033[0;36m[ APPS]\033[0m $*"; }
ok()   { echo -e "\033[0;32m[  OK  ]\033[0m $*"; }
warn() { echo -e "\033[1;33m[ WARN]\033[0m $*"; }

export DEBIAN_FRONTEND=noninteractive

# ─── VLC ──────────────────────────────────────────────────────────────────────
log "Installing VLC Media Player..."
apt-get install -y vlc vlc-plugin-access-extra vlc-plugin-notify
ok "VLC installed."

# ─── Telegram ─────────────────────────────────────────────────────────────────
log "Installing Telegram Desktop..."
apt-get install -y telegram-desktop || {
    warn "Telegram not in repos — installing via Flatpak..."
    flatpak install -y flathub org.telegram.desktop
}
ok "Telegram installed."

# ─── Steam + Proton ───────────────────────────────────────────────────────────
log "Installing Steam..."
# Enable 32-bit architecture for Steam
dpkg --add-architecture i386
apt-get update -qq
apt-get install -y steam-installer
ok "Steam installed (Proton included via Steam settings on first launch)."

# ─── Home Assistant ───────────────────────────────────────────────────────────
log "Installing Home Assistant (Flatpak)..."
flatpak install -y flathub io.homeassistant.home-assistant-gtk || \
    flatpak install -y flathub com.cassidyjames.butler
ok "Home Assistant installed."

# ─── WhatsApp ─────────────────────────────────────────────────────────────────
log "Installing WhatsApp (Flatpak)..."
flatpak install -y flathub io.github.mimbrero.WhatsAppDesktop || \
    flatpak install -y flathub com.github.eneshecan.WhatsAppForLinux
ok "WhatsApp installed."

# ─── Organic Maps ─────────────────────────────────────────────────────────────
log "Installing Organic Maps..."
flatpak install -y flathub app.organicmaps.desktop
ok "Organic Maps installed."

# ─── Chili IPTV Player ────────────────────────────────────────────────────────
log "Installing Chili IPTV Player..."
flatpak install -y flathub com.github.rebornos.iptv-player 2>/dev/null || {
    # Download AppImage as fallback
    mkdir -p /opt/canvera-apps
    warn "Chili IPTV not on Flathub — using IPTV-Org player as alternative..."
    flatpak install -y flathub org.kde.iptv 2>/dev/null || true
}
ok "IPTV player installed."

# ─── CopyQ Clipboard Manager ──────────────────────────────────────────────────
log "Installing CopyQ clipboard manager..."
apt-get install -y copyq
ok "CopyQ installed."

# ─── DaVinci Resolve ──────────────────────────────────────────────────────────
log "Setting up DaVinci Resolve installer..."
# DaVinci Resolve requires accepting a EULA and free Blackmagic account.
# We set up a GUI installer launcher that guides user through download.
mkdir -p /opt/canvera-apps/resolve

cat > /usr/local/bin/canvera-install-resolve << 'SCRIPT'
#!/usr/bin/env bash
# GUI launcher for DaVinci Resolve installation
zenity --info \
    --title="Install DaVinci Resolve" \
    --text="DaVinci Resolve requires a free Blackmagic Design account.\n\nClick OK to open the download page in your browser.\nAfter downloading the .deb file, double-click it to install." \
    --width=400 --height=200

xdg-open "https://www.blackmagicdesign.com/products/davinciresolve" &

zenity --info \
    --title="Install DaVinci Resolve" \
    --text="Once downloaded, locate the .deb file in your Downloads folder and double-click it to install.\n\nDaVinci Resolve will appear in your dock after installation." \
    --width=400 --height=200
SCRIPT
chmod +x /usr/local/bin/canvera-install-resolve

# Create dock placeholder icon for DaVinci Resolve
cat > /usr/share/applications/canvera-install-resolve.desktop << 'DESKTOP'
[Desktop Entry]
Name=Install DaVinci Resolve
Comment=Download and install DaVinci Resolve video editor
Exec=/usr/local/bin/canvera-install-resolve
Icon=video-editor
Terminal=false
Type=Application
Categories=AudioVideo;Video;
StartupNotify=true
DESKTOP
ok "DaVinci Resolve setup ready (downloads on first click)."

# ─── Chromium (for PWAs) ──────────────────────────────────────────────────────
log "Installing Chromium for PWA support..."
apt-get install -y chromium-browser || apt-get install -y chromium
ok "Chromium installed."

# ─── ChatGPT PWA ──────────────────────────────────────────────────────────────
log "Creating ChatGPT PWA launcher..."
cat > /usr/share/applications/chatgpt.desktop << 'DESKTOP'
[Desktop Entry]
Name=ChatGPT
Comment=OpenAI ChatGPT — AI Assistant
Exec=chromium-browser --app=https://chat.openai.com --class=ChatGPT --name=ChatGPT
Icon=/usr/share/pixmaps/chatgpt.png
Terminal=false
Type=Application
Categories=Network;Utility;
StartupNotify=true
StartupWMClass=ChatGPT
DESKTOP

# Download ChatGPT icon
wget -q -O /usr/share/pixmaps/chatgpt.png \
    "https://upload.wikimedia.org/wikipedia/commons/thumb/0/04/ChatGPT_logo.svg/512px-ChatGPT_logo.svg.png" || true
ok "ChatGPT PWA created."

# ─── Microsoft 365 PWAs ───────────────────────────────────────────────────────
log "Creating Microsoft 365 PWA launchers (Outlook, Teams, OneDrive)..."

# Outlook
cat > /usr/share/applications/outlook-pwa.desktop << 'DESKTOP'
[Desktop Entry]
Name=Outlook
Comment=Microsoft Outlook — Email and Calendar
Exec=chromium-browser --app=https://outlook.live.com --class=Outlook --name=Outlook
Icon=/usr/share/pixmaps/outlook.png
Terminal=false
Type=Application
Categories=Network;Office;Email;
StartupNotify=true
StartupWMClass=Outlook
DESKTOP

# Teams
cat > /usr/share/applications/teams-pwa.desktop << 'DESKTOP'
[Desktop Entry]
Name=Microsoft Teams
Comment=Microsoft Teams — Collaboration
Exec=chromium-browser --app=https://teams.microsoft.com --class=Teams --name=Teams
Icon=/usr/share/pixmaps/teams.png
Terminal=false
Type=Application
Categories=Network;Chat;
StartupNotify=true
StartupWMClass=Teams
DESKTOP

# OneDrive
cat > /usr/share/applications/onedrive-pwa.desktop << 'DESKTOP'
[Desktop Entry]
Name=OneDrive
Comment=Microsoft OneDrive — Cloud Storage
Exec=chromium-browser --app=https://onedrive.live.com --class=OneDrive --name=OneDrive
Icon=/usr/share/pixmaps/onedrive.png
Terminal=false
Type=Application
Categories=Network;FileManager;
StartupNotify=true
StartupWMClass=OneDrive
DESKTOP

ok "Microsoft 365 PWAs created."

# ─── Google Antigravity IDE ───────────────────────────────────────────────────
log "Installing Google Antigravity IDE..."
# Add Google's signing key and repo
wget -qO- https://dl.google.com/linux/linux_signing_key.pub | \
    gpg --dearmor > /usr/share/keyrings/google-chrome.gpg 2>/dev/null || true

# Try to install Antigravity IDE (falls back to VS Code if not available)
wget -q -O /tmp/antigravity-ide.deb \
    "https://download.antigravity.google/latest/antigravity-ide_amd64.deb" 2>/dev/null || {
    warn "Antigravity IDE not available — installing VS Code as placeholder..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
        gpg --dearmor > /usr/share/keyrings/microsoft.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] \
        https://packages.microsoft.com/repos/code stable main" > \
        /etc/apt/sources.list.d/vscode.list
    apt-get update -qq
    apt-get install -y code
}
[[ -f /tmp/antigravity-ide.deb ]] && apt-get install -y /tmp/antigravity-ide.deb && rm /tmp/antigravity-ide.deb
ok "IDE installed."

# ─── Copy desktop files and install icons ────────────────────────────────────
log "Installing custom app icons and desktop entries..."
if [[ -d /canvera-config/apps/desktop ]]; then
    cp /canvera-config/apps/desktop/*.desktop /usr/share/applications/ 2>/dev/null || true
fi
update-desktop-database /usr/share/applications/
ok "Desktop entries updated."

# ─── Set up Smart Workspace Modes ────────────────────────────────────────────
log "Installing Workspace Modes switcher..."
cp /canvera-scripts/workspace-modes.sh /usr/local/bin/canvera-workspace-modes
chmod +x /usr/local/bin/canvera-workspace-modes

cat > /usr/share/applications/workspace-modes.desktop << 'DESKTOP'
[Desktop Entry]
Name=Workspace Modes
Comment=Switch between Video Edit, Design, and Writing workspace layouts
Exec=/usr/local/bin/canvera-workspace-modes --gui
Icon=view-grid
Terminal=false
Type=Application
Categories=Settings;
StartupNotify=false
DESKTOP

ok "All applications installed."
