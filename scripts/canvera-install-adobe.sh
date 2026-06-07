{\rtf1\ansi\ansicpg1252\cocoartf2870
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\paperw11900\paperh16840\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 #!/usr/bin/env bash\
# =============================================================================\
# CanveraOS - Adobe CC Setup Utility (via CrossOver)\
# Fully GUI-based installer for Adobe Creative Cloud apps\
# =============================================================================\
\
# Check if CrossOver is installed\
if [[ ! -x "/opt/cxoffice/bin/cxbottle" ]]; then\
    zenity --error \\\
        --title="CrossOver Not Found" \\\
        --text="CrossOver is not installed or configured properly. Please ensure CrossOver is activated." \\\
        --width=350 2>/dev/null\
    exit 1\
fi\
\
# 1. Ask user to select the Adobe setup executable\
ADOBE_SETUP=$(zenity --file-selection \\\
    --title="Select Adobe CC Installer (Setup.exe)" \\\
    --file-filter="*.exe" \\\
    --width=600 --height=400 2>/dev/null)\
\
if [[ -z "$ADOBE_SETUP" ]]; then\
    exit 0\
fi\
\
BOTTLE_NAME="AdobeCC"\
\
# 2. Progress dialog for bottle creation and prerequisite installation\
(\
    echo "10"; echo "# Checking CrossOver environment..."\
    \
    # Create bottle if it doesn't exist\
    if ! /opt/cxoffice/bin/cxrun --bottle "$BOTTLE_NAME" --command "cmd.exe" /c echo "check" &>/dev/null; then\
        echo "30"; echo "# Creating AdobeCC Windows 10 environment..."\
        /opt/cxoffice/bin/cxbottle --create --bottle "$BOTTLE_NAME" --template win10\
        \
        echo "50"; echo "# Installing prerequisites (CoreFonts, MSXML, VC++)..."\
        /opt/cxoffice/bin/cxsetup --bottle "$BOTTLE_NAME" --install "corefonts"\
        /opt/cxoffice/bin/cxsetup --bottle "$BOTTLE_NAME" --install "msxml6"\
        /opt/cxoffice/bin/cxsetup --bottle "$BOTTLE_NAME" --install "vcrun2015"\
        /opt/cxoffice/bin/cxsetup --bottle "$BOTTLE_NAME" --install "vcrun2019"\
    else\
        echo "50"; echo "# AdobeCC environment already exists. Skipping prerequisite setup..."\
    fi\
    \
    echo "80"; echo "# Launching Adobe Installer..."\
    \
) | zenity --progress \\\
    --title="Preparing Adobe CC Environment" \\\
    --text="Setting up CrossOver..." \\\
    --percentage=0 \\\
    --auto-close \\\
    --auto-kill \\\
    --width=400\
\
# 3. Run the installer inside the CrossOver bottle\
# We run this outside the progress bar so the Adobe GUI can remain open\
/opt/cxoffice/bin/cxrun --bottle "$BOTTLE_NAME" --command "$ADOBE_SETUP"\
\
# 4. Success message\
zenity --info \\\
    --title="Installation Finished" \\\
    --text="<b>Adobe CC Installation Complete!</b>\\n\\nIf the setup finished successfully, your Adobe applications are now fully integrated into CanveraOS." \\\
    --width=400 \\\
    2>/dev/null}