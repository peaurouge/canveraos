# CanveraOS — Complete Build Guide

> **You are reading the official CanveraOS ISO build guide.**
> Every step is explained in plain English. No terminal expertise required to understand it —
> but you will be running commands on your Pop!_OS build machine.

---

## What You Need Before Starting

| Requirement | Details |
|---|---|
| **Build machine** | Your Pop!_OS machine (Ubuntu 24.04 compatible ✅) |
| **Disk space** | At least **40 GB free** (the ISO workspace + final ISO) |
| **RAM** | 8 GB minimum (16 GB recommended for fast builds) |
| **Internet** | Fast connection — ~6 GB of packages to download |
| **Time** | First build: 60–90 minutes. Subsequent builds: 30–45 min |
| **Privileges** | You must run the build as `root` (sudo) |
| **CrossOver** | Your CrossOver license key (enter on first boot) |

---

## Project Structure

```
CanveraOS/
├── build/                 # Scripts that run on your build machine
│   ├── build-iso.sh       ← START HERE — master builder
│   ├── chroot-setup.sh    — installs everything inside the system
│   ├── codecs-install.sh  — all media codecs
│   ├── apps-install.sh    — all applications
│   └── squashfs-pack.sh   — creates the final ISO file
├── config/
│   ├── kde/               — KDE Plasma theme + desktop settings
│   ├── crossover/         — CrossOver + Adobe CC setup
│   ├── apps/dolphin/      — File manager (Finder-style) settings
│   └── window-manager/    — Window size memory + snapping rules
├── theme/
│   ├── kvantum/           — Glassmorphism widget theme
│   ├── plasma/            — Light + Dark color schemes
│   └── wallpapers/        — CanveraOS default wallpapers
├── installer/
│   └── calamares/         — Graphical installer configuration
│       ├── settings.conf  — Installation step sequence
│       ├── branding/      — Installer look and feel
│       └── modules/       — Each installation step's settings
└── scripts/
    ├── first-boot.sh      — Runs once after user first logs in
    ├── dark-mode-scheduler.sh — Automatic light/dark switching
    └── workspace-modes.sh — Smart workspace layouts
```

---

## Step-by-Step Build Instructions

### Step 1 — Copy the Project to Your Build Machine

On your **Pop!_OS machine**, clone or copy this repository:

```bash
# If using git:
git clone <your-repo-url> ~/CanveraOS-build
cd ~/CanveraOS-build

# If copying from USB/network:
cp -r /path/to/CanveraOS ~/CanveraOS-build
cd ~/CanveraOS-build
```

---

### Step 2 — Install Build Dependencies

Run this ONCE on your Pop!_OS machine to install the tools needed to build ISOs:

```bash
sudo apt-get update
sudo apt-get install -y \
    debootstrap squashfs-tools xorriso grub-pc-bin \
    grub-efi-amd64-bin mtools dosfstools isolinux \
    syslinux-utils curl wget rsync python3 git
```

**What these do:**
- `debootstrap` — downloads and sets up a fresh Ubuntu base system
- `squashfs-tools` — compresses the filesystem into the ISO
- `xorriso` — creates the final bootable ISO file
- `grub-pc-bin` / `grub-efi-amd64-bin` — makes it bootable on any PC (BIOS + UEFI)

---

### Step 3 — Place Your CanveraOS Logo

Put your logo file at:
```
theme/canvera-logo.png
```

Requirements:
- Format: PNG with transparent background
- Size: 512×512 pixels (will be scaled automatically)
- Also copy it to `installer/calamares/branding/canvera-logo.png`

---

### Step 4 — Run the Master Build Script

```bash
cd ~/CanveraOS-build
sudo bash build/build-iso.sh
```

**What happens (you'll see progress for each step):**

1. ✅ Checks all build dependencies are installed
2. ✅ Downloads Ubuntu 24.04 base (~400 MB)
3. ✅ Creates an isolated build environment (chroot)
4. ✅ Installs KDE Plasma 6 desktop
5. ✅ Installs all media codecs (H.265, AV1, ProRes, etc.)
6. ✅ Installs CrossOver + pre-configures Adobe CC bottles
7. ✅ Installs all default apps (VLC, Telegram, Steam, etc.)
8. ✅ Applies macOS Tahoe visual theme
9. ✅ Packs everything into a compressed SquashFS
10. ✅ Wraps it in a bootable ISO with GRUB

**Build output:** `CanveraOS-1.0.0-amd64.iso` in the project root.

---

### Step 5 — Flash to USB and Test

**Using the terminal:**
```bash
# Find your USB drive (look for /dev/sdb, /dev/sdc, etc.)
lsblk

# Flash the ISO (replace /dev/sdX with your actual USB drive!)
sudo dd if=CanveraOS-1.0.0-amd64.iso of=/dev/sdX bs=4M status=progress
sync
```

**Using a GUI tool (recommended):**
- Install **Balena Etcher** from [etcher.balena.io](https://etcher.balena.io)
- Select the ISO file
- Select your USB drive
- Click Flash

> ⚠️ **WARNING**: Flashing will erase everything on the USB drive. Make sure you select the right drive!

---

## Installation Wizard — What the User Sees

When the USB boots on the target machine (Intel 12th gen + RTX 4090), the user sees:

### Page 1: Welcome
- CanveraOS logo, version, system requirements check
- Shows green checkmarks for: disk space, RAM, internet

### Page 2: Language & Locale
- Pre-selected: English (United States)
- One click to continue

### Page 3: Keyboard Layout
- Auto-detected from hardware
- User can change if needed

### Page 4: Disk Setup
- **Guided (Erase disk)** — recommended, one click
- **Manual** — advanced users only
- Optional: Full Disk Encryption checkbox (LUKS)
- Shows disk space visualization

### Page 5: User Account
- Full name, username, password
- Computer name (default: "canvera")
- Auto-login checkbox (default: off)

### Page 6: Installation Progress
- Animated slideshow explaining CanveraOS features
- Progress bar shows each step
- **NVIDIA GPU step**: Downloads and installs NVIDIA driver 570
  - If internet is available → installs now (~500 MB download)
  - If offline → schedules for first boot

### Page 7: Done!
- "Restart Now" button
- System reboots into CanveraOS

---

## First Boot Experience

1. **SDDM Login Screen** — CanveraOS branding, frosted glass, username/password
2. **Login** → KDE Plasma loads with macOS Tahoe theme
3. **First Boot Wizard** (automatic, GUI):
   - Configures keyboard shortcuts (macOS-style)
   - Asks about CrossOver license
   - Shows how to open Adobe apps
   - Everything explained with dialogs — no terminal
4. **Desktop** — dock at bottom, menu bar at top, ready to use

---

## Keyboard Shortcuts (macOS-Compatible)

| Action | Shortcut |
|---|---|
| Command Palette / Spotlight | `Super + Space` |
| Switch windows | `Super + Tab` |
| Close window | `Super + W` |
| Minimize window | `Super + M` |
| Maximize window | `Super + Ctrl + F` |
| Screenshot (full screen) | `Super + Shift + 3` |
| Screenshot (select area) | `Super + Shift + 4` |
| Screenshot (window) | `Super + Shift + 5` |
| Clipboard Manager | `Super + Shift + V` |
| Lock screen | `Super + Ctrl + Q` |
| Left desktop | `Super + Ctrl + ←` |
| Right desktop | `Super + Ctrl + →` |

> **Note**: "Super" key = the Windows/Meta key on a standard keyboard.
> On an Apple keyboard, Super = Command (⌘).

---

## File Manager (Dolphin — Finder Style)

| Feature | How to use it |
|---|---|
| **Icon/Thumbnail view** | Click the grid icon in toolbar |
| **Detail/List view** | Click the list icon in toolbar |
| **Column view** | Click the column icon in toolbar |
| **Quick Look** | Press `Space` on any file |
| **Tags** | Right-click → Tags → choose color |
| **Search** | `Ctrl+F` or type in the search bar |
| **New folder** | `Ctrl+Shift+N` or right-click |
| **Show hidden files** | `Ctrl+H` |

---

## Dark Mode

**Automatic (default):**
- Dark mode: 7:00 PM → 7:00 AM
- Light mode: 7:00 AM → 7:00 PM

**Manual toggle:**
- Click the moon/sun icon in the menu bar
- Or: Right-click desktop → Toggle Dark Mode

**Change schedule:**
- Click moon icon in menu bar → Settings
- Or: System Settings → Appearance → Dark Mode

---

## Smart Workspace Modes

Click the **Workspace Modes** icon in the dock:

| Mode | What it does |
|---|---|
| 🎬 Video Edit | Dark mode, launches DaVinci Resolve |
| 🎨 Design | Dark mode, launches Photoshop + Illustrator |
| ✍️ Writing | Light mode, launches Kate text editor |
| 🎮 Gaming | Dark mode, launches Steam |
| 🌐 Browsing | Opens Chromium |
| Save Custom | Saves your current layout as a named mode |

---

## Adobe CC — How It Works

1. Click **Adobe Photoshop** (or any Adobe app) in the dock
2. A dialog appears: "Photoshop needs to be installed first"
3. Click OK → Creative Cloud installer downloads automatically
4. Adobe Creative Cloud opens → **Log in with your Adobe ID**
5. Install Photoshop from the Creative Cloud app
6. Done — Photoshop opens natively next time

> This uses CrossOver (not Wine). CrossOver is pre-configured with all
> required Windows runtimes (VC++ 2019, .NET 4.8, DirectX). No setup needed.

---

## Troubleshooting

### Build fails with "debootstrap error"
- Check internet connection
- Try: `sudo debootstrap --verbose --arch=amd64 noble /tmp/test-chroot`

### NVIDIA driver not installing during setup
- This is expected if there's no internet during install
- After first boot: look for "Install GPU Driver" notification
- Or: Open System Settings → Drivers

### CrossOver apps showing "Trial" warning
- Open CrossOver from Applications
- Go to CrossOver → Activate CrossOver
- Enter your license key

### Adobe apps not opening
- Make sure CrossOver is activated with your license
- Click the app icon → follow the installation wizard

### Dark mode not switching automatically
- Open Terminal (Konsole) and run: `systemctl --user status canvera-dark-mode.timer`
- If stopped: `systemctl --user start canvera-dark-mode.timer`

---

## Rebuilding After Changes

To rebuild the ISO after modifying any config or script:

```bash
cd ~/CanveraOS-build

# Quick rebuild (keeps existing chroot, just repacks)
sudo bash build/squashfs-pack.sh \
    build-workspace/chroot \
    build-workspace/iso \
    CanveraOS-1.0.0-amd64.iso \
    .

# Full rebuild from scratch (clean slate)
sudo rm -rf build-workspace/
sudo bash build/build-iso.sh
```

---

## File to Edit for Common Changes

| What to change | File to edit |
|---|---|
| Add/remove applications | `build/apps-install.sh` |
| Change dark mode schedule default | `config/kde/plasma-apply-theme.sh` |
| Change color scheme | `theme/plasma/CanveraOSDark.colors` |
| Change Dock apps | `config/kde/latte-layout.sh` (in plasma-apply-theme.sh) |
| Add CrossOver bottles | `config/crossover/crossover-setup.sh` |
| Change installer steps | `installer/calamares/settings.conf` |
| Change installer branding | `installer/calamares/branding/branding.desc` |
| Change keyboard shortcuts | `scripts/first-boot.sh` |
| Change workspace modes | `scripts/workspace-modes.sh` |

---

## What's in Each ISO Build

| Category | What's included |
|---|---|
| Base OS | Ubuntu 24.04 LTS kernel + drivers |
| Desktop | KDE Plasma 6 + Wayland + SDDM |
| Theme | WhiteSur icons, Kvantum glassmorphism, Klassy window decorations |
| Fonts | Inter, Noto, Liberation |
| File Manager | Dolphin with all thumbnail plugins |
| Codecs | H.264, H.265, AV1, VP9, ProRes, DNxHD + all audio codecs |
| Filesystems | ext4, btrfs, NTFS, ExFAT, FAT32, APFS (read/write) |
| Apps | VLC, Telegram, Steam, WhatsApp, Home Assistant, Organic Maps |
| Adobe | CrossOver + pre-configured bottles (Photoshop, Premiere, etc.) |
| Office | CrossOver bottles (Word, Excel, PowerPoint) |
| M365 PWAs | Outlook, Teams, OneDrive as dock icons |
| Tools | CopyQ clipboard manager, Spectacle screenshots, Baloo search |
| Security | UFW firewall, AppArmor, LUKS encryption option |
| NVIDIA | Downloaded and installed during setup (not baked in) |

---

*CanveraOS v1.0.0 — Built for creative professionals.*
