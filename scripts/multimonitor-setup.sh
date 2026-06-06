#!/usr/bin/env bash
# =============================================================================
# CanveraOS — Multi-Monitor Setup Script
# Adds KDE top panel and Plank dock to ALL connected monitors.
# Also applies the highest available refresh rate per monitor.
# Runs from first-boot.sh after the desktop is fully loaded.
#
# NOTE: Do NOT use 'set -euo pipefail' here.
# This script runs as a background process (&) from first-boot.sh.
# Many commands (qdbus, xrandr, plank) can fail if the desktop is not
# fully ready yet — failures must be silent, not fatal.
# =============================================================================

log()  { echo "[MULTIMON] $*" 2>/dev/null || true; }
warn() { echo "[MULTIMON WARN] $*" 2>/dev/null || true; }

# ─── Wait for KDE compositor + plasmashell to be ready ───────────────────────
sleep 12

# ─── Count connected monitors ─────────────────────────────────────────────────
NUM_MONITORS=$(xrandr --query 2>/dev/null | grep -c " connected" || echo "1")
log "Detected ${NUM_MONITORS} connected monitor(s)."

if [[ "${NUM_MONITORS}" -le 1 ]]; then
    log "Single monitor — no multi-monitor panel setup needed."
else
    log "Multi-monitor detected — adding panels to secondary screens..."

    # ── Add KDE top panel to each secondary monitor ──────────────────────────
    for i in $(seq 1 $((NUM_MONITORS - 1))); do
        log "Adding top panel to screen ${i}..."
        qdbus org.kde.plasmashell /PlasmaShell \
            org.kde.PlasmaShell.evaluateScript "
var panel = new Panel;
panel.location = 'top';
panel.screen = ${i};
panel.height = 28;
panel.maximumLength = 32767;
panel.minimumLength = 0;
panel.floating = false;
panel.hiding = 'none';

var kick = panel.addWidget('org.kde.plasma.kickoff');
var menu = panel.addWidget('org.kde.plasma.appmenu');
var spacer1 = panel.addWidget('org.kde.plasma.panelspacer');
var clock = panel.addWidget('org.kde.plasma.digitalclock');
var spacer2 = panel.addWidget('org.kde.plasma.panelspacer');
var tray = panel.addWidget('org.kde.plasma.systemtray');
" 2>/dev/null || warn "Could not add panel to screen ${i} (desktop may not be ready)"
    done
    log "Panels added to all monitors."
fi

# ─── Restart Plank on ALL monitors ────────────────────────────────────────────
log "Restarting Plank on all monitors..."
pkill -x plank 2>/dev/null || true
sleep 2

# Start one Plank instance per monitor
for i in $(seq 0 $((NUM_MONITORS - 1))); do
    log "Starting Plank on monitor ${i}..."
    plank --monitor="${i}" &
    sleep 0.5
done
log "Plank running on all ${NUM_MONITORS} monitor(s)."

# ─── Set maximum refresh rate on all monitors ─────────────────────────────────
log "Applying maximum available refresh rates..."

# Get all connected output names (e.g. HDMI-1, DP-1, eDP-1)
mapfile -t OUTPUTS < <(xrandr --query 2>/dev/null | grep " connected" | awk '{print $1}')

if [[ ${#OUTPUTS[@]} -eq 0 ]]; then
    warn "No outputs detected by xrandr (Wayland session?). Skipping refresh rate change."
else
    for OUTPUT in "${OUTPUTS[@]}"; do
        log "Processing output: ${OUTPUT}"

        # Get all available refresh rates for this output's current mode
        CURRENT_MODE=$(xrandr --query 2>/dev/null | \
            awk "/^${OUTPUT} /{found=1; next} found && /^  /{print \$1; exit} /^[^ ]/{found=0}" 2>/dev/null || echo "")

        if [[ -z "${CURRENT_MODE}" ]]; then
            warn "Could not detect current mode for ${OUTPUT}"
            continue
        fi

        # Get the highest refresh rate available for this mode
        MAX_RATE=$(xrandr --query 2>/dev/null | \
            grep -A 20 "^${OUTPUT}" | \
            grep "${CURRENT_MODE}" | \
            grep -oP '[0-9]+\.[0-9]+' | \
            sort -rn | head -1)

        if [[ -n "${MAX_RATE}" ]]; then
            log "Setting ${OUTPUT} to ${CURRENT_MODE} @ ${MAX_RATE}Hz"
            xrandr --output "${OUTPUT}" --mode "${CURRENT_MODE}" --rate "${MAX_RATE}" \
                2>/dev/null || warn "Could not set ${MAX_RATE}Hz on ${OUTPUT}"
        else
            warn "Could not detect refresh rate for ${OUTPUT}"
        fi
    done
fi

log "Multi-monitor setup complete."
