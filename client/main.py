#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
MeeGoify Client - Version 3.0.0
MeeGo 1.2 Harmattan PySide Launcher with Native Python Async Networking,
D-Bus MPRIS Lock Screen & Headset Support, and Offline Download Manager.
"""

import sys
import os
import socket
import urllib
import urllib2
import threading

try:
    from PySide import QtCore, QtGui, QtDeclarative
except ImportError:
    print("Error: PySide is not installed on this system.")
    print("On Nokia N9: apt-get install python-pyside.qtgui python-pyside.qtdeclarative")
    sys.exit(1)

HAS_DBUS = False
try:
    import dbus
    import dbus.service
    from dbus.mainloop.glib import DBusGMainLoop
    DBusGMainLoop(set_as_default=True)
    HAS_DBUS = True
except Exception as e:
    pass


class MprisPlayer(object):
    def __init__(self, bridge):
        self.bridge = bridge
        self.playback_status = "Stopped"
        self.metadata = {}
        if not HAS_DBUS:
            return
        try:
            self.bus = dbus.SessionBus()
            self.bus_name = dbus.service.BusName("org.mpris.MediaPlayer2.spotify", self.bus)
            self.service_obj = MprisService(self, self.bus, "/org/mpris/MediaPlayer2")
        except Exception:
            pass

    def update_metadata(self, title, artist, album, cover_url, duration_ms):
        self.metadata = {
            "mpris:trackid": dbus.String("/org/mpris/MediaPlayer2/Track/1", variant_level=1) if HAS_DBUS else "/track/1",
            "xesam:title": dbus.String(title, variant_level=1) if HAS_DBUS else title,
            "xesam:artist": dbus.Array([dbus.String(artist)], variant_level=1) if HAS_DBUS else [artist],
            "xesam:album": dbus.String(album, variant_level=1) if HAS_DBUS else album,
            "mpris:artUrl": dbus.String(cover_url, variant_level=1) if HAS_DBUS else cover_url,
            "mpris:length": dbus.Int64(duration_ms * 1000, variant_level=1) if HAS_DBUS else duration_ms * 1000,
        }
        self.playback_status = "Playing"

    def set_status(self, is_playing):
        self.playback_status = "Playing" if is_playing else "Paused"


if HAS_DBUS:
    class MprisService(dbus.service.Object):
        def __init__(self, player, bus, path):
            dbus.service.Object.__init__(self, bus, path)
            self.player = player

        @dbus.service.method("org.mpris.MediaPlayer2.Player")
        def PlayPause(self):
            QtCore.QMetaObject.invokeMethod(self.player.bridge, "onMprisPlayPause", QtCore.Qt.QueuedConnection)

        @dbus.service.method("org.mpris.MediaPlayer2.Player")
        def Next(self):
            QtCore.QMetaObject.invokeMethod(self.player.bridge, "onMprisNext", QtCore.Qt.QueuedConnection)

        @dbus.service.method("org.mpris.MediaPlayer2.Player")
        def Previous(self):
            QtCore.QMetaObject.invokeMethod(self.player.bridge, "onMprisPrevious", QtCore.Qt.QueuedConnection)

        @dbus.service.method("org.mpris.MediaPlayer2.Player")
        def Stop(self):
            QtCore.QMetaObject.invokeMethod(self.player.bridge, "onMprisStop", QtCore.Qt.QueuedConnection)

        @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="ss", out_signature="v")
        def Get(self, interface, prop):
            if prop == "PlaybackStatus":
                return self.player.playback_status
            elif prop == "Metadata":
                return self.player.metadata
            return ""


class MeeGoBridge(QtCore.QObject):
    # Networking Signals (Fast & stable Python background threads)
    searchResultsReady = QtCore.Signal(str)
    searchFailed = QtCore.Signal(str)
    libraryReady = QtCore.Signal(str)
    libraryFailed = QtCore.Signal(str)
    playlistsReady = QtCore.Signal(str)
    playlistsFailed = QtCore.Signal(str)
    lyricsReady = QtCore.Signal(str)
    lyricsFailed = QtCore.Signal(str)

    # OS & Playback Signals
    serverDiscovered = QtCore.Signal(str)
    downloadProgress = QtCore.Signal(str, int)
    downloadCompleted = QtCore.Signal(str, str)
    downloadFailed = QtCore.Signal(str, str)
    mprisPlayPauseRequested = QtCore.Signal()
    mprisNextRequested = QtCore.Signal()
    mprisPreviousRequested = QtCore.Signal()


    def _get_config_dir(self):
        d = os.path.expanduser("~/.config/meegoify")
        if not os.path.exists(d):
            try:
                os.makedirs(d)
            except Exception:
                pass
        return d

    @QtCore.Slot(result=unicode)
    def getRecentSearches(self):
        try:
            p = os.path.join(self._get_config_dir(), "recent_searches.json")
            if os.path.exists(p):
                with open(p, "r") as f:
                    data = f.read()
                    return data.decode("utf-8") if isinstance(data, str) else data
        except Exception as e:
            print("Error loading recent searches:", e)
        return u"[]"

    @QtCore.Slot(str)
    def addRecentSearch(self, query):
        if not query:
            return
        q = query.strip()
        if not q:
            return
        try:
            searches_raw = self.getRecentSearches()
            import json
            searches = json.loads(searches_raw)
            if q in searches:
                searches.remove(q)
            searches.insert(0, q)
            searches = searches[:10]
            p = os.path.join(self._get_config_dir(), "recent_searches.json")
            with open(p, "w") as f:
                json.dump(searches, f)
        except Exception as e:
            print("Error saving recent search:", e)

    @QtCore.Slot(str)
    def removeRecentSearch(self, query):
        try:
            import json
            searches = json.loads(self.getRecentSearches())
            if query in searches:
                searches.remove(query)
                p = os.path.join(self._get_config_dir(), "recent_searches.json")
                with open(p, "w") as f:
                    json.dump(searches, f)
        except Exception as e:
            print("Error removing recent search:", e)

    @QtCore.Slot()
    def clearRecentSearches(self):
        try:
            p = os.path.join(self._get_config_dir(), "recent_searches.json")
            if os.path.exists(p):
                os.remove(p)
        except Exception as e:
            print("Error clearing recent searches:", e)

    @QtCore.Slot(result=unicode)
    def getRecentTracks(self):
        try:
            p = os.path.join(self._get_config_dir(), "recent_tracks.json")
            if os.path.exists(p):
                with open(p, "r") as f:
                    data = f.read()
                    return data.decode("utf-8") if isinstance(data, str) else data
        except Exception as e:
            print("Error loading recent tracks:", e)
        return u"[]"

    @QtCore.Slot(str)
    def addRecentTrack(self, track_json):
        try:
            import json
            track = json.loads(track_json)
            tracks = json.loads(self.getRecentTracks())
            tracks = [t for t in tracks if not (t.get("title") == track.get("title") and t.get("artist") == track.get("artist"))]
            tracks.insert(0, track)
            tracks = tracks[:15]
            p = os.path.join(self._get_config_dir(), "recent_tracks.json")
            with open(p, "w") as f:
                json.dump(tracks, f)
        except Exception as e:
            print("Error saving recent track:", e)

    @QtCore.Slot()
    def clearRecentTracks(self):
        try:
            p = os.path.join(self._get_config_dir(), "recent_tracks.json")
            if os.path.exists(p):
                os.remove(p)
        except Exception as e:
            print("Error clearing recent tracks:", e)

    def __init__(self, parent=None):
        super(MeeGoBridge, self).__init__(parent)
        self.mpris = MprisPlayer(self)

    # Fast background search without QML XMLHttpRequest issues
    @QtCore.Slot(result=unicode)
    def getLastSearchResults(self):
        res = getattr(self, "_last_search_results", "[]")
        if isinstance(res, str):
            return res.decode("utf-8", "replace")
        return res

    @QtCore.Slot(result=str)
    def getLastSearchError(self):
        return getattr(self, "_last_search_error", "")

    @QtCore.Slot(str, str)
    def fetchPlaylistTracks(self, server_url, playlist_id):
        def worker():
            try:
                url = "%s/api/playlist?id=%s" % (server_url.strip("/"), playlist_id)
                req = urllib2.Request(url)
                resp = urllib2.urlopen(req, timeout=15)
                data = resp.read()
                self._last_search_results = data
                self.searchResultsReady.emit(data)
            except Exception as e:
                self._last_search_error = str(e)
                self.searchFailed.emit(str(e))

        t = threading.Thread(target=worker)
        t.daemon = True
        t.start()

    @QtCore.Slot(str, str)
    def searchTracks(self, server_url, query):
        def worker():
            try:
                q = query.encode("utf-8") if isinstance(query, unicode) else str(query)
                url = "%s/api/search?q=%s" % (server_url.strip("/"), urllib.quote(q))
                req = urllib2.Request(url)
                resp = urllib2.urlopen(req, timeout=12)
                data = resp.read()
                self._last_search_results = data
                self.searchResultsReady.emit(data)
            except Exception as e:
                self._last_search_error = str(e)
                self.searchFailed.emit(str(e))

        t = threading.Thread(target=worker)
        t.daemon = True
        t.start()

    @QtCore.Slot(str)
    def fetchLibrary(self, server_url):
        def worker():
            try:
                url = "%s/api/me/library" % server_url.strip("/")
                req = urllib2.Request(url)
                resp = urllib2.urlopen(req, timeout=12)
                data = resp.read()
                self.libraryReady.emit(data)
            except urllib2.HTTPError as e:
                if e.code == 401:
                    self.libraryFailed.emit("UNAUTHORIZED")
                else:
                    self.libraryFailed.emit("HTTP %d" % e.code)
            except Exception as e:
                self.libraryFailed.emit(str(e))

        t = threading.Thread(target=worker)
        t.daemon = True
        t.start()

    @QtCore.Slot(str)
    def fetchPlaylists(self, server_url):
        def worker():
            try:
                url = "%s/api/me/playlists" % server_url.strip("/")
                req = urllib2.Request(url)
                resp = urllib2.urlopen(req, timeout=12)
                data = resp.read()
                self.playlistsReady.emit(data)
            except urllib2.HTTPError as e:
                if e.code == 401:
                    self.playlistsFailed.emit("UNAUTHORIZED")
                else:
                    self.playlistsFailed.emit("HTTP %d" % e.code)
            except Exception as e:
                self.playlistsFailed.emit(str(e))

        t = threading.Thread(target=worker)
        t.daemon = True
        t.start()

    @QtCore.Slot(str, str, str, str, int)
    def fetchLyrics(self, server_url, artist, title, album, duration_sec):
        def worker():
            try:
                def to_str(v):
                    return v.encode("utf-8") if isinstance(v, unicode) else str(v)
                params = urllib.urlencode({
                    "artist": to_str(artist),
                    "title": to_str(title),
                    "album": to_str(album),
                    "duration": str(duration_sec)
                })
                url = "%s/api/lyrics?%s" % (server_url.strip("/"), params)
                req = urllib2.Request(url)
                resp = urllib2.urlopen(req, timeout=10)
                data = resp.read()
                self.lyricsReady.emit(data)
            except Exception as e:
                self.lyricsFailed.emit(str(e))

        t = threading.Thread(target=worker)
        t.daemon = True
        t.start()

    @QtCore.Slot(str, str, str, str, int)
    def updateNowPlaying(self, title, artist, album, cover_url, duration_ms):
        self.mpris.update_metadata(title, artist, album, cover_url, duration_ms)

    @QtCore.Slot(bool)
    def updatePlaybackStatus(self, is_playing):
        self.mpris.set_status(is_playing)

    @QtCore.Slot()
    def onMprisPlayPause(self):
        self.mprisPlayPauseRequested.emit()

    @QtCore.Slot()
    def onMprisNext(self):
        self.mprisNextRequested.emit()

    @QtCore.Slot()
    def onMprisPrevious(self):
        self.mprisPreviousRequested.emit()

    @QtCore.Slot()
    def onMprisStop(self):
        self.mprisPlayPauseRequested.emit()

    @QtCore.Slot()
    def discoverServer(self):
        def run_discovery():
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
                s.settimeout(2.5)
                s.sendto("SPOTIFY_N9_DISCOVER", ("255.255.255.255", 8088))
                data, addr = s.recvfrom(1024)
                if data.startswith("SPOTIFY_N9_SERVER:"):
                    port = data.split(":")[1].strip()
                    server_url = "http://%s:%s" % (addr[0], port)
                    self.serverDiscovered.emit(server_url)
            except Exception:
                pass
            finally:
                try: s.close()
                except: pass

        t = threading.Thread(target=run_discovery)
        t.daemon = True
        t.start()

    @QtCore.Slot(str, str, str, str)
    def downloadTrack(self, track_id, stream_url, artist, title):
        def run_download():
            try:
                music_dir = "/home/user/MyDocs/Music/Spotify"
                if not os.path.exists("/home/user/MyDocs/Music"):
                    music_dir = os.path.expanduser("~/Music/Spotify")
                if not os.path.exists(music_dir):
                    os.makedirs(music_dir)

                safe_name = "%s - %s.mp3" % (artist.replace("/", "_"), title.replace("/", "_"))
                dest_path = os.path.join(music_dir, safe_name)

                req = urllib2.urlopen(stream_url, timeout=30)
                total_size = int(req.info().getheader("Content-Length") or 0)
                downloaded = 0
                block_size = 8192

                with open(dest_path, "wb") as f:
                    while True:
                        buf = req.read(block_size)
                        if not buf:
                            break
                        f.write(buf)
                        downloaded += len(buf)
                        if total_size > 0:
                            percent = int((float(downloaded) / total_size) * 100)
                            self.downloadProgress.emit(track_id, percent)

                self.downloadCompleted.emit(track_id, dest_path)
            except Exception as err:
                self.downloadFailed.emit(track_id, str(err))

        t = threading.Thread(target=run_download)
        t.daemon = True
        t.start()


def main():
    try:
        reload(sys)
        sys.setdefaultencoding('utf-8')
    except Exception:
        pass
    try:
        QtCore.QTextCodec.setCodecForCStrings(QtCore.QTextCodec.codecForName("UTF-8"))
        QtCore.QTextCodec.setCodecForTr(QtCore.QTextCodec.codecForName("UTF-8"))
    except Exception:
        pass
    app = QtGui.QApplication(sys.argv)
    app.setApplicationName("Spotify N9")
    app.setOrganizationName("MeeGo")

    bridge = MeeGoBridge()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    qml_file = os.path.join(script_dir, "qml", "main.qml")

    view = QtDeclarative.QDeclarativeView()
    view.rootContext().setContextProperty("meegoBridge", bridge)
    view.setSource(QtCore.QUrl.fromLocalFile(qml_file))
    view.setResizeMode(QtDeclarative.QDeclarativeView.SizeRootObjectToView)

    view.setAttribute(QtCore.Qt.WA_OpaquePaintEvent)
    view.setAttribute(QtCore.Qt.WA_NoSystemBackground)
    view.showFullScreen()

    sys.exit(app.exec_())

if __name__ == "__main__":
    main()
