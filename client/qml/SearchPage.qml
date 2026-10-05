import QtQuick 1.1
import com.nokia.meego 1.0

Page {
    id: searchPage

    property bool isSearchMode: false
    property string currentSearchQuery: ""

    tools: ToolBarLayout {
        ToolIcon {
            iconId: "toolbar-settings"
            onClicked: appWindow.openSettings()
        }
        ToolIcon {
            iconId: "toolbar-directory"
            onClicked: pageStack.push(libraryPage)
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

    // Top Header & Search Bar
    Column {
        id: headerArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 12

        // Logo & Title
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
                text: "MeeGoify"
                font.pixelSize: 32
                font.bold: true
                color: appWindow.spotifyGreen
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Search Input & Action Button
        Row {
            width: parent.width
            spacing: 8

            TextField {
                id: searchInput
                placeholderText: "Şarkı veya sanatçı ara..."
                width: parent.width - 108
                inputMethodHints: Qt.ImhNoAutoUppercase
                onAccepted: performSearch()
                onTextChanged: {
                    if (searchInput.text === "" && !busyIndicator.running && trackModel.count === 0) {
                        isSearchMode = false;
                        loadRecent();
                    }
                }
            }

            Button {
                id: searchBtn
                text: "Ara"
                width: 100
                onClicked: performSearch()
            }
        }
    }

    // ==========================================
    // 1. HOME DASHBOARD (Pre-Search View)
    // ==========================================
    Flickable {
        id: homeDashboard
        anchors.top: headerArea.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        visible: !isSearchMode
        contentWidth: width
        contentHeight: dashboardColumn.height + 32

        Column {
            id: dashboardColumn
            width: parent.width - 32
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20

            // --- CATEGORIES / GENRE PILLS ---
            Column {
                width: parent.width
                spacing: 10

                Label {
                    text: "Kategoriler"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#a0a0a0"
                }

                Flickable {
                    width: parent.width
                    height: 40
                    contentWidth: categoriesRow.width
                    contentHeight: 40
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: categoriesRow
                        spacing: 8

                        Repeater {
                            model: categoriesModel
                            Rectangle {
                                height: 38
                                width: pillRow.width + 24
                                radius: 19
                                color: pillMA.pressed ? "#2e2e2e" : "#1a1a1a"
                                border.color: pillMA.pressed ? appWindow.spotifyGreen : "#333333"
                                border.width: 1

                                Row {
                                    id: pillRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Image {
                                        width: 20
                                        height: 20
                                        source: model.iconSource ? Qt.resolvedUrl(model.iconSource) : ""
                                        smooth: true
                                        fillMode: Image.PreserveAspectFit
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        id: pillText
                                        text: model.name
                                        color: "white"
                                        font.pixelSize: 15
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: pillMA
                                    anchors.fill: parent
                                    onClicked: {
                                        performSearch(model.query);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // --- SON ARAMALAR (RECENT SEARCHES) ---
            Column {
                width: parent.width
                spacing: 10
                visible: recentSearchesModel.count > 0

                Row {
                    width: parent.width

                    Label {
                        text: "Son Aramalar"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#a0a0a0"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        width: parent.width - 200
                        height: 1
                    }

                    Text {
                        text: "Temizle"
                        font.pixelSize: 15
                        font.bold: true
                        color: appWindow.spotifyGreen
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            onClicked: {
                                if (typeof meegoBridge !== "undefined") {
                                    meegoBridge.clearRecentSearches();
                                }
                                loadRecent();
                            }
                        }
                    }
                }

                Flow {
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: recentSearchesModel
                        Rectangle {
                            height: 34
                            width: chipContent.width + 18
                            radius: 17
                            color: "#181818"
                            border.color: "#2a2a2a"

                            Row {
                                id: chipContent
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: model.query
                                    color: "#e0e0e0"
                                    font.pixelSize: 15
                                    anchors.verticalCenter: parent.verticalCenter

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        onClicked: {
                                            performSearch(model.query);
                                        }
                                    }
                                }

                                Text {
                                    text: "×"
                                    color: "#888888"
                                    font.pixelSize: 18
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        onClicked: {
                                            if (typeof meegoBridge !== "undefined") {
                                                meegoBridge.removeRecentSearch(model.query);
                                            }
                                            loadRecent();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // --- SON DİNLENENLER (RECENTLY PLAYED) ---
            Column {
                width: parent.width
                spacing: 10
                visible: recentTracksModel.count > 0

                Row {
                    width: parent.width

                    Label {
                        text: "Son Dinlenenler"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#a0a0a0"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        width: parent.width - 220
                        height: 1
                    }

                    Text {
                        text: "Temizle"
                        font.pixelSize: 15
                        font.bold: true
                        color: appWindow.spotifyGreen
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            onClicked: {
                                if (typeof meegoBridge !== "undefined") {
                                    meegoBridge.clearRecentTracks();
                                }
                                loadRecent();
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: recentTracksModel
                        Item {
                            width: parent.width
                            height: 64

                            Rectangle {
                                anchors.fill: parent
                                color: recentTrackMA.pressed ? "#1c1c1c" : "transparent"
                                radius: 6
                            }

                            Row {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 12

                                Rectangle {
                                    width: 54
                                    height: 54
                                    color: "#181818"
                                    radius: 6
                                    clip: true
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: "♫"
                                        font.pixelSize: 22
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
                                    width: parent.width - 70
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3

                                    Label {
                                        text: model.title
                                        font.pixelSize: 19
                                        font.bold: true
                                        elide: Text.ElideRight
                                        width: parent.width
                                        color: "white"
                                    }

                                    Label {
                                        text: model.artist + (model.album ? (" • " + model.album) : "")
                                        font.pixelSize: 14
                                        color: "#a0a0a0"
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }
                            }

                            MouseArea {
                                id: recentTrackMA
                                anchors.fill: parent
                                onClicked: {
                                    var tracks = [];
                                    for (var k = 0; k < recentTracksModel.count; k++) {
                                        tracks.push(recentTracksModel.get(k));
                                    }
                                    appWindow.setQueue(tracks, index);
                                    pageStack.push(playerPage);
                                }
                            }
                        }
                    }
                }
            }

            // --- WELCOME CARD (WHEN NO RECENT ACTIVITY) ---
            Rectangle {
                width: parent.width
                height: 130
                color: "#121212"
                radius: 10
                border.color: "#222222"
                visible: recentSearchesModel.count === 0 && recentTracksModel.count === 0

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    width: parent.width - 32

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "♫ Hoş Geldiniz"
                        font.pixelSize: 22
                        font.bold: true
                        color: appWindow.spotifyGreen
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        width: parent.width
                        text: "Müzik dinlemek için arama yapabilir veya yukarıdaki popüler kategorilere dokunabilirsiniz."
                        font.pixelSize: 15
                        color: "#888888"
                    }
                }
            }
        }
    }

    // ==========================================
    // 2. SEARCH RESULTS VIEW
    // ==========================================
    Item {
        id: searchContainer
        anchors.top: headerArea.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: isSearchMode

        // Results header with back/clear button
        Item {
            id: resultsHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 36

            Label {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Sonuçlar: " + currentSearchQuery
                font.pixelSize: 16
                color: "#a0a0a0"
                elide: Text.ElideRight
                width: parent.width - 120
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "✕ Ana Sayfa"
                font.pixelSize: 15
                font.bold: true
                color: appWindow.spotifyGreen

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    onClicked: clearSearch()
                }
            }
        }

        BusyIndicator {
            id: busyIndicator
            anchors.centerIn: parent
            running: false
            visible: running
            platformStyle: BusyIndicatorStyle { size: "large" }
        }

        Label {
            id: emptyLabel
            anchors.centerIn: parent
            width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Sonuç bulunamadı."
            color: appWindow.textSecondary
            font.pixelSize: 18
            visible: trackModel.count === 0 && !busyIndicator.running && isSearchMode
        }

        ListView {
            id: trackListView
            anchors.top: resultsHeader.bottom
            anchors.topMargin: 4
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            model: trackModel

            delegate: Item {
                width: parent.width
                height: 80

                Rectangle {
                    anchors.fill: parent
                    color: searchItemMA.pressed ? "#1c1c1c" : "transparent"
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 12

                    // Cover Art Thumbnail with Fallback Resolver
                    Rectangle {
                        width: 64
                        height: 64
                        color: "#181818"
                        radius: 6
                        clip: true
                        anchors.verticalCenter: parent.verticalCenter

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
                            font.pixelSize: 21
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                            color: "white"
                        }

                        Label {
                            text: model.artist + (model.album ? (" • " + model.album) : "")
                            font.pixelSize: 16
                            color: "#a0a0a0"
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                }

                MouseArea {
                    id: searchItemMA
                    anchors.fill: parent
                    onClicked: {
                        var tracks = [];
                        for (var i = 0; i < trackModel.count; i++) {
                            tracks.push(trackModel.get(i));
                        }
                        appWindow.setQueue(tracks, index);
                        pageStack.push(playerPage);
                    }
                }
            }
        }
    }

    // ==========================================
    // DATA MODELS
    // ==========================================
    ListModel { id: trackModel }
    ListModel { id: recentSearchesModel }
    ListModel { id: recentTracksModel }
    ListModel {
        id: categoriesModel
        ListElement { name: "Pop"; iconSource: "genre_pop.png"; query: "Türkçe Pop" }
        ListElement { name: "Rock"; iconSource: "genre_rock.png"; query: "Türkçe Rock" }
        ListElement { name: "Rap"; iconSource: "genre_rap.png"; query: "Türkçe Rap" }
        ListElement { name: "90'lar"; iconSource: "genre_90s.png"; query: "90lar Türkçe Pop" }
        ListElement { name: "Akustik"; iconSource: "genre_acoustic.png"; query: "Akustik Şarkılar" }
        ListElement { name: "Hits"; iconSource: "genre_hits.png"; query: "Top Hits" }
        ListElement { name: "Elektronik"; iconSource: "genre_electronic.png"; query: "Electronic Dance" }
        ListElement { name: "Chill"; iconSource: "genre_chill.png"; query: "Chillout Lounge" }
    }

    // ==========================================
    // CONNECTIONS & FUNCTIONS
    // ==========================================
    Connections {
        target: (typeof meegoBridge !== "undefined") ? meegoBridge : null
        onSearchResultsReady: {
            busyIndicator.running = false;
            try {
                var raw = meegoBridge.getLastSearchResults();
                var list = JSON.parse(raw);
                for (var i = 0; i < list.length; i++) {
                    trackModel.append(list[i]);
                }
                if (list.length === 0) {
                    emptyLabel.text = "Sonuç bulunamadı.";
                    emptyLabel.visible = true;
                }
            } catch(e) {
                emptyLabel.text = "Hata: " + e;
                emptyLabel.visible = true;
            }
        }
        onSearchFailed: {
            busyIndicator.running = false;
            if (searchInput.text.length > 0) {
                emptyLabel.text = "Bağlantı hatası: " + meegoBridge.getLastSearchError();
                emptyLabel.visible = true;
            }
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Active) {
            loadRecent();
        }
    }

    Component.onCompleted: {
        loadRecent();
    }

    function loadRecent() {
        if (typeof meegoBridge === "undefined") return;

        // Load recent search queries
        try {
            var rawSearches = meegoBridge.getRecentSearches();
            var searches = JSON.parse(rawSearches);
            recentSearchesModel.clear();
            for (var i = 0; i < searches.length; i++) {
                recentSearchesModel.append({ "query": searches[i] });
            }
        } catch(e) {}

        // Load recently played tracks
        try {
            var rawTracks = meegoBridge.getRecentTracks();
            var tracks = JSON.parse(rawTracks);
            recentTracksModel.clear();
            for (var j = 0; j < tracks.length; j++) {
                recentTracksModel.append(tracks[j]);
            }
        } catch(e) {}
    }

    function performSearch(customQuery) {
        var query = (customQuery !== undefined && customQuery !== null) ? customQuery : searchInput.text;
        if (!query) return;
        query = query.replace(/^\s+|\s+$/g, "");
        if (query.length === 0) return;

        searchInput.text = query;
        currentSearchQuery = query;
        isSearchMode = true;
        busyIndicator.running = true;
        emptyLabel.visible = false;
        trackModel.clear();

        if (typeof meegoBridge !== "undefined") {
            meegoBridge.addRecentSearch(query);
            loadRecent();
            meegoBridge.searchTracks(appWindow.serverUrl, query);
        }
    }

    function clearSearch() {
        searchInput.text = "";
        currentSearchQuery = "";
        isSearchMode = false;
        trackModel.clear();
        emptyLabel.visible = false;
        loadRecent();
    }
}
