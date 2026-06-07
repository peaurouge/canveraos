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

# ─── Base System, Codecs & UI Dependencies ────────────────────────────────────
log "Installing Base Utilities, Professional Codecs, and UI Dependencies..."
apt-get update -qq || true
# Codecs for creative professionals (HEVC, ProRes, RAW, AV1) + imagemagick for Quick Actions
apt-get install -y ubuntu-restricted-extras ffmpeg imagemagick \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav \
    heif-gdk-pixbuf heif-thumbnailer webp libavcodec-extra x264 x265
# UI and Script Dependencies (Dock, GUI prompts, window management)
apt-get install -y plank zenity xdotool wmctrl x11-utils qdbus unzip wget curl git jq
ok "Codecs and base utilities installed."

# ─── VLC ──────────────────────────────────────────────────────────────────────
log "Installing VLC Media Player..."
apt-get install -y vlc  # Core VLC — mandatory, always exists
apt-get install -y vlc-plugin-access-extra vlc-plugin-notify 2>/dev/null || \
    warn "Some VLC plugins not in Noble repos — VLC still works, extra plugins may be missing."
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

# ─── Runtime browser detector ─────────────────────────────────────────────────
log "Creating runtime browser detector..."
printf '#!/usr/bin/env bash
for BROWSER in chromium-browser chromium google-chrome-stable google-chrome firefox-esr firefox; do
    command -v "${BROWSER}" &>/dev/null && echo "${BROWSER}" && exit 0
done
echo "firefox"
' > /usr/local/bin/canvera-browser-detect
chmod +x /usr/local/bin/canvera-browser-detect

# Generic PWA launcher
printf '#!/usr/bin/env bash
URL="$1"
CLASS="${2:-PWA}"
APPNAME="${3:-Web App}"
BROWSER=$(/usr/local/bin/canvera-browser-detect)
if ! ping -c1 -W3 8.8.8.8 &>/dev/null; then
    zenity --error --title="${APPNAME}" --text="<b>No internet connection.</b>\n\nPlease connect to the internet and try again." --width=340 2>/dev/null || true
    exit 1
fi
if [[ "${BROWSER}" == "chromium"* ]] || [[ "${BROWSER}" == "google-chrome"* ]]; then
    exec "${BROWSER}" --app="${URL}" --class="${CLASS}" 2>/dev/null
else
    exec "${BROWSER}" "${URL}" 2>/dev/null
fi
' > /usr/local/bin/canvera-pwa
chmod +x /usr/local/bin/canvera-pwa
ok "Runtime browser detector created."

# ─── DaVinci Resolve ──────────────────────────────────────────────────────────
log "Setting up DaVinci Resolve installer..."
mkdir -p /opt/canvera-apps/resolve
printf '#!/usr/bin/env bash
if ! ping -c1 -W3 8.8.8.8 &>/dev/null; then
    zenity --error --title="DaVinci Resolve" --text="<b>No internet connection.</b>\n\nPlease connect to the internet to download DaVinci Resolve." --width=380 2>/dev/null || true
    exit 1
fi
zenity --info --title="Install DaVinci Resolve" --text="<b>DaVinci Resolve</b> requires a free Blackmagic Design account.\n\nClick OK to open the download page.\nAfter downloading the .deb file, double-click it to install." --width=420 --ok-label="Open Download Page" 2>/dev/null || true
xdg-open "https://www.blackmagicdesign.com/products/davinciresolve" &
' > /usr/local/bin/canvera-install-resolve
chmod +x /usr/local/bin/canvera-install-resolve

printf '[Desktop Entry]\nName=Install DaVinci Resolve\nComment=Download and install DaVinci Resolve video editor\nExec=/usr/local/bin/canvera-install-resolve\nIcon=video-editor\nTerminal=false\nType=Application\nCategories=AudioVideo;Video;\nStartupNotify=true\n' \
    > /usr/share/applications/canvera-install-resolve.desktop
ok "DaVinci Resolve setup ready."

# ─── PWA desktop entries ──────────────────────────────────────────────────────
log "Creating PWA launchers..."
# ChatGPT
printf '[Desktop Entry]\nName=ChatGPT\nComment=OpenAI ChatGPT - AI Assistant\nExec=/usr/local/bin/canvera-pwa https://chat.openai.com ChatGPT ChatGPT\nIcon=internet-web-browser\nTerminal=false\nType=Application\nCategories=Network;Utility;\nStartupWMClass=ChatGPT\n' > /usr/share/applications/chatgpt.desktop
# Outlook
printf '[Desktop Entry]\nName=Outlook\nComment=Microsoft Outlook\nExec=/usr/local/bin/canvera-pwa https://outlook.live.com Outlook Outlook\nIcon=internet-mail\nTerminal=false\nType=Application\nCategories=Network;Office;Email;\nStartupWMClass=Outlook\n' > /usr/share/applications/outlook-pwa.desktop
# Teams
printf '[Desktop Entry]\nName=Microsoft Teams\nComment=Microsoft Teams\nExec=/usr/local/bin/canvera-pwa https://teams.microsoft.com Teams "Microsoft Teams"\nIcon=internet-web-browser\nTerminal=false\nType=Application\nCategories=Network;Chat;\nStartupWMClass=Teams\n' > /usr/share/applications/teams-pwa.desktop
# OneDrive
printf '[Desktop Entry]\nName=OneDrive\nComment=Microsoft OneDrive\nExec=/usr/local/bin/canvera-pwa https://onedrive.live.com OneDrive OneDrive\nIcon=folder-remote\nTerminal=false\nType=Application\nCategories=Network;FileManager;\nStartupWMClass=OneDrive\n' > /usr/share/applications/onedrive-pwa.desktop
ok "PWA launchers created."

# ─── Google Antigravity IDE ───────────────────────────────────────────────────
log "Setting up Google Antigravity IDE installer..."
mkdir -p /opt/canvera-apps/antigravity
printf '#!/usr/bin/env bash
ANTIGRAVITY_DEB="/tmp/antigravity-ide.deb"
ANTIGRAVITY_URL="https://antigravity.dev/download/linux/antigravity-latest-amd64.deb"
if ! ping -c1 -W3 8.8.8.8 &>/dev/null; then
    zenity --error --title="Google Antigravity IDE" --text="<b>No internet connection.</b>" --width=360 2>/dev/null || true
    exit 1
fi
zenity --info --title="Installing Google Antigravity IDE" --text="Downloading Google Antigravity IDE...\n\nThis may take a moment." --width=360 --timeout=3 2>/dev/null || true
wget -q --show-progress -O "${ANTIGRAVITY_DEB}" "${ANTIGRAVITY_URL}" 2>/dev/null || {
    xdg-open "https://antigravity.dev" 2>/dev/null || true
    zenity --info --title="Google Antigravity IDE" --text="Could not auto-download.\n\nOpening download page in browser." --width=380 2>/dev/null || true
    exit 0
}
if [[ -f "${ANTIGRAVITY_DEB}" ]]; then
    pkexec apt-get install -y "${ANTIGRAVITY_DEB}" 2>/dev/null || sudo dpkg -i "${ANTIGRAVITY_DEB}" 2>/dev/null || true
    rm -f "${ANTIGRAVITY_DEB}"
    zenity --info --title="Installed" --text="<b>Google Antigravity IDE installed successfully!</b>" --width=300 2>/dev/null || true
fi
' > /usr/local/bin/canvera-install-antigravity
chmod +x /usr/local/bin/canvera-install-antigravity
printf '[Desktop Entry]\nName=Google Antigravity IDE\nComment=AI-powered coding assistant\nExec=/usr/local/bin/canvera-install-antigravity\nIcon=applications-development\nTerminal=false\nType=Application\nCategories=Development;IDE;\nStartupNotify=true\n' > /usr/share/applications/antigravity-ide.desktop
ok "Google Antigravity IDE setup ready."

# ─── Chillio IPTV Player ──────────────────────────────────────────────────────
log "Setting up Chillio IPTV Player..."
printf '[Desktop Entry]\nName=Chillio IPTV\nComment=Advanced IPTV player with EPG support\nExec=/usr/local/bin/canvera-launch-chillio\nIcon=multimedia-player\nTerminal=false\nType=Application\nCategories=AudioVideo;Video;\nStartupNotify=true\n' > /usr/share/applications/chillio.desktop
printf '#!/usr/bin/env bash
if flatpak list 2>/dev/null | grep -q "io.chillio"; then
    exec flatpak run io.chillio.Chillio
fi
if ! ping -c1 -W3 8.8.8.8 &>/dev/null; then
    zenity --error --title="Chillio IPTV" --text="<b>No internet connection.</b>" --width=360 2>/dev/null || true
    exit 1
fi
zenity --question --title="Install Chillio IPTV" --text="<b>Chillio IPTV</b> is not installed yet.\n\nWould you like to install it now?" --ok-label="Install" --cancel-label="Cancel" --width=380 2>/dev/null || exit 0
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
flatpak install -y --noninteractive flathub io.chillio.Chillio 2>/dev/null && exec flatpak run io.chillio.Chillio || zenity --error --title="Chillio IPTV" --text="Installation failed." --width=320 2>/dev/null || true
' > /usr/local/bin/canvera-launch-chillio
chmod +x /usr/local/bin/canvera-launch-chillio
ok "Chillio IPTV setup ready."

# ─── Flatpak apps first-boot installer ────────────────────────────────────────
log "Creating first-boot Flatpak installer..."
printf '#!/usr/bin/env bash
MARKER="${HOME}/.local/share/canvera/.flatpak-apps-installed"
[[ -f "${MARKER}" ]] && exit 0
if ! ping -c1 -W5 8.8.8.8 &>/dev/null; then exit 0; fi
mkdir -p "$(dirname "${MARKER}")"
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
flatpak update --user -y --noninteractive 2>/dev/null || true
flatpak install --user -y --noninteractive flathub org.telegram.desktop 2>/dev/null || true
flatpak install --user -y --noninteractive flathub io.github.mimbrero.WhatsAppDesktop 2>/dev/null || flatpak install --user -y --noninteractive flathub com.github.eneshecan.WhatsAppForLinux 2>/dev/null || true
flatpak install --user -y --noninteractive flathub app.organicmaps.desktop 2>/dev/null || true
touch "${MARKER}"
' > /usr/local/bin/canvera-install-flatpak-apps
chmod +x /usr/local/bin/canvera-install-flatpak-apps

mkdir -p /etc/systemd/user
printf '[Unit]\nDescription=CanveraOS First-Boot Flatpak App Installer\nAfter=network-online.target\n\n[Service]\nType=oneshot\nExecStart=/usr/local/bin/canvera-install-flatpak-apps\nRemainAfterExit=yes\nStandardOutput=journal\nStandardError=journal\n\n[Install]\nWantedBy=default.target\n' > /etc/systemd/user/canvera-flatpak-apps.service
systemctl --global enable canvera-flatpak-apps.service 2>/dev/null || true
ok "Flatpak apps will be installed on first boot (with internet)."

# ─── Workspace Modes switcher ─────────────────────────────────────────────────
log "Installing Workspace Modes switcher..."
cp /canvera-scripts/workspace-modes.sh /usr/local/bin/canvera-workspace-modes 2>/dev/null || {
    warn "workspace-modes.sh not found — creating placeholder..."
    printf '#!/usr/bin/env bash\necho "Workspace Modes: feature coming soon"\n' > /usr/local/bin/canvera-workspace-modes
}
chmod +x /usr/local/bin/canvera-workspace-modes
printf '[Desktop Entry]\nName=Workspace Modes\nComment=Switch between Video Edit, Design, and Writing workspace layouts\nExec=/usr/local/bin/canvera-workspace-modes --gui\nIcon=view-grid\nTerminal=false\nType=Application\nCategories=Settings;\nStartupNotify=false\n' > /usr/share/applications/workspace-modes.desktop

# ─── Custom desktop entries ───────────────────────────────────────────────────
log "Installing custom desktop entries..."
if [[ -d /canvera-config/apps/desktop ]]; then
    cp /canvera-config/apps/desktop/*.desktop /usr/share/applications/ 2>/dev/null || true
fi
update-desktop-database /usr/share/applications/
ok "Desktop entries updated."

ok "All applications installed."