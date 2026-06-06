#!/usr/bin/env bash
# =============================================================================
# CanveraOS — Multi-Monitor Setup Script
# Adds KDE top panel and Plank dock to ALL connected monitors.
# Also applies the highest available refresh rate per monitor.
# Runs from first-boot.sh after the desktop is fully loaded.
# =============================================================================
set -euo pipefail

log()  { echo "[MULTIMON] $*"; }
warn() { echo "[MULTIMON WARN] $*"; }

# ─── Wait for KDE compositor + plasmashell to be ready ───────────────────────
sleep 8

# ─── Count connected monitors ─────────────────────────────────────────────────
NUM_MONITORS=$(xrandr --query 2>/dev/null | grep -c " connected" || echo 1)
log "Detected ${NUM_MONITORS} connected monitor(s)."

if [[ "${NUM_MONITORS}" -le 1 ]]; then
    log "Single monitor — no multi-monitor setup needed."
else
    log "Multi-monitor detected — adding panels to all screens..."

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

// App launcher on left
var kick = panel.addWidget('org.kde.plasma.kickoff');

// Global menu (shows active app menus — macOS style)
var menu = panel.addWidget('org.kde.plasma.appmenu');

// Spacer — push clock to center
var spacer1 = panel.addWidget('org.kde.plasma.panelspacer');

// Clock in center
var clock = panel.addWidget('org.kde.plasma.digitalclock');

// Spacer — push tray to right
var spacer2 = panel.addWidget('org.kde.plasma.panelspacer');

// System tray on right
var tray = panel.addWidget('org.kde.plasma.systemtray');
" 2>/dev/null || warn "Could not add panel to screen ${i}"
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
    sleep 0.3
done
log "Plank running on all ${NUM_MONITORS} monitor(s)."

# ─── Set maximum refresh rate on all monitors ─────────────────────────────────
log "Applying maximum available refresh rates..."

# Get all connected output names (e.g. HDMI-1, DP-1, eDP-1)
mapfile -t OUTPUTS < <(xrandr --query 2>/dev/null | grep " connected" | awk '{print $1}')

for OUTPUT in "${OUTPUTS[@]}"; do
    log "Processing output: ${OUTPUT}"

    # Get all available refresh rates for this output's current mode
    CURRENT_MODE=$(xrandr --query 2>/dev/null | grep -A1 "^${OUTPUT}" | \
        tail -1 | awk '{print $1}')

    if [[ -z "${CURRENT_MODE}" ]]; then
        warn "Could not detect current mode for ${OUTPUT}"
        continue
    fi

    # Get the highest refresh rate available for this mode
    # xrandr output looks like: "  1920x1080     60.00*+  50.00  59.94"
    MAX_RATE=$(xrandr --query 2>/dev/null | grep -A20 "^${OUTPUT}" | \
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

log "Multi-monitor setup complete."
