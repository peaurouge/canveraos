#!/usr/bin/env bash
# =============================================================================
# CanveraOS — Smart Workspace Modes
# Pre-configured desktop layouts for different creative workflows.
# GUI-based. Invoked via dock icon or keyboard shortcut.
# Modes: Video Edit, Design, Writing, Gaming, Browsing, Custom
# =============================================================================

MODES_DIR="${HOME}/.config/canvera/workspace-modes"
CURRENT_MODE_FILE="${HOME}/.config/canvera/current-workspace"
mkdir -p "${MODES_DIR}"

# ─── Available workspace modes ────────────────────────────────────────────────
declare -A MODE_NAMES=(
    ["video"]="🎬 Video Edit"
    ["design"]="🎨 Design"
    ["writing"]="✍️ Writing"
    ["gaming"]="🎮 Gaming"
    ["browsing"]="🌐 Browsing"
    ["custom"]="⚙️ Custom"
)

declare -A MODE_APPS=(
    ["video"]="davinci-resolve"
    ["design"]="photoshop illustrator"
    ["writing"]="kate"
    ["gaming"]="steam"
    ["browsing"]="chromium-browser"
    ["custom"]=""
)

# ─── Close all open windows ───────────────────────────────────────────────────
close_all_windows() {
    # Politely close all non-essential windows
    wmctrl -l 2>/dev/null | awk '{print $1}' | while read -r wid; do
        wmctrl -i -c "${wid}" 2>/dev/null || true
    done
    sleep 1
}

# ─── Apply workspace mode ─────────────────────────────────────────────────────
apply_mode() {
    local MODE="$1"

    case "${MODE}" in
        video)
            log "Switching to Video Edit workspace..."
            # Set DaVinci-friendly dark environment
            /usr/local/bin/canvera-dark-mode --dark
            # Launch DaVinci Resolve (or show install dialog)
            if command -v resolve &>/dev/null; then
                resolve &
            else
                /usr/local/bin/canvera-install-resolve
            fi
            # Set single-monitor, maximize video app
            kwin-maximize-active
            ;;

        design)
            log "Switching to Design workspace..."
            /usr/local/bin/canvera-dark-mode --dark
            # Launch Photoshop
            /usr/local/bin/canvera-launch-photoshop &
            sleep 2
            ;;

        writing)
            log "Switching to Writing workspace..."
            /usr/local/bin/canvera-dark-mode --light
            kate &
            sleep 1
            ;;

        gaming)
            log "Switching to Gaming workspace..."
            /usr/local/bin/canvera-dark-mode --dark
            steam &
            ;;

        browsing)
            log "Switching to Browsing workspace..."
            chromium-browser &
            ;;
    esac

    echo "${MODE}" > "${CURRENT_MODE_FILE}"
    log "Workspace mode: ${MODE_NAMES[$MODE]}"
}

# ─── GUI mode picker ──────────────────────────────────────────────────────────
show_mode_picker() {
    CURRENT=$(cat "${CURRENT_MODE_FILE}" 2>/dev/null || echo "none")

    CHOICE=$(zenity --list \
        --title="Workspace Modes" \
        --text="<b>Choose your creative workspace:</b>\n\nEach mode optimizes your desktop layout and\nlaunches the relevant tools automatically." \
        --column="Mode" --column="Description" --column="Key Apps" \
        "🎬 Video Edit" "Optimized for video production" "DaVinci Resolve" \
        "🎨 Design"     "Creative design workspace" "Photoshop, Illustrator" \
        "✍️ Writing"    "Focused writing environment" "Kate Text Editor" \
        "🎮 Gaming"     "Gaming mode with Steam" "Steam + Proton" \
        "🌐 Browsing"   "Web browsing workspace" "Chromium" \
        --width=640 --height=380 \
        --print-column=1 \
        2>/dev/null) || return

    case "${CHOICE}" in
        "🎬 Video Edit") apply_mode "video" ;;
        "🎨 Design")     apply_mode "design" ;;
        "✍️ Writing")    apply_mode "writing" ;;
        "🎮 Gaming")     apply_mode "gaming" ;;
        "🌐 Browsing")   apply_mode "browsing" ;;
    esac
}

# ─── Save current workspace as custom mode ────────────────────────────────────
save_custom_mode() {
    local MODE_NAME
    MODE_NAME=$(zenity --entry \
        --title="Save Workspace Mode" \
        --text="Enter a name for this workspace configuration:" \
        --entry-text="My Workspace" \
        --width=380 2>/dev/null) || return

    local SAFE_NAME="${MODE_NAME// /_}"
    local MODE_FILE="${MODES_DIR}/${SAFE_NAME}.mode"

    # Save current window positions
    wmctrl -lG 2>/dev/null > "${MODE_FILE}" || true
    echo "name=${MODE_NAME}" >> "${MODE_FILE}"
    echo "saved=$(date '+%Y-%m-%d %H:%M')" >> "${MODE_FILE}"

    zenity --info \
        --title="Mode Saved" \
        --text="Workspace mode '<b>${MODE_NAME}</b>' saved successfully!\n\nYou can restore it from the Workspace Modes menu." \
        --width=340 2>/dev/null || true
}

# ─── Log function ─────────────────────────────────────────────────────────────
log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ─── Main ─────────────────────────────────────────────────────────────────────
case "${1:-}" in
    --gui)         show_mode_picker ;;
    --save)        save_custom_mode ;;
    video|design|writing|gaming|browsing)
                   apply_mode "$1" ;;
    *)             show_mode_picker ;;
esac
