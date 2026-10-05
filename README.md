# MeeGoify (v3.0.0) 🎵
### Modern Music Streaming & Player for Nokia N9 (MeeGo 1.2 Harmattan)

[![MeeGo 1.2 Harmattan](https://img.shields.io/badge/Platform-MeeGo%201.2%20Harmattan-00adef.svg)](https://en.wikipedia.org/wiki/MeeGo)
[![Device](https://img.shields.io/badge/Device-Nokia%20N9-black.svg)](https://en.wikipedia.org/wiki/Nokia_N9)
[![Go Version](https://img.shields.io/badge/Go-1.18%2B-00ADD8.svg)](https://golang.org)
[![Python Version](https://img.shields.io/badge/Python-2.6%20%2F%20PySide-3776AB.svg)](https://wiki.qt.io/PySide)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> [🇹🇷 Türkçe Dokümantasyon için buraya tıklayın (README_TR.md)](README_TR.md)

**MeeGoify** is a complete, modern music streaming solution tailored specifically for the legendary **Nokia N9** running **MeeGo 1.2 Harmattan**. It pairs a high-performance **Go Bridge Server** running on your local network (PC / Mac / Raspberry Pi) with a native **PySide / QtQuick QML Client** running directly on the Nokia N9.

Enjoy rich streaming, Spotify & Deezer search, synchronized scrolling lyrics, glance/lock-screen controls via D-Bus MPRIS2, offline downloads, and a pure AMOLED black UI designed to honor MeeGo Harmattan's Blanco design language.

---

## 📸 Screenshots & Highlights

- **Pure AMOLED Black Design (`#000000`):** Maximizes battery life and contrast on the Nokia N9's ClearBlack display.
- **Dynamic Homepage Dashboard:**
  - **Quick Genre & Category Pills:** Tap to explore Pop, Rock, Rap, 90s, Acoustic, Hits, Electronic, and Chill with custom high-contrast 48x48 PNG icons.
  - **Recent Searches (Son Aramalar):** Tagged search history chips with quick re-search and one-tap removal.
  - **Recently Played (Son Dinlenenler):** History of played songs with album thumbnails and instant playback.
- **Multi-Source Cover Art Resolver:** Automatically falls back to Deezer and iTunes public APIs when Spotify CDN blocks legacy requests.
- **MeeGo D-Bus MPRIS2 Integration:** Full album art and track metadata on the MeeGo Glance Screen, Lock Screen, and 3.5mm headset remote control.
- **Synchronized Lyrics:** Real-time scrolling lyrics powered by [LRCLIB](https://lrclib.net/) with tap-to-seek functionality.
- **Offline Download Manager:** Download favorite MP3 tracks straight into `/home/user/MyDocs/Music/MeeGoify` for playback anywhere.

---

## 📐 System Architecture

```text
               +-------------------------------------------+
               |        Nokia N9 (MeeGo Harmattan)         |
               |                                           |
               |   • PySide & QtQuick 1.1 QML UI (AMOLED)  |
               |   • D-Bus MPRIS2 (Glance & Lock Screen)   |
               |   • GStreamer / Phonon Local Playback     |
               |   • Background Download Manager           |
               +-------------------------------------------+
                                     ▲
                                     │ Plain HTTP / MP3 Streams
                                     │ Port 8080 (TCP) & 8088 (UDP)
                                     ▼
               +-------------------------------------------+
               |        Go Bridge Server (PC / NAS)        |
               |                                           |
               |   • Spotify Web API & Search Engine       |
               |   • Deezer & iTunes Fallback Resolvers    |
               |   • Audio Stream Transcoder & Disk Cache  |
               |   • HTTP 206 Partial Content (Fast Seek)  |
               |   • LRCLIB Synchronized Lyrics Service    |
               |   • UDP Auto-Discovery Broadcast Server   |
               +-------------------------------------------+
```

---

## 📁 Repository Structure

```text
meegoify/
├── README.md               # English Documentation
├── README_TR.md            # Turkish Documentation
├── LICENSE                 # MIT License
├── .gitignore              # Git Ignore configuration
├── update_n9.sh            # Nokia N9 Automated Installer / Updater
├── server/                 # Go Bridge Server
│   ├── .env.example        # Environment configuration template
│   ├── go.mod              # Go module definition
│   ├── config.go           # Server configuration & cache management
│   ├── lyrics.go           # LRCLIB synchronized lyrics client
│   ├── main.go             # Main HTTP router, discovery & entry point
│   ├── proxy.go            # High-compatibility cover proxy with Deezer/iTunes resolver
│   ├── spotify.go          # Spotify API client with search fallback
│   └── stream.go           # Audio streaming & disk cache engine
└── client/                 # Nokia N9 PySide / QML Client
    ├── main.py             # PySide launcher, bridge, D-Bus MPRIS2 service
    ├── harmattan/
    │   ├── meegoify.desktop # MeeGo Application Menu entry
    │   └── meegoify.png     # 80x80 Harmattan app icon
    └── qml/                # QML User Interface
        ├── main.qml        # Root window, state machine, audio controller
        ├── SearchPage.qml  # Dashboard: Genre pills, search, recent history
        ├── PlayerPage.qml  # Player view, album cover, synced lyrics, seeker
        ├── LibraryPage.qml # Favorites & recommended tracks
        ├── meegoify_logo.png# MeeGoify badge logo
        ├── genre_*.png     # 8 Dedicated 48x48 category icons
        └── components/
            └── TrackDelegate.qml # Reusable AMOLED list item
```

---

## 🛠️ Prerequisites

### 1. For the Bridge Server (PC / Laptop / Server)
- **Go 1.18 or higher** (Windows, Linux, or macOS).
- **Network:** Connected to the same local Wi-Fi network as the Nokia N9.
- **Port Access:** Inbound connections permitted on ports `8080` (HTTP) and `8088` (UDP).

### 2. For the Nokia N9 Phone
- **Nokia N9** running MeeGo 1.2 Harmattan (PR 1.3 recommended).
- **Developer Mode enabled:** Settings > Security > Developer Mode (provides Terminal and `devel-su`).
- **Required Packages:** Installed via Terminal on the phone:
  ```sh
  devel-su
  # Default root password is: rootme
  apt-get update
  apt-get install python python-pyside.qtgui python-pyside.qtdeclarative python-dbus
  ```

---

## 🚀 Setup & Installation Guide

### Phase 1: Bridge Server Setup (on your PC)

1. Clone or extract the repository:
   ```bash
   git clone https://github.com/your-username/meegoify.git
   cd meegoify/server
   ```
2. Create your `.env` configuration file:
   ```bash
   cp .env.example .env
   ```
   Edit `.env` (optional: you can insert your Spotify Developer Client ID/Secret, or leave defaults to use the built-in fallback search):
   ```ini
   SPOTIFY_CLIENT_ID=your_client_id
   SPOTIFY_CLIENT_SECRET=your_client_secret
   REDIRECT_URI=http://localhost:8080/callback
   PORT=8080
   DISCOVERY_PORT=8088
   CACHE_DIR=cache
   AUDIO_BITRATE=128k
   ```
3. Start the server:
   ```bash
   go run .
   ```
   *Note: Ensure your Windows Firewall or OS firewall allows port `8080` on private networks.*

---

### Phase 2: Nokia N9 Client Installation

1. **Find your Nokia N9 IP address:**
   On your phone, go to Settings > Internet connections > Wi-Fi network details (e.g., `192.168.8.144`).

2. **Transfer the files to your Nokia N9 (from PC PowerShell or Terminal):**
   ```powershell
   # If transferring a packaged zip:
   scp -O -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa MeeGoify-v3.0.0.zip user@<N9-IP>:/home/user/meegoify.zip
   ```

3. **Install on Nokia N9 (via SSH or Phone Terminal):**
   ```sh
   # Connect via SSH from PC:
   ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa user@<N9-IP>

   # Switch to root:
   devel-su
   # (default password: rootme)

   # Extract and run the installer:
   rm -rf /tmp/meegoify_pkg
   python -c "import zipfile; zipfile.ZipFile('/home/user/meegoify.zip').extractall('/tmp/meegoify_pkg')"
   cd /tmp/meegoify_pkg
   sh update_n9.sh
   ```

4. **Launch the App:**
   - Tap the **MeeGoify** icon in the Nokia N9 Application Grid.
   - Or run from terminal for debugging:
     ```sh
     /opt/meegoify/main.py
     ```

5. **Connect to Server:**
   - On first launch, open **Settings** (gear icon in bottom toolbar).
   - Enter your PC IP address (e.g., `http://192.168.8.137:8080`) or tap **🔍 Auto-Discover Server** to detect it automatically.

---

## 🔍 Troubleshooting & FAQ

- **`QNetworkReplyImpl::_q_startOperation was called more than once`:**
  - This is a normal, non-critical Qt 4.7 internal message printed when parallel HTTP image/cover requests are executed. It does not cause errors or crashes.
- **`Meego graphics system destroyed`:**
  - This is the standard log produced by Harmattan X11 when the application window is closed.
- **Covers not loading:**
  - Verify that the PC Bridge Server is running and reachable from the phone browser by opening `http://<PC-IP>:8080/api/health`.
  - MeeGoify v3.0.0 features automatic Deezer & iTunes fallback cover resolution to bypass Spotify CDN 403 blocks.
- **SSH connection issues:**
  - Modern OpenSSH requires legacy RSA algorithms. Always pass `-o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa`.

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).
Nokia, MeeGo, Harmattan, and Spotify are trademarks of their respective owners.
