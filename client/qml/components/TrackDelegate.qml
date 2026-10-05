import QtQuick 1.1
import com.nokia.meego 1.0

Item {
    id: root
    width: parent.width
    height: 80

    signal clicked()

    Rectangle {
        id: bg
        anchors.fill: parent
        color: mouseArea.pressed ? "#1c1c1c" : "transparent"
    }

    Row {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 12

        // Album thumbnail (proxied via bridge HTTP)
        Rectangle {
            width: 64
            height: 64
            color: "#121212"
            radius: 6

            Image {
                id: coverThumb
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                smooth: true
                source: (model.cover_url || model.artist || model.title) ? (appWindow.serverUrl + "/api/cover?url=" + encodeURIComponent(model.cover_url || "") + "&artist=" + encodeURIComponent(model.artist || "") + "&title=" + encodeURIComponent(model.title || "")) : ""
            }
        }

        // Title and Artist
        Column {
            width: root.width - 64 - 36 - 60
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Label {
                text: model.title
                font.pixelSize: 22
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
                color: appWindow.textPrimary
            }

            Label {
                text: model.artist + " • " + model.album
                font.pixelSize: 17
                color: appWindow.textSecondary
                elide: Text.ElideRight
                width: parent.width
            }
        }

        // Duration (mm:ss)
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: formatDuration(model.duration_ms)
            font.pixelSize: 15
            color: "#666666"
        }
    }

    // Separator line
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: 84
        anchors.right: parent.right
        height: 1
        color: "#1a1a1a"
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        onClicked: root.clicked()
    }

    function formatDuration(ms) {
        if (!ms) return "0:00";
        var totalSec = Math.floor(ms / 1000);
        var min = Math.floor(totalSec / 60);
        var sec = totalSec % 60;
        return min + ":" + (sec < 10 ? "0" : "") + sec;
    }
}
