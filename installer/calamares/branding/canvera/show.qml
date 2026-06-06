// CanveraOS Calamares Slideshow
// Shown during installation (exec phase)
// Minimal QML — just shows the logo centered on a dark background

import QtQuick 2.15
import QtQuick.Controls 2.15
import io.calamares.ui 1.0

Presentation {
    id: presentation

    Rectangle {
        anchors.fill: parent
        color: "#1C1C1E"

        Column {
            anchors.centerIn: parent
            spacing: 32

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: "canvera-logo.png"
                fillMode: Image.PreserveAspectFit
                width: 200
                height: 200
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Installing CanveraOS..."
                color: "#F5F5F7"
                font.pixelSize: 22
                font.family: "Inter, SF Pro Display, Helvetica Neue, sans-serif"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Your creative workspace is being set up."
                color: "#8E8E93"
                font.pixelSize: 14
                font.family: "Inter, SF Pro Text, Helvetica Neue, sans-serif"
            }
        }
    }
}
