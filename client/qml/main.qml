import QtQuick 1.1
import com.nokia.meego 1.0
import QtMultimediaKit 1.1

PageStackWindow {
    id: appWindow
    initialPage: searchPage

    // AMOLED Theme Palette
    property color amoledBlack: "#000000"
    property color amoledCard: "#121212"
    property color spotifyGreen: "#1db954"
    property color textPrimary: "#ffffff"
    property color textSecondary: "#a0a0a0"

    // Bridge Server Connection
    property string serverUrl: "http://192.168.8.137:8080"
    property variant currentTrack: null
    property bool isPlaying: false
    property int currentPosition: audioPlayer.position
    property int totalDuration: audioPlayer.duration

    onIsPlayingChanged: {
        if (typeof meegoBridge !== "undefined") {
            meegoBridge.updatePlaybackStatus(isPlaying);
        }
    }

    // Playback Queue & Modes
    property int currentIndex: -1
    property bool isShuffle: false
    property int repeatMode: 0 // 0: None, 1: Repeat All, 2: Repeat One

    ListModel {
        id: playQueue
    }

    // Global Audio Engine (QtMultimediaKit 1.1)
    Audio {
        id: audioPlayer

        onStatusChanged: {
            if (status === Audio.EndOfMedia) {
                handleTrackFinished();
            }
        }

        onError: {
            console.log("Audio error: " + error + " - " + errorString);
        }
    }

    // Initialize D-Bus hooks on startup
    Component.onCompleted: {
        if (typeof meegoBridge !== "undefined") {
            meegoBridge.mprisPlayPauseRequested.connect(togglePlayPause);
            meegoBridge.mprisNextRequested.connect(playNext);
            meegoBridge.mprisPreviousRequested.connect(playPrevious);
            meegoBridge.serverDiscovered.connect(function(foundUrl) {
                appWindow.serverUrl = foundUrl;
                showNotification("Sunucu bulundu: " + foundUrl);
            });
            meegoBridge.downloadCompleted.connect(function(id, path) {
                showNotification("İndirme tamamlandı! Müzik kütüphanesine kaydedildi.");
            });
            meegoBridge.downloadFailed.connect(function(id, err) {
                showNotification("İndirme hatası: " + err);
            });
        }
    }

    function setQueue(tracks, startIndex) {
        playQueue.clear();
        for (var i = 0; i < tracks.length; i++) {
            playQueue.append(tracks[i]);
        }
        currentIndex = startIndex;
        if (playQueue.count > 0 && startIndex >= 0 && startIndex < playQueue.count) {
            playTrack(playQueue.get(startIndex));
        }
    }

    function playTrack(track) {
        currentTrack = track;
        var streamUrl = serverUrl + "/api/stream?artist=" + encodeURIComponent(track.artist) + "&title=" + encodeURIComponent(track.title);
        
        audioPlayer.stop();
        audioPlayer.source = streamUrl;
        audioPlayer.play();
        isPlaying = true;

        // Record to Recently Played History
        if (typeof meegoBridge !== "undefined" && track) {
            try {
                meegoBridge.addRecentTrack(JSON.stringify(track));
            } catch(e) {}
        }

        // Update MeeGo Lockscreen / Glance Screen
        if (typeof meegoBridge !== "undefined") {
            var coverUrl = (track.cover_url || track.artist || track.title) ? (serverUrl + "/api/cover?url=" + encodeURIComponent(track.cover_url || "") + "&artist=" + encodeURIComponent(track.artist || "") + "&title=" + encodeURIComponent(track.title || "")) : "";
            meegoBridge.updateNowPlaying(track.title, track.artist, track.album, coverUrl, track.duration_ms);
            meegoBridge.updatePlaybackStatus(true);
        }

        // Gapless Pre-buffer next track in queue
        prefetchNextTrack();
    }

    function prefetchNextTrack() {
        if (playQueue.count <= 1 || currentIndex < 0) return;
        var nextIdx = (currentIndex + 1) % playQueue.count;
        var nextTrack = playQueue.get(nextIdx);
        if (nextTrack) {
            var xhr = new XMLHttpRequest();
            var prefetchUrl = serverUrl + "/api/prefetch?artist=" + encodeURIComponent(nextTrack.artist) + "&title=" + encodeURIComponent(nextTrack.title);
            xhr.open("GET", prefetchUrl, true);
            xhr.send();
        }
    }

    function handleTrackFinished() {
        if (audioPlayer.duration > 5000 && audioPlayer.position < audioPlayer.duration - 3000) {
            return;
        }
        isPlaying = false;
        if (repeatMode === 2 && currentTrack) {
            audioPlayer.position = 0;
            audioPlayer.play();
            isPlaying = true;
        } else {
            playNext();
        }
    }

    function playNext() {
        if (playQueue.count === 0) return;
        if (isShuffle) {
            currentIndex = Math.floor(Math.random() * playQueue.count);
        } else {
            if (currentIndex + 1 < playQueue.count) {
                currentIndex++;
            } else if (repeatMode === 1) {
                currentIndex = 0;
            } else {
                audioPlayer.stop();
                return;
            }
        }
        playTrack(playQueue.get(currentIndex));
    }

    function playPrevious() {
        if (audioPlayer.position > 3000) {
            audioPlayer.position = 0;
            return;
        }
        if (playQueue.count === 0) return;
        if (currentIndex > 0) {
            currentIndex--;
        } else {
            currentIndex = playQueue.count - 1;
        }
        playTrack(playQueue.get(currentIndex));
    }

    function togglePlayPause() { if (isPlaying) { audioPlayer.pause(); isPlaying = false; } else { audioPlayer.play(); isPlaying = true; } }
    function seekTo(ms) {
        audioPlayer.position = ms;
    }

    function downloadCurrentTrack() {
        if (!currentTrack || typeof meegoBridge === "undefined") return;
        var streamUrl = serverUrl + "/api/stream?artist=" + encodeURIComponent(currentTrack.artist) + "&title=" + encodeURIComponent(currentTrack.title);
        showNotification("İndiriliyor: " + currentTrack.title);
        meegoBridge.downloadTrack(currentTrack.id, streamUrl, currentTrack.artist, currentTrack.title);
    }

    // Pages
    SearchPage {
        id: searchPage
    }

    PlayerPage {
        id: playerPage
    }

    LibraryPage {
        id: libraryPage
    }

    // Toast Notification Banner
    Rectangle {
        id: toastBanner
        z: 999
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 70
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 40, toastText.width + 40)
        height: 48
        radius: 24
        color: "#282828"
        border.color: spotifyGreen
        border.width: 1
        opacity: 0.0

        Label {
            id: toastText
            anchors.centerIn: parent
            text: ""
            color: "white"
            font.pixelSize: 18
        }

        NumberAnimation {
            id: toastAnim
            target: toastBanner
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 250
            onCompleted: toastTimer.start()
        }

        Timer {
            id: toastTimer
            interval: 3000
            onTriggered: {
                toastBanner.opacity = 0.0;
            }
        }
    }

    function showNotification(msg) {
        toastText.text = msg;
        toastAnim.start();
    }

    // Server IP Config & Auto-Discovery Dialog
    Dialog {
        id: settingsDialog
        title: Item {
            height: 40
            width: parent.width
            Label {
                text: "Sunucu ve Bağlantı Ayarları"
                font.bold: true
                anchors.centerIn: parent
                color: "white"
            }
        }
        content: Column {
            spacing: 14
            width: parent.width

            Label {
                text: "Köprü Sunucu IP & Port:"
                font.pixelSize: 18
                color: textSecondary
            }
            TextField {
                id: serverUrlInput
                text: appWindow.serverUrl
                width: parent.width
                inputMethodHints: Qt.ImhUrlCharactersOnly
            }
            Button {
                text: "Ağda Sunucuyu Otomatik Bul"
                width: parent.width
                onClicked: {
                    if (typeof meegoBridge !== "undefined") {
                        showNotification("Ağ taranıyor (UDP Broadcast)...");
                        meegoBridge.discoverServer();
                    }
                }
            }
        }
        buttons: Row {
            spacing: 12
            anchors.horizontalCenter: parent.horizontalCenter
            Button {
                width: 175
                text: "Kaydet"
                onClicked: {
                    appWindow.serverUrl = serverUrlInput.text;
                    settingsDialog.accept();
                    showNotification("Sunucu adresi güncellendi.");
                }
            }
            Button {
                width: 175
                text: "İptal"
                onClicked: settingsDialog.reject()
            }
        }
    }

    function openSettings() {
        serverUrlInput.text = appWindow.serverUrl;
        settingsDialog.open();
    }
}
