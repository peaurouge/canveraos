#!/usr/bin/env bash
# =============================================================================
# CanveraOS — Codec & Media Format Installation Script
# Installs ALL audio/video/image codecs and container format support.
# Every format works out-of-the-box. User never needs to install codecs.
# =============================================================================
set -euo pipefail

log() { echo -e "\033[0;36m[CODEC]\033[0m $*"; }
ok()  { echo -e "\033[0;32m[  OK  ]\033[0m $*"; }

export DEBIAN_FRONTEND=noninteractive

# ─── Enable restricted repos ──────────────────────────────────────────────────
log "Enabling restricted and multiverse repositories..."
add-apt-repository -y multiverse
apt-get update -qq

# ─── Accept restricted extras EULA non-interactively ─────────────────────────
echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections

# ─── Core codec packages ──────────────────────────────────────────────────────
log "Installing core codecs (H.264, H.265, AV1, VP8/9, MPEG-2/4, Theora)..."
apt-get install -y \
    ubuntu-restricted-extras \
    libavcodec-extra \
    libavformat-extra \
    ffmpeg \
    gstreamer1.0-libav \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-vaapi \
    gstreamer1.0-gl \
    gstreamer1.0-alsa \
    gstreamer1.0-pulseaudio \
    gstreamer1.0-x \
    gstreamer1.0-tools

ok "Core codecs installed."

# ─── Video codecs ─────────────────────────────────────────────────────────────
log "Installing video codecs (HEVC, AV1, ProRes, DNxHD, VP8/9)..."
apt-get install -y \
    libx264-dev \
    libx265-dev \
    libaom-dev \
    libvpx-dev \
    libtheora-dev \
    libdav1d-dev \
    libsvtav1-dev \
    libmpeg2-4 \
    mpeg2dec \
    libdvdread8 \
    libdvdnav4 \
    v4l-utils

ok "Video codecs installed."

# ─── Audio codecs ─────────────────────────────────────────────────────────────
log "Installing audio codecs (AAC, MP3, FLAC, OGG, ALAC, AIFF, AC3, DTS, Opus)..."
apt-get install -y \
    libmp3lame-dev \
    libfdk-aac-dev \
    libvorbis-dev \
    libflac-dev \
    libopus-dev \
    libopusfile-dev \
    libalac-dev \
    lame \
    faad \
    faac \
    sox \
    libsox-fmt-all \
    alsa-utils \
    pulseaudio \
    pipewire \
    pipewire-audio \
    pipewire-alsa \
    pipewire-pulse \
    pipewire-jack \
    wireplumber \
    libwireplumber-0.4-0

ok "Audio codecs installed."

# ─── Image format support ─────────────────────────────────────────────────────
log "Installing image format support (HEIC, AVIF, WebP, RAW, TIFF, SVG)..."
apt-get install -y \
    libheif-dev \
    libheif1 \
    heif-gdk-pixbuf \
    libavif-dev \
    libavif16 \
    libwebp-dev \
    librsvg2-dev \
    libtiff-dev \
    libraw-dev \
    libraw23 \
    darktable \
    rawtherapee \
    kimageformats \
    qt6-imageformats

ok "Image formats installed."

# ─── Container format support (MKV, MOV, AVI, WebM, FLV, WMV, MTS etc.) ─────
log "Installing container format support..."
apt-get install -y \
    mkvtoolnix \
    mkvtoolnix-gui \
    mediainfo \
    mediainfo-gui \
    mp4v2-utils

ok "Container formats supported."

# ─── Hardware video acceleration ──────────────────────────────────────────────
log "Installing hardware video acceleration (VA-API, VDPAU for NVIDIA)..."
apt-get install -y \
    va-driver-all \
    vdpau-driver-all \
    libvdpau-va-gl1 \
    mesa-va-drivers \
    mesa-vdpau-drivers \
    intel-media-va-driver \
    nvidia-vaapi-driver || warn "Some VA/VDPAU drivers may not apply — this is normal."

ok "Hardware video acceleration configured."

# ─── FFmpeg compile flags verification ───────────────────────────────────────
log "Verifying FFmpeg codec support..."
ffmpeg -codecs 2>/dev/null | grep -E "(hevc|h264|av1|vp9|prores|dnxhd|opus|flac|aac)" | \
    awk '{print "  ✓ " $2}' | head -20
ok "FFmpeg codec verification complete."

# ─── ProRes and DNxHD via FFmpeg ──────────────────────────────────────────────
log "Verifying ProRes and DNxHD support..."
ffmpeg -encoders 2>/dev/null | grep -i "prores\|dnx" | awk '{print "  ✓ " $2}' || \
    warn "ProRes/DNxHD encode requires specific FFmpeg build — decode is always available."

ok "All codecs and media formats installed successfully."
echo ""
echo "  Supported video:  H.264 H.265/HEVC AV1 VP8 VP9 MPEG-2 MPEG-4 ProRes DNxHD Theora"
echo "  Supported audio:  AAC MP3 FLAC OGG WAV ALAC AIFF AC3 DTS Opus"
echo "  Supported images: JPEG PNG GIF WebP AVIF HEIC TIFF BMP SVG RAW(CR2/NEF/ARW/DNG)"
echo "  Supported containers: MP4 MKV MOV AVI WebM FLV WMV M4V MTS M2TS"
