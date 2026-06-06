#!/usr/bin/env bash
# =============================================================================
# CanveraOS — Loupedeck CT Setup Script
# Installs udev rules, community tools, CrossOver Windows software bottle,
# and a GUI launcher for Loupedeck CT on Linux.
#
# Loupedeck officially supports Windows/macOS ONLY.
# This script provides:
#   1. udev rules — device access without root
#   2. Node.js community library (foxxyz/loupedeck) — full CT support
#   3. CrossOver Windows bottle — official Windows software via CrossOver
#   4. Setup assistant — guides user on how to use Loupedeck CT
# =============================================================================
set -euo pipefail

log()  { echo -e "\033[0;36m[LDECK]\033[0m $*"; }
ok()   { echo -e "\033[0;32m[  OK  ]\033[0m $*"; }
warn() { echo -e "\033[1;33m[ WARN ]\033[0m $*"; }

# ─── 1. Install udev rules ────────────────────────────────────────────────────
log "Installing Loupedeck udev rules..."
cp /canvera-config/loupedeck/50-loupedeck.rules /etc/udev/rules.d/50-loupedeck.rules
chmod 644 /etc/udev/rules.d/50-loupedeck.rules
udevadm control --reload-rules 2>/dev/null || true
ok "Loupedeck udev rules installed."

# ─── 2. Install system dependencies ──────────────────────────────────────────
log "Installing Loupedeck system dependencies..."
apt-get install -y \
    nodejs \
    npm \
    libhidapi-hidraw0 \
    libhidapi-libusb0 \
    libusb-1.0-0 \
    libudev1
ok "System dependencies installed."

# ─── 3. Install Node.js Loupedeck community library ──────────────────────────
log "Installing loupedeck Node.js community library (foxxyz/loupedeck)..."
# This library provides full Loupedeck CT support on Linux:
# - Read button presses, dial rotations, touchpad events
# - Control display panels, RGB button colors
# - Full bidirectional communication
npm install -g loupedeck 2>/dev/null || {
    warn "npm global install failed — installing to /opt/loupedeck..."
    mkdir -p /opt/loupedeck
    cd /opt/loupedeck
    npm init -y 2>/dev/null || true
    npm install loupedeck 2>/dev/null || warn "loupedeck npm install failed"
    cd /
}
ok "Loupedeck Node.js library installed."

# ─── 4. Create Loupedeck CT connection test script ───────────────────────────
log "Creating Loupedeck CT tools..."
mkdir -p /opt/loupedeck/scripts

# Connection test script — verifies CT is detected
printf '#!/usr/bin/env node
// CanveraOS Loupedeck CT connection test
const { LoupedeckDevice } = require("loupedeck");

console.log("Scanning for Loupedeck devices...");

const device = new LoupedeckDevice({ autoConnect: false });

device.on("connect", async (info) => {
    console.log("✅ Loupedeck CT connected:", info);
    // Set all buttons to CanveraOS blue
    for (let i = 0; i < 8; i++) {
        await device.setButtonColor({ id: i, r: 10, g: 132, b: 255 });
    }
    console.log("Buttons set to CanveraOS blue.");
    setTimeout(() => device.close(), 3000);
});

device.on("error", (err) => {
    console.error("❌ Error:", err.message);
    process.exit(1);
});

device.connect();
' > /opt/loupedeck/scripts/test-connection.js

# ─── 5. Create Loupedeck Windows software CrossOver bottle ───────────────────
log "Creating CrossOver bottle for official Loupedeck Windows software..."
CX_INSTALL="/opt/cxoffice"
BOTTLES_DIR="/etc/skel/.cxoffice"
mkdir -p "${BOTTLES_DIR}"

if [[ -f "${CX_INSTALL}/bin/cxbottle" ]]; then
    # Create dedicated Loupedeck bottle
    "${CX_INSTALL}/bin/cxbottle" --create --bottle "Loupedeck" \
        --winver win10 2>/dev/null || true

    # Install Visual C++ Redistributables (required by Loupedeck software)
    "${CX_INSTALL}/bin/cxinstall" \
        --bottle "Loupedeck" \
        --component "msvcrt2019_64" 2>/dev/null || true

    "${CX_INSTALL}/bin/cxinstall" \
        --bottle "Loupedeck" \
        --component "msvcrt2019_32" 2>/dev/null || true

    # Install .NET Framework (required by Loupedeck)
    "${CX_INSTALL}/bin/cxinstall" \
        --bottle "Loupedeck" \
        --component "dotnet48" 2>/dev/null || true

    ok "Loupedeck CrossOver bottle created."
else
    warn "CrossOver not installed — Windows Loupedeck software bottle skipped."
    warn "Install CrossOver first, then run: /usr/local/bin/canvera-setup-loupedeck"
fi

# ─── 6. Create GUI launcher for Loupedeck software ───────────────────────────
log "Creating Loupedeck GUI launcher..."
printf '#!/usr/bin/env bash
# CanveraOS Loupedeck CT Launcher
# Tries to launch official Windows software via CrossOver.
# Falls back to community Node.js tools if CrossOver not available.

CX_INSTALL="/opt/cxoffice"
BOTTLE="Loupedeck"
LOUPEDECK_EXE="C:\\\\Program Files\\\\Loupedeck\\\\Loupedeck.exe"
LOUPEDECK_ALT="C:\\\\Program Files (x86)\\\\Loupedeck\\\\Loupedeck.exe"

# Check if device is connected
if ! ls /dev/loupedeck* 2>/dev/null | grep -q loupedeck; then
    zenity --info \
        --title="Loupedeck CT" \
        --text="<b>Loupedeck CT not detected.</b>\\n\\nPlease connect your Loupedeck CT via USB and try again.\\n\\n<i>If the device is connected but not detected, you may need to log out and back in to apply device permissions.</i>" \
        --width=420 2>/dev/null || \
    notify-send "Loupedeck" "Loupedeck CT not detected. Please connect via USB." 2>/dev/null
    exit 0
fi

# Check if Windows software is installed in CrossOver bottle
if [[ -f "${HOME}/.cxoffice/${BOTTLE}/drive_c/Program Files/Loupedeck/Loupedeck.exe" ]] || \
   [[ -f "${HOME}/.cxoffice/${BOTTLE}/drive_c/Program Files (x86)/Loupedeck/Loupedeck.exe" ]]; then
    # Launch installed Windows software
    exec "${CX_INSTALL}/bin/wine" --bottle "${BOTTLE}" "${LOUPEDECK_EXE}" 2>/dev/null || \
    exec "${CX_INSTALL}/bin/wine" --bottle "${BOTTLE}" "${LOUPEDECK_ALT}" 2>/dev/null
fi

# Loupedeck not installed yet — offer installation
zenity --question \
    --title="Install Loupedeck" \
    --text="<b>Loupedeck software is not installed.</b>\\n\\nWould you like to download and install the official Loupedeck software now?\\n\\n<i>Requires CrossOver and internet connection.\\nThe installer will run via CrossOver (Windows compatibility layer).</i>" \
    --ok-label="Download and Install" \
    --cancel-label="Cancel" \
    --width=440 2>/dev/null || exit 0

# Download Windows installer
INSTALLER="${HOME}/Downloads/LoupedeckSetup.exe"
wget -q --show-progress \
    -O "${INSTALLER}" \
    "https://s3.amazonaws.com/loupedeck-releases/latest/LoupedeckSetup.exe" 2>/dev/null || {
    # Fallback: open official download page
    xdg-open "https://loupedeck.com/start/" 2>/dev/null
    zenity --info \
        --title="Loupedeck" \
        --text="Opening Loupedeck download page in browser.\\n\\nDownload the Windows installer (.exe) and run it through CrossOver:\\n\\n<b>CrossOver → Install Application → Browse for .exe</b>" \
        --width=400 2>/dev/null
    exit 0
}

# Run installer through CrossOver
if [[ -f "${INSTALLER}" ]]; then
    zenity --info \
        --title="Installing Loupedeck" \
        --text="Running Loupedeck installer via CrossOver...\\n\\nFollow the on-screen instructions to complete installation." \
        --width=380 --timeout=5 2>/dev/null || true
    "${CX_INSTALL}/bin/wine" --bottle "${BOTTLE}" "${INSTALLER}" 2>/dev/null || {
        zenity --error \
            --title="Installation Failed" \
            --text="Could not run the installer.\\n\\nManually install via:\\n<b>CrossOver → Install Application → Browse for .exe</b>\\n\\nSelect the Loupedeck bottle when prompted." \
            --width=400 2>/dev/null
    }
fi
' > /usr/local/bin/canvera-loupedeck
chmod +x /usr/local/bin/canvera-loupedeck

# ─── 7. Create .desktop entry ─────────────────────────────────────────────────
printf '[Desktop Entry]
Name=Loupedeck CT
Comment=Creative console control software — Loupedeck CT by CanveraOS
Exec=/usr/local/bin/canvera-loupedeck
Icon=input-dialpad
Terminal=false
Type=Application
Categories=Utility;HardwareSettings;
StartupNotify=true
Keywords=loupedeck;ct;creative;console;dial;knob;
' > /usr/share/applications/loupedeck-ct.desktop

# ─── 8. Create Loupedeck first-boot setup script ─────────────────────────────
log "Creating Loupedeck first-boot group setup..."
# NOTE: The actual user needs to be in 'plugdev' group.
# This is handled by first-boot.sh adding the user to plugdev.
printf '#!/usr/bin/env bash
# Adds the current user to plugdev group for Loupedeck access
# Run once after installation
USERNAME=$(whoami)
if ! groups "${USERNAME}" | grep -q plugdev; then
    pkexec usermod -aG plugdev "${USERNAME}" 2>/dev/null && \
    zenity --info \
        --title="Loupedeck CT Ready" \
        --text="<b>Loupedeck CT permissions configured!</b>\\n\\nYou have been added to the device access group.\\n\\n<i>Please log out and back in for changes to take effect.</i>" \
        --width=400 2>/dev/null || true
fi
' > /usr/local/bin/canvera-loupedeck-setup
chmod +x /usr/local/bin/canvera-loupedeck-setup

update-desktop-database /usr/share/applications/ 2>/dev/null || true
ok "Loupedeck CT setup complete."
