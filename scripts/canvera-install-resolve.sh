{\rtf1\ansi\ansicpg1252\cocoartf2870
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\paperw11900\paperh16840\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 #!/usr/bin/env bash\
# =============================================================================\
# CanveraOS - DaVinci Resolve GUI Installer\
# Provides a zero-terminal graphical installation for DaVinci Resolve.\
# =============================================================================\
\
# Require root privileges via pkexec (graphical sudo)\
if [[ $EUID -ne 0 ]]; then\
    pkexec "$0" "$@"\
    exit $?\
fi\
\
# 1. Ask user to select the downloaded DaVinci Resolve .zip file\
RESOLVE_ZIP=$(zenity --file-selection \\\
    --title="Select DaVinci Resolve Linux Installer (.zip)" \\\
    --file-filter="*.zip" \\\
    --width=600 --height=400 2>/dev/null)\
\
if [[ -z "$RESOLVE_ZIP" ]]; then\
    exit 0\
fi\
\
# 2. Show progress dialog while installing dependencies and extracting\
(\
    echo "10"; echo "# Installing required Linux libraries..."\
    apt-get update -qq\
    apt-get install -yq libssl-dev libglib2.0-0 libglib2.0-bin libxcb-composite0 \\\
        libxcb-cursor0 libxcb-damage0 libxcb-dpms0 libxcb-dri2-0 libxcb-dri3-0 \\\
        libxcb-glx0 libxcb-present0 libxcb-randr0 libxcb-record0 libxcb-render0 \\\
        libxcb-shape0 libxcb-shm0 libxcb-sync1 libxcb-util1 libxcb-xfixes0 \\\
        libxcb-xinerama0 libxcb-xkb1 libxkbcommon-x11-0 libx11-xcb1 \\\
        libasound2t64 libglu1-mesa libapr1 libaprutil1 mesa-utils\
    \
    echo "40"; echo "# Extracting DaVinci Resolve installer..."\
    TMP_DIR=$(mktemp -d)\
    unzip -q "$RESOLVE_ZIP" -d "$TMP_DIR"\
    \
    RUN_FILE=$(ls "$TMP_DIR"/*.run | head -n 1)\
    \
    if [[ -z "$RUN_FILE" ]]; then\
        echo "100"; echo "# Error: Invalid zip file."\
        exit 1\
    fi\
    \
    echo "70"; echo "# Installing DaVinci Resolve (this may take a few minutes)..."\
    chmod +x "$RUN_FILE"\
    "$RUN_FILE" -i -y\
    \
    echo "95"; echo "# Cleaning up temporary files..."\
    rm -rf "$TMP_DIR"\
    \
    echo "100"; echo "# Installation complete!"\
) | zenity --progress \\\
    --title="Installing DaVinci Resolve" \\\
    --text="Preparing installation..." \\\
    --percentage=0 \\\
    --auto-close \\\
    --auto-kill \\\
    --width=400\
\
# 3. Final success message\
zenity --info \\\
    --title="Installation Complete" \\\
    --text="<b>DaVinci Resolve</b> has been successfully installed!\\n\\nYou can now launch it from the Applications menu or the Command Palette." \\\
    --width=350 \\\
    2>/dev/null}