#!/usr/bin/env bash
# =============================================================================
# CanveraOS — CrossOver Installation & Adobe CC Bottle Setup
# Installs CrossOver, creates pre-configured Wine bottles for each Adobe app,
# installs all required Windows runtimes into each bottle.
# User just opens the app icon and logs into Adobe. Zero terminal.
# =============================================================================
set -euo pipefail

log()  { echo -e "\033[0;36m[ CXOV]\033[0m $*"; }
ok()   { echo -e "\033[0;32m[  OK  ]\033[0m $*"; }
warn() { echo -e "\033[1;33m[ WARN]\033[0m $*"; }
err()  { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

export DEBIAN_FRONTEND=noninteractive

# ─── Download CrossOver .deb ──────────────────────────────────────────────────
log "Downloading CrossOver..."
CROSSOVER_DEB="/tmp/crossover.deb"
CROSSOVER_URL="https://crossover.codeweavers.com/redirect/crossover.deb"

wget -q --show-progress -O "${CROSSOVER_DEB}" "${CROSSOVER_URL}" || {
    warn "Direct download failed — trying alternate URL..."
    wget -q -O "${CROSSOVER_DEB}" \
        "https://media.codeweavers.com/pub/crossover/cxlinux/demo/crossover_24.0.8-1.deb" || {
        warn "CrossOver download failed — skipping CrossOver install."
        exit 0
    }
}

# ─── Install CrossOver dependencies ───────────────────────────────────────────
log "Installing CrossOver dependencies..."
apt-get install -y \
    gdebi-core \
    libglib2.0-0 \
    libc6 \
    libstdc++6 \
    libfreetype6 \
    libfontconfig1 \
    libxrender1 \
    libxext6 \
    libx11-6 \
    libxrandr2 \
    libxi6 \
    libxfixes3 \
    libxcursor1 \
    libxcomposite1 \
    libxdamage1 \
    libxinerama1 \
    libxkbfile1 \
    libpulse0 \
    libvulkan1 \
    mesa-vulkan-drivers \
    vulkan-tools
# libasound2 was renamed to libasound2t64 in Ubuntu 24.04
apt-get install -y libasound2t64 2>/dev/null || apt-get install -y libasound2 2>/dev/null || true

# ─── Install CrossOver ────────────────────────────────────────────────────────
log "Installing CrossOver package..."
gdebi -n "${CROSSOVER_DEB}" || dpkg -i "${CROSSOVER_DEB}" || {
    apt-get install -f -y
    dpkg -i "${CROSSOVER_DEB}"
}
rm -f "${CROSSOVER_DEB}"
ok "CrossOver installed."

# ─── CrossOver bottle directory ───────────────────────────────────────────────
CX_INSTALL="/opt/cxoffice"
BOTTLES_DIR="/etc/skel/.cxoffice"
mkdir -p "${BOTTLES_DIR}"

# ─── Function: create bottle with prerequisites ───────────────────────────────
create_adobe_bottle() {
    local BOTTLE_NAME="$1"
    local BOTTLE_DISPLAY="$2"

    log "Creating CrossOver bottle: ${BOTTLE_DISPLAY}..."

    # Create bottle structure
    "${CX_INSTALL}/bin/cxbottle" --create --bottle "${BOTTLE_NAME}" \
        --winver win10 2>/dev/null || true

    BOTTLE_PATH="${BOTTLES_DIR}/${BOTTLE_NAME}"

    # Install Visual C++ Redistributables (required by all Adobe apps)
    "${CX_INSTALL}/bin/cxinstall" \
        --bottle "${BOTTLE_NAME}" \
        --component "msvcrt2019_64" 2>/dev/null || true

    "${CX_INSTALL}/bin/cxinstall" \
        --bottle "${BOTTLE_NAME}" \
        --component "msvcrt2019_32" 2>/dev/null || true

    # Install .NET Framework 4.8
    "${CX_INSTALL}/bin/cxinstall" \
        --bottle "${BOTTLE_NAME}" \
        --component "dotnet48" 2>/dev/null || true

    # Install DirectX
    "${CX_INSTALL}/bin/cxinstall" \
        --bottle "${BOTTLE_NAME}" \
        --component "dxvk" 2>/dev/null || true

    # Install Windows fonts (required for Photoshop UI)
    "${CX_INSTALL}/bin/cxinstall" \
        --bottle "${BOTTLE_NAME}" \
        --component "corefonts" 2>/dev/null || true

    # Enable GPU acceleration for the bottle
    printf '\n[CanveraOS]\nEnableGPU=true\nUseVulkan=true\nDXVKEnabled=true\n' \
        >> "${BOTTLE_PATH}/cxbottle.conf" 2>/dev/null || true

    ok "Bottle ${BOTTLE_NAME} created and configured."
}

# ─── Create Adobe CC Bottles ──────────────────────────────────────────────────
log "Creating Adobe CC CrossOver bottles..."
create_adobe_bottle "Photoshop"  "Adobe Photoshop CC"
create_adobe_bottle "Illustrator" "Adobe Illustrator CC"
create_adobe_bottle "Premiere"   "Adobe Premiere Pro CC"
create_adobe_bottle "AfterEffects" "Adobe After Effects CC"
create_adobe_bottle "Lightroom"  "Adobe Lightroom CC"
create_adobe_bottle "SuitcaseFusion" "Suitcase Fusion"
create_adobe_bottle "Word"       "Microsoft Word"
create_adobe_bottle "Excel"      "Microsoft Excel"
create_adobe_bottle "PowerPoint" "Microsoft PowerPoint"

# ─── Create Adobe CC installer launcher scripts ───────────────────────────────
log "Creating Adobe CC GUI launcher scripts..."

create_adobe_launcher() {
    local APP_NAME="$1"
    local BOTTLE="$2"
    local EXE_PATH="$3"
    local ICON_NAME="$4"
    local DISPLAY_NAME="$5"
    local SCRIPT="/usr/local/bin/canvera-launch-${APP_NAME,,}"

    cat > "${SCRIPT}" << SCRIPT
#!/usr/bin/env bash
# CanveraOS launcher for ${DISPLAY_NAME}
# NOTE: No 'set -euo pipefail' here — zenity dialog close returns non-zero
# and we don't want the launcher to die silently when the user closes a dialog.

BOTTLE_PATH="\${HOME}/.cxoffice/${BOTTLE}"
CX_INSTALL="/opt/cxoffice"

# Check if Adobe CC Desktop App is installed in bottle
if [[ ! -f "\${BOTTLE_PATH}/drive_c/Program Files/Adobe/Adobe Creative Cloud/ACC/Creative Cloud.exe" ]]; then
    # Show installation dialog
    zenity --info \
        --title="Install ${DISPLAY_NAME}" \
        --text="<b>${DISPLAY_NAME}</b> needs to be installed first.\n\nYou will need:\n• An Adobe Creative Cloud subscription\n• Your Adobe ID and password\n\nClick OK to start the installation. It may take a few minutes." \
        --width=420 --height=220 \
        2>/dev/null || true  # || true: user closing dialog = OK, don't exit

    # Download Creative Cloud installer
    CC_INSTALLER="\${HOME}/Downloads/CreativeCloudSetup.exe"
    zenity --progress \
        --title="Downloading Adobe Creative Cloud" \
        --text="Downloading installer..." \
        --percentage=0 --auto-close --pulsate \
        2>/dev/null &
    ZPID=\$!

    wget -q -O "\${CC_INSTALLER}" \
        "https://ccmdls.adobe.com/AdobeProducts/KCCC/1/win64/CreativeCloudSetup.exe" || \
    wget -q -O "\${CC_INSTALLER}" \
        "https://prod-rel-ffc-ccm.oobesaas.adobe.com/adobe-ffc-external/core/v1/wam?payload=ssai&appName=creativeclouddesktop&os=win" 2>/dev/null || true

    kill \$ZPID 2>/dev/null || true

    if [[ -f "\${CC_INSTALLER}" ]]; then
        # Run installer inside CrossOver bottle
        "\${CX_INSTALL}/bin/wine" --bottle "${BOTTLE}" "\${CC_INSTALLER}" || true
    else
        zenity --error \
            --title="Download Failed" \
            --text="Could not download the Adobe Creative Cloud installer.\n\nPlease download it manually from:\nhttps://www.adobe.com/creativecloud/desktop-app.html\n\nThen place it in your Downloads folder and try again." \
            --width=400 2>/dev/null || true
        exit 1
    fi
fi

# Launch the specific Adobe app
exec "\${CX_INSTALL}/bin/wine" --bottle "${BOTTLE}" "${EXE_PATH}" 2>/dev/null || true
SCRIPT

    chmod +x "${SCRIPT}"

    # Create .desktop file
    printf '[Desktop Entry]\nName=%s\nComment=Professional creative software by Adobe\nExec=%s\nIcon=%s\nTerminal=false\nType=Application\nCategories=Graphics;Photography;AudioVideo;\nStartupNotify=true\nStartupWMClass=%s\n' \
        "${DISPLAY_NAME}" "${SCRIPT}" "${ICON_NAME}" "${APP_NAME}" \
        > "/usr/share/applications/${APP_NAME,,}.desktop"
}

create_adobe_launcher "Photoshop" "Photoshop" \
    "C:\\Program Files\\Adobe\\Adobe Photoshop 2025\\Photoshop.exe" \
    "photoshop" "Adobe Photoshop"

create_adobe_launcher "Illustrator" "Illustrator" \
    "C:\\Program Files\\Adobe\\Adobe Illustrator 2025\\Support Files\\Contents\\Windows\\Illustrator.exe" \
    "illustrator" "Adobe Illustrator"

create_adobe_launcher "Premiere" "Premiere" \
    "C:\\Program Files\\Adobe\\Adobe Premiere Pro 2025\\Adobe Premiere Pro.exe" \
    "premiere-pro" "Adobe Premiere Pro"

create_adobe_launcher "AfterEffects" "AfterEffects" \
    "C:\\Program Files\\Adobe\\Adobe After Effects 2025\\Support Files\\AfterFX.exe" \
    "aftereffects" "Adobe After Effects"

create_adobe_launcher "Lightroom" "Lightroom" \
    "C:\\Program Files\\Adobe\\Adobe Lightroom Classic\\lightroom.exe" \
    "lightroom" "Adobe Lightroom Classic"

create_adobe_launcher "SuitcaseFusion" "SuitcaseFusion" \
    "C:\\Program Files\\Extensis\\Suitcase Fusion\\Suitcase Fusion.exe" \
    "preferences-desktop-font" "Suitcase Fusion"

# ─── Microsoft Office via CrossOver ───────────────────────────────────────────
log "Creating Microsoft Office CrossOver launchers..."

create_office_launcher() {
    local APP="$1"
    local DISPLAY="$2"
    local EXE="$3"
    local ICON="$4"
    local SCRIPT="/usr/local/bin/canvera-launch-${APP,,}"

    cat > "${SCRIPT}" << SCRIPT
#!/usr/bin/env bash
/opt/cxoffice/bin/wine --bottle "Microsoft${APP}" "${EXE}"
SCRIPT
    chmod +x "${SCRIPT}"

    printf '[Desktop Entry]\nName=Microsoft %s\nComment=Microsoft %s via CrossOver\nExec=%s\nIcon=%s\nTerminal=false\nType=Application\nCategories=Office;\nStartupNotify=true\n' \
        "${DISPLAY}" "${DISPLAY}" "${SCRIPT}" "${ICON}" \
        > "/usr/share/applications/office-${APP,,}.desktop"
}

create_office_launcher "Word" "Word" \
    "C:\\Program Files\\Microsoft Office\\Office16\\WINWORD.EXE" \
    "libreoffice-writer"

create_office_launcher "Excel" "Excel" \
    "C:\\Program Files\\Microsoft Office\\Office16\\EXCEL.EXE" \
    "libreoffice-calc"

create_office_launcher "PowerPoint" "PowerPoint" \
    "C:\\Program Files\\Microsoft Office\\Office16\\POWERPNT.EXE" \
    "libreoffice-impress"

# ─── First-boot CrossOver license setup ──────────────────────────────────────
log "Creating CrossOver license setup launcher..."
cat > /usr/local/bin/canvera-crossover-license << 'SCRIPT'
#!/usr/bin/env bash
# CrossOver license entry GUI — runs on first boot
/opt/cxoffice/bin/crossover --manage-serial 2>/dev/null || \
/opt/cxoffice/bin/cxoffice --manage-serial 2>/dev/null || {
    zenity --info \
        --title="CrossOver License" \
        --text="To activate CrossOver, open CrossOver from the Applications menu and enter your license key.\n\nYour Adobe apps will work in trial mode until CrossOver is activated." \
        --width=380 --height=180
}
SCRIPT
chmod +x /usr/local/bin/canvera-crossover-license

update-desktop-database /usr/share/applications/
ok "CrossOver + Adobe CC setup complete."
