import QtQuick 1.1
import com.nokia.meego 1.0

Page {
    id: playerPage
    tools: null

    property bool showLyrics: false
    property int currentLyricIndex: -1
    property int currentPosition: appWindow.currentPosition
    property variant currentTrack: appWindow.currentTrack

    onCurrentPositionChanged: {
        if (!showLyrics || lyricsModel.count === 0) return;
        var pos = currentPosition;
        var activeIdx = -1;
        for (var i = 0; i < lyricsModel.count; i++) {
            if (pos >= lyricsModel.get(i).time) {
                activeIdx = i;
            } else {
                break;
            }
        }
        if (activeIdx !== currentLyricIndex && activeIdx >= 0) {
            currentLyricIndex = activeIdx;
            lyricsListView.positionViewAtIndex(activeIdx, ListView.Center);
        }
    }

    onCurrentTrackChanged: {
        lyricsModel.clear();
        currentLyricIndex = -1;
        if (showLyrics) {
            fetchLyrics();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    ListModel {
        id: lyricsModel
    }

    // Main Content Area (above bottom navbar)
    Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomNavbar.top
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 10
        anchors.bottomMargin: 6

        // 1. Cover Art / Lyrics Area (Top half, large square)
        Item {
            id: coverArea
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: parent.width

            Rectangle {
                id: coverContainer
                anchors.fill: parent
                visible: !showLyrics
                color: "#121212"
                radius: 6
                clip: true

                Image {
                    id: albumCover
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    source: appWindow.currentTrack
                            ? (appWindow.serverUrl + "/api/cover?url=" + encodeURIComponent(appWindow.currentTrack.cover_url || "") + "&artist=" + encodeURIComponent(appWindow.currentTrack.artist || "") + "&title=" + encodeURIComponent(appWindow.currentTrack.title || ""))
                            : ""
                }
            }

            Rectangle {
                id: lyricsContainer
                anchors.fill: parent
                visible: showLyrics
                color: "#0a0a0a"
                radius: 6
                clip: true

                BusyIndicator {
                    id: lyricsBusy
                    anchors.centerIn: parent
                    running: false
                    visible: running
                }

                Label {
                    id: noLyricsLabel
                    anchors.centerIn: parent
                    text: "Sözler bulunamadı."
                    color: "#888888"
                    font.pixelSize: 18
                    visible: lyricsModel.count === 0 && !lyricsBusy.running
                }

                ListView {
                    id: lyricsListView
                    anchors.fill: parent
                    anchors.margins: 12
                    clip: true
                    model: lyricsModel

                    delegate: Item {
                        width: lyricsListView.width
                        height: lyricTextLabel.height + 16

                        Label {
                            id: lyricTextLabel
                            anchors.centerIn: parent
                            width: parent.width - 10
                            text: model.text
                            font.pixelSize: index === currentLyricIndex ? 22 : 17
                            font.bold: index === currentLyricIndex
                            color: index === currentLyricIndex ? "#1db954" : "#666666"
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (model.time >= 0) appWindow.seekTo(model.time);
                            }
                        }
                    }
                }
            }
        }

        // 2. Track Info & Queue Count (Without the red circled button)
        Item {
            id: infoRow
            anchors.top: coverArea.bottom
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            height: 52

            Column {
                anchors.left: parent.left
                anchors.right: queueLabel.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Label {
                    text: appWindow.currentTrack ? appWindow.currentTrack.title : "Şarkı Seçilmedi"
                    font.pixelSize: 22
                    font.bold: true
                    color: "#ffffff"
                    elide: Text.ElideRight
                    width: parent.width
                }

                Label {
                    text: appWindow.currentTrack ? (appWindow.currentTrack.artist + (appWindow.currentTrack.album ? (" • " + appWindow.currentTrack.album) : "")) : ""
                    font.pixelSize: 15
                    color: "#a0a0a0"
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            Label {
                id: queueLabel
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: (appWindow.currentIndex >= 0 && playQueue.count > 0)
                      ? ((appWindow.currentIndex + 1) + "/" + playQueue.count)
                      : ""
                font.pixelSize: 18
                font.bold: true
                color: "#888888"
            }
        }

        // 3. Playback Controls Row (N9 Native Proportional Style)
        Row {
            id: controlsRow
            anchors.top: infoRow.bottom
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 65

            // Previous Button (|◀)
            Item {
                width: 60
                height: 60
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 30
                    color: prevMouse.pressed ? "#183822" : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: "\u25ae\u25c0" // |◀
                    font.pixelSize: 26
                    color: prevMouse.pressed ? "#1db954" : "#ffffff"
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    onClicked: appWindow.playPrevious()
                }
            }

            // Big Center Play / Pause Button (▶ / ||)
            Item {
                width: 74
                height: 74
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: playBtnBg
                    anchors.fill: parent
                    radius: 37
                    color: playMouse.pressed ? "#169343" : "#1db954"
                    scale: playMouse.pressed ? 0.93 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }
                }

                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: appWindow.isPlaying ? 0 : 2
                    text: appWindow.isPlaying ? "\u275a\u275a" : "\u25b6" // || or ▶
                    font.pixelSize: appWindow.isPlaying ? 24 : 30
                    font.bold: true
                    color: "#000000"
                }

                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    onClicked: appWindow.togglePlayPause()
                }
            }

            // Next Button (▶|)
            Item {
                width: 60
                height: 60
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 30
                    color: nextMouse.pressed ? "#183822" : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: "\u25b6\u25ae" // ▶|
                    font.pixelSize: 26
                    color: nextMouse.pressed ? "#1db954" : "#ffffff"
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    onClicked: appWindow.playNext()
                }
            }
        }

        // 4. Progress Slider and Time Labels (Below controls)
        Column {
            id: progressSection
            anchors.top: controlsRow.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            Slider {
                id: progressSlider
                width: parent.width
                minimumValue: 0
                maximumValue: appWindow.totalDuration > 0 ? appWindow.totalDuration : (appWindow.currentTrack ? appWindow.currentTrack.duration_ms : 100)
                value: appWindow.currentPosition
                stepSize: 1000

                property bool isUserSeeking: false

                onPressedChanged: {
                    if (pressed) {
                        isUserSeeking = true;
                    } else {
                        isUserSeeking = false;
                        appWindow.seekTo(value);
                    }
                }
            }

            Item {
                width: parent.width
                height: 20

                Label {
                    text: formatTime(appWindow.currentPosition)
                    font.pixelSize: 14
                    color: "#888888"
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                }

                Label {
                    text: formatTime(appWindow.totalDuration > 0 ? appWindow.totalDuration : (appWindow.currentTrack ? appWindow.currentTrack.duration_ms : 0))
                    font.pixelSize: 14
                    color: "#888888"
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                }
            }
        }
    }

    // 5. Enlarged Bottom Navbar in Spotify Dark Green (#0c2616)
    Rectangle {
        id: bottomNavbar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 72
        color: "#0c2616" // Spotify Deep Dark Green
        border.color: "#184524"
        border.width: 1

        Row {
            anchors.fill: parent

            // 1. Geri (N9 stili daire icinde ok)
            Item {
                width: parent.width / 5
                height: parent.height

                Rectangle {
                    anchors.centerIn: parent
                    width: 44
                    height: 44
                    radius: 22
                    color: backMouse.pressed ? "#164426" : "#13381f"
                    border.color: "#1d522c"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "\u2190" // ←
                        font.pixelSize: 22
                        font.bold: true
                        color: "#ffffff"
                    }
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    onClicked: pageStack.pop()
                }
            }

            // 2. Favori / Indir (N9 Yildiz Ikonu)
            Item {
                width: parent.width / 5
                height: parent.height

                Rectangle {
                    anchors.centerIn: parent
                    width: 44
                    height: 44
                    radius: 22
                    color: favMouse.pressed ? "#164426" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "\u2605" // ★
                        font.pixelSize: 26
                        color: favMouse.pressed ? "#1db954" : "#ffffff"
                    }
                }

                MouseArea {
                    id: favMouse
                    anchors.fill: parent
                    onClicked: appWindow.downloadCurrentTrack()
                }
            }

            // 3. Karisik Calma (N9 Cift Ok Ikonu)
            Item {
                width: parent.width / 5
                height: parent.height

                Rectangle {
                    anchors.centerIn: parent
                    width: 48
                    height: 40
                    radius: 20
                    color: appWindow.isShuffle ? "#1db954" : (shufMouse.pressed ? "#164426" : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: "\u21c4" // ⇄
                        font.pixelSize: 24
                        font.bold: true
                        color: appWindow.isShuffle ? "#0c2616" : "#b0d8be"
                    }
                }

                MouseArea {
                    id: shufMouse
                    anchors.fill: parent
                    onClicked: {
                        appWindow.isShuffle = !appWindow.isShuffle;
                        appWindow.showNotification("Karışık: " + (appWindow.isShuffle ? "Açık" : "Kapalı"));
                    }
                }
            }

            // 4. Tekrar Calma (N9 Dongu Ikonu)
            Item {
                width: parent.width / 5
                height: parent.height

                Rectangle {
                    anchors.centerIn: parent
                    width: 48
                    height: 40
                    radius: 20
                    color: appWindow.repeatMode !== 0 ? "#1db954" : (repMouse.pressed ? "#164426" : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: appWindow.repeatMode === 2 ? "\u21ba1" : "\u21ba" // ↺
                        font.pixelSize: 22
                        font.bold: true
                        color: appWindow.repeatMode !== 0 ? "#0c2616" : "#b0d8be"
                    }
                }

                MouseArea {
                    id: repMouse
                    anchors.fill: parent
                    onClicked: {
                        appWindow.repeatMode = (appWindow.repeatMode + 1) % 3;
                        var modeName = appWindow.repeatMode === 0 ? "Kapalı" : (appWindow.repeatMode === 1 ? "Tüm Liste" : "Tek Parça");
                        appWindow.showNotification("Tekrar: " + modeName);
                    }
                }
            }

            // 5. Sozler / Menu (N9 3 Cizgi Ikonu)
            Item {
                width: parent.width / 5
                height: parent.height

                Rectangle {
                    anchors.centerIn: parent
                    width: 48
                    height: 40
                    radius: 20
                    color: showLyrics ? "#1db954" : (menuMouse.pressed ? "#164426" : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: "\u2261" // ≡
                        font.pixelSize: 26
                        font.bold: true
                        color: showLyrics ? "#0c2616" : "#ffffff"
                    }
                }

                MouseArea {
                    id: menuMouse
                    anchors.fill: parent
                    onClicked: {
                        showLyrics = !showLyrics;
                        if (showLyrics && lyricsModel.count === 0) fetchLyrics();
                    }
                }
            }
        }
    }

    function fetchLyrics() {
        if (!appWindow.currentTrack) return;
        lyricsBusy.running = true;
        lyricsModel.clear();
        noLyricsLabel.visible = false;

        var t = appWindow.currentTrack;
        var durSec = Math.floor((t.duration_ms || 0) / 1000);
        var url = appWindow.serverUrl + "/api/lyrics?artist=" + encodeURIComponent(t.artist)
                  + "&title=" + encodeURIComponent(t.title)
                  + "&album=" + encodeURIComponent(t.album || "")
                  + "&duration=" + durSec;

        var xhr = new XMLHttpRequest();
        xhr.open("GET", url, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                lyricsBusy.running = false;
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText);
                        if (res.synced && res.synced.length > 0) {
                            for (var i = 0; i < res.synced.length; i++) {
                                lyricsModel.append(res.synced[i]);
                            }
                        } else if (res.plain && res.plain.length > 0) {
                            var lines = res.plain.split("\n");
                            for (var j = 0; j < lines.length; j++) {
                                lyricsModel.append({ time: -1, text: lines[j] });
                            }
                        } else {
                            noLyricsLabel.visible = true;
                        }
                    } catch(e) {
                        noLyricsLabel.visible = true;
                    }
                } else {
                    noLyricsLabel.visible = true;
                }
            }
        };
        xhr.send();
    }

    function formatTime(ms) {
        if (!ms || ms < 0) return "0:00";
        var totalSec = Math.floor(ms / 1000);
        var min = Math.floor(totalSec / 60);
        var sec = totalSec % 60;
        return min + ":" + (sec < 10 ? "0" : "") + sec;
    }
}
