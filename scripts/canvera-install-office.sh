{\rtf1\ansi\ansicpg1252\cocoartf2870
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\paperw11900\paperh16840\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 #!/usr/bin/env bash\
# =============================================================================\
# CanveraOS - Microsoft Office Setup Utility (via CrossOver)\
# Fully GUI-based installer for Microsoft Office (Word, Excel, PowerPoint)\
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
# 1. Ask user to select the Office setup executable\
OFFICE_SETUP=$(zenity --file-selection \\\
    --title="Select Microsoft Office Installer (Setup.exe)" \\\
    --file-filter="*.exe" \\\
    --width=600 --height=400 2>/dev/null)\
\
if [[ -z "$OFFICE_SETUP" ]]; then\
    exit 0\
fi\
\
BOTTLE_NAME="MSOffice"\
\
# 2. Progress dialog for bottle creation and prerequisite installation\
(\
    echo "10"; echo "# Checking CrossOver environment..."\
    \
    # Create bottle if it doesn't exist\
    if ! /opt/cxoffice/bin/cxrun --bottle "$BOTTLE_NAME" --command "cmd.exe" /c echo "check" &>/dev/null; then\
        echo "30"; echo "# Creating MSOffice Windows 10 environment..."\
        /opt/cxoffice/bin/cxbottle --create --bottle "$BOTTLE_NAME" --template win10\
        \
        echo "50"; echo "# Installing prerequisites (CoreFonts, MSXML, RichEd)..."\
        /opt/cxoffice/bin/cxsetup --bottle "$BOTTLE_NAME" --install "corefonts"\
        /opt/cxoffice/bin/cxsetup --bottle "$BOTTLE_NAME" --install "msxml6"\
        /opt/cxoffice/bin/cxsetup --bottle "$BOTTLE_NAME" --install "riched20"\
        /opt/cxoffice/bin/cxsetup --bottle "$BOTTLE_NAME" --install "gdiplus"\
    else\
        echo "50"; echo "# MSOffice environment already exists. Skipping prerequisite setup..."\
    fi\
    \
    echo "80"; echo "# Launching Microsoft Office Installer..."\
    \
) | zenity --progress \\\
    --title="Preparing Microsoft Office Environment" \\\
    --text="Setting up CrossOver..." \\\
    --percentage=0 \\\
    --auto-close \\\
    --auto-kill \\\
    --width=400\
\
# 3. Run the installer inside the CrossOver bottle\
/opt/cxoffice/bin/cxrun --bottle "$BOTTLE_NAME" --command "$OFFICE_SETUP"\
\
# 4. Success message\
zenity --info \\\
    --title="Installation Finished" \\\
    --text="<b>Microsoft Office Installation Complete!</b>\\n\\nIf the setup finished successfully, Word, Excel, and PowerPoint are now fully integrated into CanveraOS." \\\
    --width=400 \\\
    2>/dev/null}