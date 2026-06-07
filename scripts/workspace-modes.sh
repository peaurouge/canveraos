#!/usr/bin/env bash
# =============================================================================
# CanveraOS - Smart Workspace Modes
# Auto-launches and arranges applications based on creative workflows.
# Fully GUI-driven with Zenity.
# =============================================================================

# Disable notifications (Do Not Disturb) helper function
set_dnd() {
    local state=$1 # "true" or "false"
    kwriteconfig5 --file plasmanotifyrc --group Notifications --key DoNotDisturb "${state}" 2>/dev/null || true
    kwriteconfig6 --file plasmanotifyrc --group Notifications --key DoNotDisturb "${state}" 2>/dev/null || true
    qdbus org.kde.plasmashell /org/kde/osdService org.kde.osdService.showText "Do Not Disturb: ${state}" "notifications-disabled" 2>/dev/null || true
}

# ─── Workspace Selection Dialog ───────────────────────────────────────────────
MODE=$(zenity --list \
    --title="Smart Workspace Modes" \
    --text="<b>Select your creative workflow:</b>\n\nCanveraOS will prepare your applications and system settings." \
    --radiolist \
    --column="Select" --column="Workspace" \
    TRUE "🎨 Design & Photography" \
    FALSE "🎬 Video Production" \
    FALSE "📝 Focus / Writing" \
    --width=400 --height=250 \
    2>/dev/null)

if [[ -z "$MODE" ]]; then
    exit 0
fi

# ─── Apply Workspace Configurations ───────────────────────────────────────────
case "$MODE" in
    "🎨 Design & Photography")
        zenity --notification --text="Preparing Design & Photography Workspace..." 2>/dev/null
        set_dnd "false"
        
        # Launch Adobe apps via CrossOver
        if [[ -d "/opt/cxoffice/bin" ]]; then
            /opt/cxoffice/bin/cxrun --bottle "AdobeCC" --command "Photoshop.exe" &
            sleep 3
            /opt/cxoffice/bin/cxrun --bottle "AdobeCC" --command "Illustrator.exe" &
        fi
        # Open Dolphin to Pictures/Assets
        dolphin "${HOME}/Pictures" &
        ;;
        
    "🎬 Video Production")
        zenity --notification --text="Preparing Video Production Workspace..." 2>/dev/null
        # Enable DND to prevent notification sounds during audio/video playback
        set_dnd "true"
        
        # Launch DaVinci Resolve and Premiere Pro
        if [[ -f "/opt/resolve/bin/resolve" ]]; then
            /opt/resolve/bin/resolve &
        elif [[ -d "/opt/cxoffice/bin" ]]; then
            /opt/cxoffice/bin/cxrun --bottle "AdobeCC" --command "Premiere Pro.exe" &
        fi
        
        # Open Dolphin to Videos folder
        dolphin "${HOME}/Videos" &
        ;;
        
    "📝 Focus / Writing")
        zenity --notification --text="Entering Focus Mode..." 2>/dev/null
        # Strict DND
        set_dnd "true"
        
        # Launch Office apps (via CrossOver or PWA)
        if [[ -d "/opt/cxoffice/bin" ]]; then
            /opt/cxoffice/bin/cxrun --bottle "MSOffice" --command "WINWORD.EXE" &
        fi
        ;;
esac

exit 0