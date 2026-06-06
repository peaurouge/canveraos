#!/usr/bin/env python3
# =============================================================================
# CanveraOS — Calamares NVIDIA Driver Module
# This is a Python Calamares module that runs during installation.
# It detects NVIDIA hardware and downloads + installs the appropriate driver.
# No terminal. Pure GUI. Fully automatic.
# =============================================================================

import subprocess
import libcalamares
from libcalamares.utils import debug, warning

def pretty_name():
    return "Setting up GPU Drivers"

def pretty_status_message():
    return "Configuring graphics drivers for best performance..."

def detect_nvidia():
    """Detect if an NVIDIA GPU is present."""
    try:
        result = subprocess.run(
            ["lspci", "-nn"],
            capture_output=True, text=True, timeout=10
        )
        lines = result.stdout.lower()
        nvidia_cards = [l for l in lines.split('\n') if 'nvidia' in l and ('vga' in l or '3d' in l or 'display' in l)]
        if nvidia_cards:
            debug(f"NVIDIA GPU detected: {nvidia_cards[0]}")
            return True, nvidia_cards[0]
        return False, None
    except Exception as e:
        warning(f"GPU detection failed: {e}")
        return False, None

def check_internet():
    """Check if internet is available for driver download."""
    try:
        result = subprocess.run(
            ["ping", "-c", "1", "-W", "3", "archive.ubuntu.com"],
            capture_output=True, timeout=5
        )
        return result.returncode == 0
    except Exception:
        return False

def install_nvidia_driver(root_mount_point):
    """Install NVIDIA driver in the target system."""
    target = root_mount_point

    # Add NVIDIA PPA for latest drivers
    subprocess.run(
        ["chroot", target, "add-apt-repository", "-y", "ppa:graphics-drivers/ppa"],
        check=True, capture_output=True
    )
    subprocess.run(
        ["chroot", target, "apt-get", "update", "-qq"],
        check=True, capture_output=True
    )

    # Install driver (570 is the latest stable for RTX 4090)
    subprocess.run(
        ["chroot", target, "apt-get", "install", "-y",
         "nvidia-driver-570",
         "nvidia-dkms-570",
         "nvidia-cuda-toolkit",
         "nvidia-settings",
         "nvidia-prime",
         "libvdpau1",
         "libvdpau-dev",
         "vdpau-driver-all",
         "libnvcuvid1",
         "libnvidia-encode1"],
        check=True
    )

    # Blacklist nouveau
    with open(f"{target}/etc/modprobe.d/blacklist-nouveau.conf", "w") as f:
        f.write("blacklist nouveau\noptions nouveau modeset=0\n")

    # Enable DRM KMS (required for Wayland + NVIDIA)
    with open(f"{target}/etc/modprobe.d/nvidia-kms.conf", "w") as f:
        f.write("options nvidia-drm modeset=1 fbdev=1\n")

    # Add nvidia modules to initramfs
    modules_file = f"{target}/etc/initramfs-tools/modules"
    with open(modules_file, "a") as f:
        f.write("\nnvidia\nnvidia_modeset\nnvidia_uvm\nnvidia_drm\n")

    # Update initramfs
    subprocess.run(
        ["chroot", target, "update-initramfs", "-u", "-k", "all"],
        check=True
    )

    return True

def run():
    """Main entry point called by Calamares."""
    root_mount_point = libcalamares.globalstorage.value("rootMountPoint")
    if not root_mount_point:
        return ("No target system found",
                "Could not locate the installation target. Please retry.")

    has_nvidia, gpu_info = detect_nvidia()

    if not has_nvidia:
        debug("No NVIDIA GPU detected. Skipping NVIDIA driver installation.")
        libcalamares.job.setprogress(1.0)
        return None

    debug(f"NVIDIA GPU found: {gpu_info}")

    if not check_internet():
        # No internet — create a post-install reminder script
        warning("No internet connection. NVIDIA driver will be installed on first boot.")
        target = root_mount_point

        with open(f"{target}/usr/local/bin/canvera-install-nvidia", "w") as f:
            f.write("""#!/bin/bash
# CanveraOS — NVIDIA Driver Installer (deferred)
zenity --info --title="CanveraOS GPU Setup" \\
    --text="Your NVIDIA GPU requires a driver for best performance.\\n\\nConnect to the internet and click OK to install automatically." \\
    --width=400

if ping -c 1 archive.ubuntu.com &>/dev/null; then
    add-apt-repository -y ppa:graphics-drivers/ppa
    apt-get update -qq
    apt-get install -y nvidia-driver-570 nvidia-settings
    zenity --info --title="GPU Driver Installed" \\
        --text="NVIDIA driver installed successfully!\\nPlease restart your computer." \\
        --width=300
    zenity --question --title="Restart?" --text="Restart now?"
    [[ $? -eq 0 ]] && reboot
else
    zenity --error --title="No Internet" \\
        --text="Could not connect to the internet. Please try again later." \\
        --width=300
fi
""")
        subprocess.run(["chmod", "+x", f"{target}/usr/local/bin/canvera-install-nvidia"])

        # Add to autostart for first boot
        autostart_dir = f"{target}/etc/skel/.config/autostart"
        subprocess.run(["mkdir", "-p", autostart_dir])
        with open(f"{autostart_dir}/canvera-nvidia.desktop", "w") as f:
            f.write("""[Desktop Entry]
Name=GPU Driver Setup
Comment=Install NVIDIA driver for your graphics card
Exec=pkexec /usr/local/bin/canvera-install-nvidia
Icon=video-display
Terminal=false
Type=Application
""")
        libcalamares.job.setprogress(1.0)
        return None

    # Internet available — install now
    libcalamares.job.setprogress(0.1)
    debug("Downloading and installing NVIDIA driver 570...")

    try:
        install_nvidia_driver(root_mount_point)
        libcalamares.job.setprogress(1.0)
        debug("NVIDIA driver installation complete.")
        return None
    except subprocess.CalledProcessError as e:
        warning(f"NVIDIA install failed: {e}")
        return ("NVIDIA driver installation failed",
                f"Could not install NVIDIA driver: {e.stderr}\n\n"
                "The system will still boot. You can install the driver manually from System Settings → Drivers.")
