# CanveraOS

> **A bootable Linux distribution for creative professionals.**
> Built on Ubuntu 24.04 LTS + KDE Plasma 6 with macOS Tahoe-inspired design.

---

## Build the ISO

The ISO is built automatically in the cloud via GitHub Actions — no Linux machine needed.

**To build:**
1. Go to the **Actions** tab above
2. Click **"🏗️ Build CanveraOS ISO"**
3. Click **"Run workflow"** → **"Run workflow"**
4. Wait ~90 minutes
5. Download the ISO from the **Releases** page

See [docs/GITHUB-UPLOAD-GUIDE.md](docs/GITHUB-UPLOAD-GUIDE.md) for detailed step-by-step instructions.

---

## What's Included

| Feature | Details |
|---|---|
| Base OS | Ubuntu 24.04 LTS |
| Desktop | KDE Plasma 6 (Wayland + X11) |
| Theme | macOS Tahoe-inspired (frosted glass, traffic-light buttons, Inter font) |
| GPU | NVIDIA driver downloaded during installation |
| Adobe CC | Photoshop, Illustrator, Premiere, After Effects, Lightroom via CrossOver |
| Video | DaVinci Resolve native + CUDA acceleration |
| Codecs | H.264, H.265, AV1, ProRes, DNxHD, HEIC, RAW, and more |
| File Manager | Dolphin (3 views: Icon, List, Column) with Quick Look |
| Dark Mode | Automatic schedule + instant toggle |
| Apps | VLC, Steam+Proton, Telegram, WhatsApp, Home Assistant, Organic Maps |
| M365 | Outlook, Teams, OneDrive as PWAs + Word/Excel/PowerPoint via CrossOver |
| Security | UFW, AppArmor, LUKS encryption option |
| Filesystems | NTFS, ExFAT, FAT32, APFS (read/write) |

---

## Keyboard Shortcuts (macOS-compatible)

| Action | Shortcut |
|---|---|
| Command Palette | `Super + Space` |
| Close window | `Super + W` |
| Screenshot area | `Super + Shift + 4` |
| Clipboard manager | `Super + Shift + V` |
| Lock screen | `Super + Ctrl + Q` |

---

## Documentation

- [📖 Build Guide](docs/BUILD.md) — how the ISO is built
- [🚀 GitHub Upload Guide](docs/GITHUB-UPLOAD-GUIDE.md) — step-by-step for non-developers

---

*CanveraOS v1.0.0 "Aurora" — Built for those who make things.*
