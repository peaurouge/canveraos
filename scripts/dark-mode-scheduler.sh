#!/usr/bin/env bash
# =============================================================================
# CanveraOS — Dark Mode Scheduler
# Automatically switches between light and dark mode based on time of day.
# Also provides instant toggle via menu bar icon.
# Called by: canvera-dark-mode.timer (systemd user timer)
# =============================================================================

CONFIG_FILE="${HOME}/.config/canvera/dark-mode.conf"
LOG_FILE="${HOME}/.local/share/canvera/dark-mode.log"

# ─── Logging ──────────────────────────────────────────────────────────────────
log() { echo "[$(date '+%H:%M:%S')] $*" >> "${LOG_FILE}"; }

# ─── Read config ──────────────────────────────────────────────────────────────
mkdir -p "$(dirname "${LOG_FILE}")"

DARK_START=$(grep "dark_start" "${CONFIG_FILE}" 2>/dev/null | cut -d= -f2 | tr -d ' ' || echo "19:00")
LIGHT_START=$(grep "light_start" "${CONFIG_FILE}" 2>/dev/null | cut -d= -f2 | tr -d ' ' || echo "07:00")
ENABLED=$(grep "enabled" "${CONFIG_FILE}" 2>/dev/null | cut -d= -f2 | tr -d ' ' || echo "true")

[[ "${ENABLED}" != "true" ]] && exit 0

# ─── Parse times ──────────────────────────────────────────────────────────────
now_minutes=$(date +%H%M | sed 's/^0//')
dark_minutes=$(echo "${DARK_START}" | awk -F: '{print $1*60+$2}')
light_minutes=$(echo "${LIGHT_START}" | awk -F: '{print $1*60+$2}')

# ─── Determine current mode ───────────────────────────────────────────────────
should_be_dark() {
    if [[ ${dark_minutes} -gt ${light_minutes} ]]; then
        # Dark period spans midnight (e.g., 23:00 → 07:00)
        [[ ${now_minutes} -ge ${dark_minutes} || ${now_minutes} -lt ${light_minutes} ]]
    else
        # Dark period within same day (e.g., 19:00 → 07:00)
        [[ ${now_minutes} -ge ${dark_minutes} && ${now_minutes} -lt ${light_minutes} ]]
    fi
}

# ─── Apply mode ───────────────────────────────────────────────────────────────
apply_dark_mode() {
    log "Switching to DARK mode"
    # KDE color scheme
    plasma-apply-colorscheme CanveraOSDark
    # KDE look and feel
    plasma-apply-lookandfeel org.kde.breezedark.desktop 2>/dev/null || true
    # GTK apps (via gsettings)
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Dark' 2>/dev/null || true
    # Kvantum (GTK-style Qt)
    kvantummanager --set CanveraOS 2>/dev/null || true
    # Wallpaper
    plasma-apply-wallpaperimage /usr/share/wallpapers/CanveraOS/canvera-dark.png 2>/dev/null || true
    # Save state
    sed -i 's/current_mode=.*/current_mode=dark/' "${CONFIG_FILE}"
}

apply_light_mode() {
    log "Switching to LIGHT mode"
    # KDE color scheme
    plasma-apply-colorscheme CanveraOS
    # KDE look and feel
    plasma-apply-lookandfeel org.kde.breezelight.desktop 2>/dev/null || true
    # GTK apps
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Light' 2>/dev/null || true
    # Kvantum (light variant)
    kvantummanager --set CanveraOSLight 2>/dev/null || true
    # Wallpaper
    plasma-apply-wallpaperimage /usr/share/wallpapers/CanveraOS/canvera-light.png 2>/dev/null || true
    # Save state
    sed -i 's/current_mode=.*/current_mode=light/' "${CONFIG_FILE}"
}

# ─── Manual toggle mode ───────────────────────────────────────────────────────
toggle_mode() {
    current=$(grep "current_mode" "${CONFIG_FILE}" 2>/dev/null | cut -d= -f2 | tr -d ' ' || echo "dark")
    if [[ "${current}" == "dark" ]]; then
        apply_light_mode
    else
        apply_dark_mode
    fi
}

# ─── GUI settings dialog ──────────────────────────────────────────────────────
show_settings() {
    result=$(zenity --forms \
        --title="Dark Mode Settings" \
        --text="Configure automatic dark mode schedule" \
        --add-entry="Dark mode starts at (HH:MM):" \
        --add-entry="Light mode starts at (HH:MM):" \
        --add-list="Automatic schedule:" --list-values="Enabled|Disabled" \
        --width=400 --height=280 \
        2>/dev/null)

    if [[ $? -eq 0 && -n "${result}" ]]; then
        dark_new=$(echo "${result}" | cut -d'|' -f1)
        light_new=$(echo "${result}" | cut -d'|' -f2)
        enabled_new=$(echo "${result}" | cut -d'|' -f3)
        [[ "${enabled_new}" == "Enabled" ]] && enabled_str="true" || enabled_str="false"
        CURRENT_MODE=$(grep "current_mode" "${CONFIG_FILE}" 2>/dev/null | cut -d= -f2 | tr -d ' ' || echo "dark")
        printf '[DarkMode]\nenabled=%s\ndark_start=%s\nlight_start=%s\ncurrent_mode=%s\n' \
            "${enabled_str}" "${dark_new}" "${light_new}" "${CURRENT_MODE}" \
            > "${CONFIG_FILE}"
        log "Settings updated: dark=${dark_new}, light=${light_new}, enabled=${enabled_str}"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
case "${1:-auto}" in
    --toggle)   toggle_mode ;;
    --dark)     apply_dark_mode ;;
    --light)    apply_light_mode ;;
    --settings) show_settings ;;
    auto)
        if should_be_dark; then
            current=$(grep "current_mode" "${CONFIG_FILE}" 2>/dev/null | cut -d= -f2 | tr -d ' ' || echo "")
            [[ "${current}" != "dark" ]] && apply_dark_mode
        else
            current=$(grep "current_mode" "${CONFIG_FILE}" 2>/dev/null | cut -d= -f2 | tr -d ' ' || echo "")
            [[ "${current}" != "light" ]] && apply_light_mode
        fi
        ;;
esac
