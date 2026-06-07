{\rtf1\ansi\ansicpg1252\cocoartf2870
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\paperw11900\paperh16840\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 #!/usr/bin/env bash\
# =============================================================================\
# CanveraOS - Quick Look (Spacebar Preview) Engine\
# Mimics macOS Quick Look functionality for KDE Plasma\
# =============================================================================\
\
# E\uc0\u287 er script arg\'fcmans\u305 z \'e7al\u305 \u351 t\u305 r\u305 l\u305 rsa, arka planda a\'e7\u305 k olan Quick Look penceresini kapat\u305 r (Toggle mant\u305 \u287 \u305 )\
if [[ -z "$1" ]]; then\
    PID=$(cat /tmp/canvera-quicklook.pid 2>/dev/null)\
    if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then\
        kill "$PID" 2>/dev/null\
        rm -f /tmp/canvera-quicklook.pid\
        exit 0\
    fi\
    exit 0\
fi\
\
FILE="$1"\
\
# E\uc0\u287 er zaten a\'e7\u305 k bir Quick Look varsa kapat\
PID=$(cat /tmp/canvera-quicklook.pid 2>/dev/null)\
if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then\
    kill "$PID" 2>/dev/null\
    rm -f /tmp/canvera-quicklook.pid\
fi\
\
# Dosya t\'fcr\'fcn\'fc tespit et\
MIMETYPE=$(file -b --mime-type "$FILE")\
\
# T\'fcr\'fcne g\'f6re en h\uc0\u305 zl\u305  g\'f6r\'fcnt\'fcleyiciyi ba\u351 lat\
case "$MIMETYPE" in\
    image/*)\
        # Foto\uc0\u287 raflar\u305  Gwenview ile tam ekran/slayt modunda a\'e7\
        gwenview -f "$FILE" &\
        echo $! > /tmp/canvera-quicklook.pid\
        ;;\
    video/*|audio/*)\
        # Medyalar\uc0\u305  VLC ile \'e7er\'e7evesiz/minimal modda a\'e7\
        vlc --fullscreen --play-and-exit "$FILE" &\
        echo $! > /tmp/canvera-quicklook.pid\
        ;;\
    application/pdf)\
        # PDF'leri Okular ile sunum modunda a\'e7\
        okular --presentation "$FILE" &\
        echo $! > /tmp/canvera-quicklook.pid\
        ;;\
    text/*)\
        # Metin dosyalar\uc0\u305 n\u305  Kate ile a\'e7\
        kate "$FILE" &\
        echo $! > /tmp/canvera-quicklook.pid\
        ;;\
    *)\
        # Bilinmeyen t\'fcrleri varsay\uc0\u305 lan uygulama ile a\'e7\
        xdg-open "$FILE" &\
        echo $! > /tmp/canvera-quicklook.pid\
        ;;\
esac}