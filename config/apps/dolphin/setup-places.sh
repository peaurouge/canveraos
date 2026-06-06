#!/usr/bin/env bash
# CanveraOS — Dolphin kfileplaces setup
# Creates ~/.local/share/kfileplaces/bookmarks.xml with macOS Finder-style sidebar:
#   Home, Desktop, Documents, Downloads, Music, Pictures, Videos, Trash
# System disk entries (root /, partitions) are hidden.
# Run from first-boot.sh after user home is created.

PLACES_DIR="${HOME}/.local/share/kfileplaces"
PLACES_FILE="${PLACES_DIR}/bookmarks.xml"
mkdir -p "${PLACES_DIR}"

cat > "${PLACES_FILE}" << XMLEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xbel PUBLIC "+//IDN python.org//DTD XML Bookmark Exchange Language 1.0//EN//XML" "http://www.python.org/topics/xml/dtd/xbel-1.0.dtd">
<xbel xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks" xmlns:kdepriv="http://www.kde.org/kdepriv" dbusName="org.kde.fileplaces" noApp="">

 <!-- ══ PLACES (macOS Finder-style) ════════════════════════════════════════ -->

 <bookmark href="file://${HOME}/">
  <title>Home</title>
  <info><metadata owner="http://www.kde.org">
   <ID>canvera/home</ID>
   <IsHidden>false</IsHidden>
   <isDevice>false</isDevice>
   <icon>user-home</icon>
  </metadata></info>
 </bookmark>

 <bookmark href="file://${HOME}/Desktop/">
  <title>Desktop</title>
  <info><metadata owner="http://www.kde.org">
   <ID>canvera/desktop</ID>
   <IsHidden>false</IsHidden>
   <isDevice>false</isDevice>
   <icon>user-desktop</icon>
  </metadata></info>
 </bookmark>

 <bookmark href="file://${HOME}/Documents/">
  <title>Documents</title>
  <info><metadata owner="http://www.kde.org">
   <ID>canvera/documents</ID>
   <IsHidden>false</IsHidden>
   <isDevice>false</isDevice>
   <icon>folder-documents</icon>
  </metadata></info>
 </bookmark>

 <bookmark href="file://${HOME}/Downloads/">
  <title>Downloads</title>
  <info><metadata owner="http://www.kde.org">
   <ID>canvera/downloads</ID>
   <IsHidden>false</IsHidden>
   <isDevice>false</isDevice>
   <icon>folder-downloads</icon>
  </metadata></info>
 </bookmark>

 <bookmark href="file://${HOME}/Music/">
  <title>Music</title>
  <info><metadata owner="http://www.kde.org">
   <ID>canvera/music</ID>
   <IsHidden>false</IsHidden>
   <isDevice>false</isDevice>
   <icon>folder-music</icon>
  </metadata></info>
 </bookmark>

 <bookmark href="file://${HOME}/Pictures/">
  <title>Pictures</title>
  <info><metadata owner="http://www.kde.org">
   <ID>canvera/pictures</ID>
   <IsHidden>false</IsHidden>
   <isDevice>false</isDevice>
   <icon>folder-pictures</icon>
  </metadata></info>
 </bookmark>

 <bookmark href="file://${HOME}/Videos/">
  <title>Videos</title>
  <info><metadata owner="http://www.kde.org">
   <ID>canvera/videos</ID>
   <IsHidden>false</IsHidden>
   <isDevice>false</isDevice>
   <icon>folder-videos</icon>
  </metadata></info>
 </bookmark>

 <bookmark href="trash:/">
  <title>Trash</title>
  <info><metadata owner="http://www.kde.org">
   <ID>canvera/trash</ID>
   <IsHidden>false</IsHidden>
   <isDevice>false</isDevice>
   <icon>user-trash</icon>
  </metadata></info>
 </bookmark>

 <!-- ══ HIDDEN — System disks (macOS Finder hides these) ═══════════════════ -->
 <!-- These entries pre-mark common system paths as hidden.                    -->
 <!-- KDE will respect IsHidden=true and not show them in the sidebar.         -->

 <bookmark href="file:///">
  <title>System Disk</title>
  <info><metadata owner="http://www.kde.org">
   <ID>canvera/root</ID>
   <IsHidden>true</IsHidden>
   <isDevice>true</isDevice>
   <icon>drive-harddisk</icon>
  </metadata></info>
 </bookmark>

 <bookmark href="file:///boot/">
  <title>Boot</title>
  <info><metadata owner="http://www.kde.org">
   <ID>canvera/boot</ID>
   <IsHidden>true</IsHidden>
   <isDevice>true</isDevice>
   <icon>drive-harddisk</icon>
  </metadata></info>
 </bookmark>

 <bookmark href="file:///boot/efi/">
  <title>EFI</title>
  <info><metadata owner="http://www.kde.org">
   <ID>canvera/efi</ID>
   <IsHidden>true</IsHidden>
   <isDevice>true</isDevice>
   <icon>drive-harddisk</icon>
  </metadata></info>
 </bookmark>

</xbel>
XMLEOF

echo "Dolphin places configured (macOS Finder-style sidebar)."
