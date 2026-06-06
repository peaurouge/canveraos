#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# CanveraOS — Calamares post-install script
# Runs at the END of installation inside the TARGET system.
# Creates /etc/canvera-installed marker so the installer doesn't re-launch.

import os
import subprocess
import libcalamares

def run():
    """Create installation marker and clean up live-only files."""
    root_mount = libcalamares.globalstorage.value("rootMountPoint")
    if not root_mount:
        return None

    # Create marker file so first-boot knows this is an installed system
    marker_path = os.path.join(root_mount, "etc", "canvera-installed")
    try:
        with open(marker_path, "w") as f:
            f.write("CanveraOS installation complete\n")
    except Exception as e:
        libcalamares.utils.warning(f"Could not create canvera-installed marker: {e}")

    # Remove the installer autostart from the installed system
    # (The installer should not auto-launch on the installed system)
    autostart_path = os.path.join(
        root_mount,
        "etc", "skel", ".config", "autostart", "canvera-installer.desktop"
    )
    try:
        if os.path.exists(autostart_path):
            os.remove(autostart_path)
    except Exception:
        pass

    # Also remove it from any created user homes
    home_base = os.path.join(root_mount, "home")
    if os.path.isdir(home_base):
        for user_dir in os.listdir(home_base):
            user_autostart = os.path.join(
                home_base, user_dir,
                ".config", "autostart", "canvera-installer.desktop"
            )
            try:
                if os.path.exists(user_autostart):
                    os.remove(user_autostart)
            except Exception:
                pass

    # Remove live-only sudoers rule (NOPASSWD for ubuntu user)
    # This is live session only — installed users have proper passwords
    live_sudoers = os.path.join(root_mount, "etc", "sudoers.d", "90-canvera-live")
    try:
        if os.path.exists(live_sudoers):
            os.remove(live_sudoers)
    except Exception:
        pass

    libcalamares.utils.debug("CanveraOS post-install cleanup complete.")
    return None
