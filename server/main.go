package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
)

func cleanParam(s string) string {
	for strings.Contains(s, "%") {
		if u, err := url.QueryUnescape(s); err == nil && u != s {
			s = u
		} else {
			break
		}
	}
	return strings.TrimSpace(s)
}

func main() {
	cfg := LoadConfig()

	if cfg.SpotifyClientID == "" || cfg.SpotifyClientSecret == "" {
		log.Println("WARNING: SPOTIFY_CLIENT_ID or SPOTIFY_CLIENT_SECRET is not set!")
		log.Println("Please set them in your environment or in a .env file.")
	}

	spotify := NewSpotifyClient(cfg.SpotifyClientID, cfg.SpotifyClientSecret, cfg.RedirectURI)
	streamer := NewStreamer(cfg.YtDlpPath, cfg.FFmpegPath, cfg.AudioBitrate, cfg.CacheDir)
	imgProxy := NewImageProxy()
	lyricsService := NewLyricsService()

	// Start UDP discovery responder in background
	go startDiscoveryServer(cfg.DiscoveryPort, cfg.Port)

	mux := http.NewServeMux()

	// Health & Auto-discovery endpoint
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":      "ok",
			"version":     "3.0.0",
			"target":      "Nokia N9 MeeGo Harmattan Bridge",
			"cache_dir":   cfg.CacheDir,
			"user_logged": spotify.IsUserLoggedIn(),
		})
	})

	mux.HandleFunc("/api/discover", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"service": "spotify-n9-bridge",
			"version": "3.0.0",
			"status":  "ready",
		})
	})

	// Search endpoint: /api/search?q=query&limit=20
	mux.HandleFunc("/api/search", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}

		query := r.URL.Query().Get("q")
		if query == "" {
			http.Error(w, `{"error":"query parameter 'q' is required"}`, http.StatusBadRequest)
			return
		}

		limit := 10
		if lStr := r.URL.Query().Get("limit"); lStr != "" {
			if l, err := strconv.Atoi(lStr); err == nil && l > 0 && l <= 10 {
				limit = l
			}
		}

		tracks, err := spotify.Search(query, limit)
		if err != nil {
			log.Printf("[Error] Spotify Search failed: %v", err)
			http.Error(w, fmt.Sprintf(`{"error":%q}`, err.Error()), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(tracks)
	})

	// Public / Targeted Playlist tracks: /api/playlist?id=playlist_id
	mux.HandleFunc("/api/playlist", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}

		playlistID := r.URL.Query().Get("id")
		if playlistID == "" {
			http.Error(w, `{"error":"parameter 'id' is required"}`, http.StatusBadRequest)
			return
		}

		tracks, err := spotify.GetPlaylistTracks(playlistID)
		if err != nil {
			log.Printf("[Error] Playlist fetch failed: %v", err)
			http.Error(w, fmt.Sprintf(`{"error":%q}`, err.Error()), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(tracks)
	})

	// Audio streaming with disk cache & Range support: /api/stream?artist=...&title=...
	mux.HandleFunc("/api/stream", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w)
		artist := cleanParam(r.URL.Query().Get("artist"))
		title := cleanParam(r.URL.Query().Get("title"))
		q := cleanParam(r.URL.Query().Get("q"))

		searchQuery := q
		if searchQuery == "" {
			if artist != "" && title != "" {
				searchQuery = fmt.Sprintf("%s - %s audio", artist, title)
			} else if title != "" {
				searchQuery = fmt.Sprintf("%s audio", title)
			}
		}

		if searchQuery == "" {
			http.Error(w, "missing track search parameters", http.StatusBadRequest)
			return
		}

		streamer.StreamMP3(w, r, searchQuery)
	})

	// Background Pre-buffering: /api/prefetch?artist=...&title=...
	mux.HandleFunc("/api/prefetch", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w)
		artist := cleanParam(r.URL.Query().Get("artist"))
		title := cleanParam(r.URL.Query().Get("title"))
		q := cleanParam(r.URL.Query().Get("q"))

		searchQuery := q
		if searchQuery == "" && artist != "" && title != "" {
			searchQuery = fmt.Sprintf("%s - %s audio", artist, title)
		}

		if searchQuery != "" {
			streamer.Prefetch(searchQuery)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "buffering_queued"})
	})

	// Lyrics endpoint: /api/lyrics?artist=...&title=...&album=...&duration=...
	mux.HandleFunc("/api/lyrics", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w)
		artist := r.URL.Query().Get("artist")
		title := r.URL.Query().Get("title")
		album := r.URL.Query().Get("album")
		durationStr := r.URL.Query().Get("duration")

		durationSec := 0
		if d, err := strconv.Atoi(durationStr); err == nil {
			durationSec = d
		}

		lyrics, err := lyricsService.FetchLyrics(artist, title, album, durationSec)
		if err != nil {
			log.Printf("[Lyrics] %v for %s - %s", err, artist, title)
			http.Error(w, `{"error":"lyrics not found"}`, http.StatusNotFound)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(lyrics)
	})

	// Cover art proxy: /api/cover?url=...
	mux.HandleFunc("/api/cover", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w)
		targetURL := cleanParam(r.URL.Query().Get("url"))
		imgProxy.ServeImage(w, r, targetURL)
	})

	// Spotify User OAuth Flow
	mux.HandleFunc("/login", func(w http.ResponseWriter, r *http.Request) {
		authURL := spotify.GetAuthURL("n9-state")
		http.Redirect(w, r, authURL, http.StatusFound)
	})

	mux.HandleFunc("/callback", func(w http.ResponseWriter, r *http.Request) {
		if errParam := r.URL.Query().Get("error"); errParam != "" {
			log.Printf("[Spotify Auth Error] %s: %s", errParam, r.URL.Query().Get("error_description"))
			http.Error(w, fmt.Sprintf("Spotify Auth Error: %s", errParam), http.StatusBadRequest)
			return
		}
		code := r.URL.Query().Get("code")
		if code == "" {
			http.Error(w, "missing authorization code", http.StatusBadRequest)
			return
		}

		if err := spotify.ExchangeCode(code); err != nil {
			http.Error(w, fmt.Sprintf("failed to exchange code: %v", err), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		fmt.Fprintf(w, `<!DOCTYPE html>
<html>
<head><title>Spotify N9 Giriş Başarılı</title></head>
<body style="font-family:sans-serif; text-align:center; padding-top:50px; background:#121212; color:#1db954;">
  <h1>✓ Spotify Girişi Başarılı!</h1>
  <p style="color:#ffffff;">Nokia N9 cihazınız artık kişisel çalma listelerinize ve beğenilen şarkılarınıza erişebilir.</p>
</body>
</html>`)
	})

	mux.HandleFunc("/api/auth/status", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]bool{
			"logged_in": spotify.IsUserLoggedIn(),
		})
	})

	mux.HandleFunc("/api/me/library", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w)
		tracks, err := spotify.GetUserLikedSongs(50)
		if err != nil {
			http.Error(w, fmt.Sprintf(`{"error":%q}`, err.Error()), http.StatusUnauthorized)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(tracks)
	})

	mux.HandleFunc("/api/me/playlists", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w)
		playlists, err := spotify.GetUserPlaylists()
		if err != nil {
			http.Error(w, fmt.Sprintf(`{"error":%q}`, err.Error()), http.StatusUnauthorized)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(playlists)
	})

	addr := ":" + cfg.Port
	log.Printf("==================================================")
	log.Printf("  Nokia N9 Spotify Bridge Server (v3.0.0)")
	log.Printf("  Listening on http://0.0.0.0%s", addr)
	log.Printf("  Cache directory: %s", cfg.CacheDir)
	log.Printf("  User Login: http://localhost%s/login", addr)
	log.Printf("==================================================")

	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}

func startDiscoveryServer(udpPort, httpPort string) {
	addr, err := net.ResolveUDPAddr("udp", ":"+udpPort)
	if err != nil {
		return
	}
	conn, err := net.ListenUDP("udp", addr)
	if err != nil {
		return
	}
	defer conn.Close()

	buf := make([]byte, 1024)
	for {
		n, remoteAddr, err := conn.ReadFrom(buf)
		if err != nil {
			continue
		}
		msg := strings.TrimSpace(string(buf[:n]))
		if msg == "SPOTIFY_N9_DISCOVER" {
			resp := []byte("SPOTIFY_N9_SERVER:" + httpPort)
			_, _ = conn.WriteTo(resp, remoteAddr)
		}
	}
}

func enableCORS(w http.ResponseWriter) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, Range")
	w.Header().Set("Access-Control-Expose-Headers", "Content-Range, Accept-Ranges, Content-Length")
}
