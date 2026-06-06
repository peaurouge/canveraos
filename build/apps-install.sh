#!/usr/bin/env bash
# =============================================================================
# CanveraOS — Applications Installation Script
# Installs applications that can be installed during build via apt.
# Flatpak apps (Telegram, WhatsApp, etc.) are installed on first boot
# via /usr/local/bin/canvera-first-boot which runs after network is up.
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

# ─── Steam + Proton ───────────────────────────────────────────────────────────
log "Installing Steam..."
dpkg --add-architecture i386 || true
apt-get update -qq || true
apt-get install -y steam-installer || warn "Steam install failed — will retry on first boot."
ok "Steam step complete."

# ─── CopyQ Clipboard Manager ──────────────────────────────────────────────────
log "Installing CopyQ clipboard manager..."
apt-get install -y copyq
ok "CopyQ installed."

# ─── Chromium (for PWAs) ──────────────────────────────────────────────────────
log "Installing Chromium for PWA support..."
apt-get install -y chromium-browser 2>/dev/null || \
    apt-get install -y chromium 2>/dev/null || \
    warn "Chromium not found — PWAs will use Firefox."
ok "Browser installed."

# ─── Firefox ──────────────────────────────────────────────────────────────────
log "Installing Firefox..."
apt-get install -y firefox 2>/dev/null || \
    apt-get install -y firefox-esr 2>/dev/null || \
    warn "Firefox not found."
ok "Firefox step complete."

# ─── VS Code (IDE) ────────────────────────────────────────────────────────────
log "Installing VS Code..."
wget -qO /usr/share/keyrings/microsoft.gpg \
    https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        > /etc/apt/sources.list.d/vscode.list && \
    apt-get update -qq && \
    apt-get install -y code && \
    ok "VS Code installed." || warn "VS Code install failed — skipping."

# ─── DaVinci Resolve ──────────────────────────────────────────────────────────
log "Setting up DaVinci Resolve installer..."
mkdir -p /opt/canvera-apps/resolve

printf '#!/usr/bin/env bash\n# DaVinci Resolve installer launcher\nzenity --info --title="Install DaVinci Resolve" --text="DaVinci Resolve requires a free Blackmagic Design account.\\n\\nClick OK to open the download page in your browser.\\nAfter downloading the .deb file, double-click it to install." --width=400 --height=200\nxdg-open "https://www.blackmagicdesign.com/products/davinciresolve" &\nzenity --info --title="Install DaVinci Resolve" --text="Once downloaded, locate the .deb file in your Downloads folder and double-click it to install." --width=400 --height=200\n' \
    > /usr/local/bin/canvera-install-resolve
chmod +x /usr/local/bin/canvera-install-resolve

printf '[Desktop Entry]\nName=Install DaVinci Resolve\nComment=Download and install DaVinci Resolve video editor\nExec=/usr/local/bin/canvera-install-resolve\nIcon=video-editor\nTerminal=false\nType=Application\nCategories=AudioVideo;Video;\nStartupNotify=true\n' \
    > /usr/share/applications/canvera-install-resolve.desktop
ok "DaVinci Resolve setup ready (downloads on first click)."

# ─── PWA desktop entries (ChatGPT, M365) ───────────────────────────────────────────
log "Creating PWA launchers..."
# Determine best browser for PWAs
if command -v chromium-browser &>/dev/null; then
    BROWSER_CMD="chromium-browser"
elif command -v chromium &>/dev/null; then
    BROWSER_CMD="chromium"
else
    BROWSER_CMD="firefox"
fi

printf '[Desktop Entry]\nName=ChatGPT\nComment=OpenAI ChatGPT - AI Assistant\nExec=%s --app=https://chat.openai.com --class=ChatGPT\nIcon=internet-web-browser\nTerminal=false\nType=Application\nCategories=Network;Utility;\nStartupWMClass=ChatGPT\n' "$BROWSER_CMD" \
    > /usr/share/applications/chatgpt.desktop

printf '[Desktop Entry]\nName=Outlook\nComment=Microsoft Outlook - Email and Calendar\nExec=%s --app=https://outlook.live.com --class=Outlook\nIcon=internet-mail\nTerminal=false\nType=Application\nCategories=Network;Office;Email;\nStartupWMClass=Outlook\n' "$BROWSER_CMD" \
    > /usr/share/applications/outlook-pwa.desktop

printf '[Desktop Entry]\nName=Microsoft Teams\nComment=Microsoft Teams - Collaboration\nExec=%s --app=https://teams.microsoft.com --class=Teams\nIcon=internet-web-browser\nTerminal=false\nType=Application\nCategories=Network;Chat;\nStartupWMClass=Teams\n' "$BROWSER_CMD" \
    > /usr/share/applications/teams-pwa.desktop

printf '[Desktop Entry]\nName=OneDrive\nComment=Microsoft OneDrive - Cloud Storage\nExec=%s --app=https://onedrive.live.com --class=OneDrive\nIcon=folder-remote\nTerminal=false\nType=Application\nCategories=Network;FileManager;\nStartupWMClass=OneDrive\n' "$BROWSER_CMD" \
    > /usr/share/applications/onedrive-pwa.desktop

ok "PWA launchers created."

# ─── Google Antigravity IDE ─────────────────────────────────────────────────
log "Setting up Google Antigravity IDE installer..."
mkdir -p /opt/canvera-apps/antigravity
# Antigravity IDE by Google DeepMind — download installer on first click
printf '#!/usr/bin/env bash\n# Google Antigravity IDE Installer\nANTIGRAVITY_DEB="/tmp/antigravity-ide.deb"\nzenity --info --title="Install Google Antigravity IDE" --text="Downloading Google Antigravity IDE...\n\nThis may take a moment." --width=360 --height=120 --timeout=3 2>/dev/null\nwget -q --show-progress -O "${ANTIGRAVITY_DEB}" \nhttps://antigravity.dev/download/linux/antigravity-latest-amd64.deb" 2>/dev/null || {\n    # Fallback: open download page in browser\n    xdg-open "https://antigravity.dev" 2>/dev/null || true\n    zenity --info --title="Google Antigravity IDE" --text="Could not auto-download.\n\nOpening download page in browser.\nDownload the .deb file and double-click to install." --width=380\n    exit 0\n}\n[[ -f "${ANTIGRAVITY_DEB}" ]] && {\n    pkexec apt-get install -y "${ANTIGRAVITY_DEB}" 2>/dev/null || \n    sudo dpkg -i "${ANTIGRAVITY_DEB}" 2>/dev/null || true\n    rm -f "${ANTIGRAVITY_DEB}"\n    zenity --info --title="Installed" --text="Google Antigravity IDE installed." --width=300\n}\n' > /usr/local/bin/canvera-install-antigravity
chmod +x /usr/local/bin/canvera-install-antigravity
printf '[Desktop Entry]\nName=Google Antigravity IDE\nComment=AI-powered coding assistant by Google DeepMind\nExec=/usr/local/bin/canvera-install-antigravity\nIcon=applications-development\nTerminal=false\nType=Application\nCategories=Development;IDE;\nStartupNotify=true\n' \
    > /usr/share/applications/antigravity-ide.desktop
ok "Google Antigravity IDE setup ready."

# ─── Chillio IPTV Player ────────────────────────────────────────────────────
log "Setting up Chillio IPTV Player..."
# Chillio IPTV — install via Flatpak (requires Flathub, done at first boot)
# The first-boot Flatpak installer handles the actual install.
# Create placeholder .desktop that shows install prompt if Chillio not yet installed.
printf '[Desktop Entry]\nName=Chillio IPTV Player\nComment=Advanced IPTV player with EPG support\nExec=bash -c "flatpak run io.chillio.Chillio 2>/dev/null || (flatpak install -y flathub io.chillio.Chillio && flatpak run io.chillio.Chillio)"\nIcon=multimedia-player\nTerminal=false\nType=Application\nCategories=AudioVideo;Video;\nStartupNotify=true\n' \
    > /usr/share/applications/chillio.desktop
ok "Chillio IPTV setup ready (installs from Flathub on first launch)."

# ─── Flatpak apps first-boot installer ───────────────────────────────────────
# Telegram, WhatsApp, Home Assistant, Organic Maps cannot be installed in
# the build chroot (Flatpak needs a running system with network).
# This script runs ONCE on first boot after Flathub is configured.
log "Creating first-boot Flatpak installer..."
printf '#!/usr/bin/env bash\n# CanveraOS First-Boot Flatpak App Installer\n# Runs once when user first logs in, installs Flatpak apps from Flathub.\nset -euo pipefail\nMARKER="${HOME}/.local/share/canvera/.flatpak-apps-installed"\n[[ -f "${MARKER}" ]] && exit 0\nmkdir -p "$(dirname "${MARKER}")"\nlog() { echo "[FIRSTBOOT] $*"; }\nwarn() { echo "[FIRSTBOOT WARN] $*"; }\n\nlog "Setting up Flathub..."\nflatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true\nflatpak update -y --noninteractive 2>/dev/null || true\n\nlog "Installing Telegram Desktop..."\nflatpak install -y --noninteractive flathub org.telegram.desktop 2>/dev/null || warn "Telegram install failed"\n\nlog "Installing WhatsApp..."\nflatpak install -y --noninteractive flathub io.github.mimbrero.WhatsAppDesktop 2>/dev/null || \\\n    flatpak install -y --noninteractive flathub com.github.eneshecan.WhatsAppForLinux 2>/dev/null || \\\n    warn "WhatsApp install failed"\n\nlog "Installing Organic Maps..."\nflatpak install -y --noninteractive flathub app.organicmaps.desktop 2>/dev/null || warn "Organic Maps install failed"\n\nlog "Installing Home Assistant..."\nflatpak install -y --noninteractive flathub com.cassidyjames.butler 2>/dev/null || warn "Home Assistant install failed"\n\nlog "Installing Chillio IPTV Player..."\nflatpak install -y --noninteractive flathub io.chillio.Chillio 2>/dev/null || warn "Chillio install failed (may not be on Flathub yet)"\n\ntouch "${MARKER}"\nlog "Flatpak apps installation complete."\n' \
    > /usr/local/bin/canvera-install-flatpak-apps
chmod +x /usr/local/bin/canvera-install-flatpak-apps

# Create systemd user service to run Flatpak installer at first graphical login
# Uses ~/.local/share/canvera/ marker (user-writable — can't use /var/lib/ in user services)
mkdir -p /etc/systemd/user
printf '[Unit]\nDescription=CanveraOS First-Boot Flatpak App Installer\nAfter=network-online.target\n\n[Service]\nType=oneshot\nExecStart=/usr/local/bin/canvera-install-flatpak-apps\nRemainAfterExit=yes\nStandardOutput=journal\nStandardError=journal\n\n[Install]\nWantedBy=default.target\n' \
    > /etc/systemd/user/canvera-flatpak-apps.service
systemctl --global enable canvera-flatpak-apps.service 2>/dev/null || true

ok "Flatpak apps will be installed on first boot."

# ─── Workspace Modes switcher ────────────────────────────────────────────────
log "Installing Workspace Modes switcher..."
cp /canvera-scripts/workspace-modes.sh /usr/local/bin/canvera-workspace-modes 2>/dev/null || {
    warn "workspace-modes.sh not found — creating placeholder..."
    printf '#!/usr/bin/env bash\necho "Workspace Modes: feature coming in next update"\n' \
        > /usr/local/bin/canvera-workspace-modes
}
chmod +x /usr/local/bin/canvera-workspace-modes

printf '[Desktop Entry]\nName=Workspace Modes\nComment=Switch between Video Edit, Design, and Writing workspace layouts\nExec=/usr/local/bin/canvera-workspace-modes --gui\nIcon=view-grid\nTerminal=false\nType=Application\nCategories=Settings;\nStartupNotify=false\n' \
    > /usr/share/applications/workspace-modes.desktop

# ─── Custom desktop entries ───────────────────────────────────────────────────
log "Installing custom desktop entries..."
if [[ -d /canvera-config/apps/desktop ]]; then
    cp /canvera-config/apps/desktop/*.desktop /usr/share/applications/ 2>/dev/null || true
fi
update-desktop-database /usr/share/applications/
ok "Desktop entries updated."

ok "All applications installed."
