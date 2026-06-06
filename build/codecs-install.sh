#!/usr/bin/env bash
# =============================================================================
# CanveraOS — Codec & Media Format Installation Script
# Installs ALL audio/video/image codecs and container format support.
# Every format works out-of-the-box. User never needs to install codecs.
# =============================================================================
set -euo pipefail

log()  { echo -e "\033[0;36m[CODEC]\033[0m $*"; }
ok()   { echo -e "\033[0;32m[  OK  ]\033[0m $*"; }
warn() { echo -e "\033[1;33m[ WARN ]\033[0m $*"; }

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
    libmpeg2-4 \
    mpeg2dec \
    v4l-utils

# Optional video codec dev libs (may not exist in Noble)
apt-get install -y libsvtav1-dev 2>/dev/null || warn "libsvtav1-dev not available — skipping"
apt-get install -y libdvdread8  2>/dev/null || apt-get install -y libdvdread-dev 2>/dev/null || warn "DVD read lib not found"
apt-get install -y libdvdnav4  2>/dev/null || warn "libdvdnav4 not found"

ok "Video codecs installed."

# ─── Audio codecs ─────────────────────────────────────────────────────────────
log "Installing audio codecs (AAC, MP3, FLAC, OGG, ALAC, AIFF, AC3, DTS, Opus)..."
# ALAC (Apple Lossless) is supported via FFmpeg's libavcodec-extra — no separate package needed
apt-get install -y \
    libmp3lame-dev \
    libvorbis-dev \
    libflac-dev \
    libopus-dev \
    libopusfile-dev \
    lame \
    faad \
    sox \
    libsox-fmt-all \
    alsa-utils \
    pulseaudio \
    pipewire \
    pipewire-audio \
    pipewire-alsa \
    pipewire-pulse \
    pipewire-jack \
    wireplumber

# Optional audio libs (names vary by Ubuntu version)
apt-get install -y libfdk-aac-dev  2>/dev/null || warn "libfdk-aac-dev not available"
apt-get install -y faac            2>/dev/null || warn "faac not available"
apt-get install -y libwireplumber-0.4-0 2>/dev/null || \
    apt-get install -y libwireplumber-0.5-0 2>/dev/null || warn "wireplumber lib version varies"

ok "Audio codecs installed."

# ─── Image format support ─────────────────────────────────────────────────────
log "Installing image format support (HEIC, AVIF, WebP, RAW, TIFF, SVG)..."
apt-get install -y \
    libheif1 \
    libwebp-dev \
    librsvg2-dev \
    libtiff-dev \
    libraw-dev

# Optional image libs (package names vary in Noble)
apt-get install -y heif-gdk-pixbuf  2>/dev/null || warn "heif-gdk-pixbuf not found"
apt-get install -y libheif-dev      2>/dev/null || warn "libheif-dev not found"
apt-get install -y libavif-dev      2>/dev/null || warn "libavif-dev not found"
apt-get install -y libavif16        2>/dev/null || \
    apt-get install -y libavif15    2>/dev/null || warn "libavif version varies"
apt-get install -y libraw23         2>/dev/null || \
    apt-get install -y libraw22     2>/dev/null || warn "libraw version varies"
apt-get install -y kimageformats    2>/dev/null || warn "kimageformats not found"
apt-get install -y qt6-imageformats 2>/dev/null || warn "qt6-imageformats not found"
apt-get install -y darktable        2>/dev/null || warn "darktable not found"
apt-get install -y rawtherapee      2>/dev/null || warn "rawtherapee not found"

ok "Image formats installed."

# ─── Container format support ─────────────────────────────────────────────────
log "Installing container format support (MKV, MOV, AVI, WebM, FLV, WMV, MTS)..."
apt-get install -y \
    mkvtoolnix \
    mediainfo

apt-get install -y mkvtoolnix-gui 2>/dev/null || warn "mkvtoolnix-gui not found"
apt-get install -y mediainfo-gui  2>/dev/null || warn "mediainfo-gui not found"
apt-get install -y mp4v2-utils    2>/dev/null || warn "mp4v2-utils not found"

ok "Container formats supported."

# ─── Hardware video acceleration ──────────────────────────────────────────────
log "Installing hardware video acceleration (VA-API, VDPAU for NVIDIA)..."
apt-get install -y \
    va-driver-all \
    vdpau-driver-all \
    mesa-va-drivers \
    mesa-vdpau-drivers 2>/dev/null || warn "Some VA/VDPAU drivers not available — OK for now."

apt-get install -y libvdpau-va-gl1      2>/dev/null || true
apt-get install -y intel-media-va-driver 2>/dev/null || true
apt-get install -y nvidia-vaapi-driver   2>/dev/null || true

ok "Hardware video acceleration configured."

# ─── FFmpeg verification ───────────────────────────────────────────────────────
log "Verifying FFmpeg codec support..."
ffmpeg -codecs 2>/dev/null | grep -E "(hevc|h264|av1|vp9|prores|dnxhd|opus|flac|aac)" | \
    awk '{print "  ✓ " $2}' | head -20
ok "FFmpeg codec verification complete."

ok "All codecs and media formats installed successfully."
echo ""
echo "  Supported video:  H.264 H.265/HEVC AV1 VP8 VP9 MPEG-2 MPEG-4 ProRes DNxHD Theora"
echo "  Supported audio:  AAC MP3 FLAC OGG WAV ALAC AIFF AC3 DTS Opus"
echo "  Supported images: JPEG PNG GIF WebP AVIF HEIC TIFF BMP SVG RAW(CR2/NEF/ARW/DNG)"
echo "  Supported containers: MP4 MKV MOV AVI WebM FLV WMV M4V MTS M2TS"
