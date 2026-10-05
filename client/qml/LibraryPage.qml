import QtQuick 1.1
import com.nokia.meego 1.0

Page {
    id: libraryPage

    tools: ToolBarLayout {
        ToolIcon {
            iconId: "toolbar-back"
            onClicked: pageStack.pop()
        }
        ToolIcon {
            iconId: "toolbar-view-menu"
            visible: appWindow.currentTrack !== null
            onClicked: pageStack.push(playerPage)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: appWindow.amoledBlack
    }

    Column {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 12

        // MeeGoify Logo + Favoriler Title
        Row {
            spacing: 12
            anchors.left: parent.left

            Image {
                width: 36
                height: 36
                source: "meegoify_logo.png"
                smooth: true
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
            }

            Label {
                text: "Favoriler"
                font.pixelSize: 32
                font.bold: true
                color: appWindow.spotifyGreen
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        ButtonRow {
            id: tabRow
            width: parent.width
            Button {
                id: favTabBtn
                text: "Favorilerim"
                onClicked: loadFavorites()
            }
            Button {
                id: recTabBtn
                text: "Önerilenler"
                onClicked: loadRecommended()
            }
        }
    }

    BusyIndicator {
        id: libBusy
        anchors.centerIn: parent
        running: false
        visible: running
        platformStyle: BusyIndicatorStyle { size: "large" }
    }

    Column {
        id: statusContainer
        anchors.centerIn: parent
        width: parent.width - 40
        spacing: 12
        visible: libModel.count === 0 && !libBusy.running

        Label {
            id: statusLabel
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Liste yükleniyor..."
            color: appWindow.textSecondary
            font.pixelSize: 18
        }

        Button {
            id: retryBtn
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Tekrar Dene"
            width: 160
            onClicked: loadFavorites()
        }
    }

    ListModel {
        id: libModel
    }

    ListView {
        id: libList
        anchors.top: header.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        model: libModel

        delegate: Item {
            width: parent.width
            height: 80

            Rectangle {
                anchors.fill: parent
                color: mouseArea.pressed ? "#1c1c1c" : "transparent"
            }

            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 12

                // Cover Art Thumbnail with Placeholder and Fallback Resolver
                Rectangle {
                    width: 64
                    height: 64
                    color: "#181818"
                    radius: 6
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        text: "♫"
                        font.pixelSize: 26
                        color: "#383838"
                    }

                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        source: (model.cover_url || model.artist || model.title)
                                ? (appWindow.serverUrl + "/api/cover?url=" + encodeURIComponent(model.cover_url || "") + "&artist=" + encodeURIComponent(model.artist || "") + "&title=" + encodeURIComponent(model.title || ""))
                                : ""
                    }
                }

                Column {
                    width: parent.width - 80
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Label {
                        text: model.title
                        font.pixelSize: 22
                        font.bold: true
                        elide: Text.ElideRight
                        width: parent.width
                        color: "white"
                    }

                    Label {
                        text: model.artist + (model.album ? (" • " + model.album) : "")
                        font.pixelSize: 17
                        color: "#a0a0a0"
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                onClicked: {
                    var tracks = [];
                    for (var i = 0; i < libModel.count; i++) {
                        tracks.push(libModel.get(i));
                    }
                    appWindow.setQueue(tracks, index);
                    pageStack.push(playerPage);
                }
            }
        }
    }

    Connections {
        target: (typeof meegoBridge !== "undefined") ? meegoBridge : null
        onSearchResultsReady: {
            if (!libBusy.running) return;
            libBusy.running = false;
            try {
                var raw = meegoBridge.getLastSearchResults();
                var list = JSON.parse(raw);
                libModel.clear();
                for (var i = 0; i < list.length; i++) {
                    libModel.append(list[i]);
                }
                if (list.length === 0) {
                    statusLabel.text = "Parça bulunamadı.";
                }
            } catch(e) {
                statusLabel.text = "Ayrıştırma hatası: " + e;
            }
        }
        onSearchFailed: {
            if (!libBusy.running) return;
            libBusy.running = false;
            statusLabel.text = "Bağlantı hatası: Sunucuya ulaşılamadı.\n(" + meegoBridge.getLastSearchError() + ")";
        }
    }

    Component.onCompleted: {
        loadFavorites();
    }

    function loadRecommended() {
        libBusy.running = true;
        libModel.clear();
        statusLabel.text = "Önerilen parçalar yükleniyor...";
        if (typeof meegoBridge !== "undefined") {
            meegoBridge.searchTracks(appWindow.serverUrl, "türkçe pop");
        }
    }

    function loadFavorites() {
        libBusy.running = true;
        libModel.clear();
        statusLabel.text = "Favoriler yükleniyor...";
        if (typeof meegoBridge !== "undefined") {
            meegoBridge.fetchPlaylistTracks(appWindow.serverUrl, "1cGFHKDjXMzaHWYGMMIzwx");
        }
    }
}
