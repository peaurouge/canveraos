{\rtf1\ansi\ansicpg1252\cocoartf2870
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\paperw11900\paperh16840\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 #!/usr/bin/env bash\
# =============================================================================\
# CanveraOS - Advanced File System Support (APFS, NTFS, ExFAT, HFS+)\
# Run this inside the chroot environment (called from chroot-setup.sh)\
# =============================================================================\
\
echo "[BUILD] Installing native file system support (NTFS, ExFAT, FAT32, HFS+)..."\
apt-get update\
apt-get install -y ntfs-3g exfat-fuse exfatprogs dosfstools mtools hfsprogs\
\
echo "[BUILD] Preparing environment for APFS kernel module compilation..."\
apt-get install -y dkms git build-essential linux-headers-generic\
\
# 1. Install linux-apfs-rw (Kernel module for native read/write)\
echo "[BUILD] Building linux-apfs-rw module via DKMS..."\
git clone https://github.com/linux-apfs/linux-apfs-rw.git /usr/src/apfs-1.0\
dkms add -m apfs -v 1.0\
dkms build -m apfs -v 1.0\
dkms install -m apfs -v 1.0\
\
# 2. Install apfs-fuse (Fallback user-space mounting tool for encrypted/special APFS volumes)\
echo "[BUILD] Building apfs-fuse fallback tool..."\
apt-get install -y fuse3 libfuse3-dev bzip2 libbz2-dev cmake\
git clone https://github.com/sgan81/apfs-fuse.git /tmp/apfs-fuse\
cd /tmp/apfs-fuse\
git submodule init\
git submodule update\
mkdir build && cd build\
cmake ..\
make -j$(nproc)\
make install\
cd /\
rm -rf /tmp/apfs-fuse\
\
echo "[BUILD] APFS and advanced file system support successfully installed."}