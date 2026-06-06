/* =============================================================================
 * CanveraOS — Calamares Installer Slideshow
 * Shown to user while files are being copied to disk.
 * Uses QML — the Qt UI language.
 * ============================================================================= */

import QtQuick 2.15
import QtQuick.Controls 2.15
import Calamares.Slideshow 1.0

Presentation {
    id: presentation

    // ─── Auto-advance slides every 5 seconds ──────────────────────────────────
    Timer {
        id: slideTimer
        interval: 5000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    // ─── Slide 1: Welcome ─────────────────────────────────────────────────────
    Slide {
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#0d0d1a" }
                GradientStop { position: 1.0; color: "#1a1a3e" }
            }

            Column {
                anchors.centerIn: parent
                spacing: 24

                Image {
                    source: "canvera-logo.png"
                    width: 96; height: 96
                    anchors.horizontalCenter: parent.horizontalCenter
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    text: "Welcome to CanveraOS"
                    font.family: "Inter"
                    font.pixelSize: 32
                    font.weight: Font.Bold
                    color: "#ffffff"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "A creative professional's OS. Built for those who make things."
                    font.family: "Inter"
                    font.pixelSize: 16
                    color: "#aaaacc"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    // ─── Slide 2: Adobe CC via CrossOver ──────────────────────────────────────
    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#f5f5f7"

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.7

                Text {
                    text: "🎨"
                    font.pixelSize: 64
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Adobe CC — Ready to Use"
                    font.family: "Inter"
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    color: "#1d1d1f"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Photoshop, Illustrator, Premiere Pro, After Effects and Lightroom — all pre-configured via CrossOver. Just log in with your Adobe account and start creating."
                    font.family: "Inter"
                    font.pixelSize: 15
                    color: "#3c3c43"
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                }
            }
        }
    }

    // ─── Slide 3: KDE Desktop ─────────────────────────────────────────────────
    Slide {
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#1a1a2e" }
                GradientStop { position: 1.0; color: "#16213e" }
            }

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.7

                Text {
                    text: "🖥️"
                    font.pixelSize: 64
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "macOS-Inspired Desktop"
                    font.family: "Inter"
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    color: "#ffffff"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Frosted glass top bar, animated dock, macOS-style window buttons, and instant Light/Dark mode switching. Familiar elegance, Linux power."
                    font.family: "Inter"
                    font.pixelSize: 15
                    color: "#aaaacc"
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                }
            }
        }
    }

    // ─── Slide 4: DaVinci Resolve ─────────────────────────────────────────────
    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#1a1a1a"

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.7

                Text {
                    text: "🎬"
                    font.pixelSize: 64
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Professional Video Editing"
                    font.family: "Inter"
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    color: "#ffffff"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "DaVinci Resolve runs natively on CanveraOS with full NVIDIA RTX GPU acceleration — CUDA, NVENC, and NVDEC all enabled out of the box."
                    font.family: "Inter"
                    font.pixelSize: 15
                    color: "#aaaaaa"
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                }
            }
        }
    }

    // ─── Slide 5: Codecs & Formats ────────────────────────────────────────────
    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#f5f5f7"

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.7

                Text {
                    text: "🎵"
                    font.pixelSize: 64
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Every Format, Out of the Box"
                    font.family: "Inter"
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    color: "#1d1d1f"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "H.264 · H.265 · AV1 · ProRes · DNxHD · AAC · FLAC · ALAC · HEIC · RAW · AVIF · MKV · MOV — all supported natively. No extra software to install, ever."
                    font.family: "Inter"
                    font.pixelSize: 15
                    color: "#3c3c43"
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                }
            }
        }
    }

    // ─── Slide 6: Almost done ─────────────────────────────────────────────────
    Slide {
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#0d1b4b" }
                GradientStop { position: 1.0; color: "#1a3a6e" }
            }

            Column {
                anchors.centerIn: parent
                spacing: 24

                Text {
                    text: "Almost there..."
                    font.family: "Inter"
                    font.pixelSize: 32
                    font.weight: Font.Bold
                    color: "#ffffff"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "CanveraOS is being installed to your drive.\nThis usually takes 5–15 minutes."
                    font.family: "Inter"
                    font.pixelSize: 16
                    color: "#aaccff"
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
