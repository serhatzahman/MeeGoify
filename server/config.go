package main

import (
	"bufio"
	"os"
	"strings"
)

type Config struct {
	SpotifyClientID     string
	SpotifyClientSecret string
	RedirectURI         string
	Port                string
	DiscoveryPort       string
	CacheDir            string
	YtDlpPath           string
	FFmpegPath          string
	AudioBitrate        string
}

func LoadConfig() *Config {
	loadDotEnv(".env")

	cfg := &Config{
		SpotifyClientID:     getEnv("SPOTIFY_CLIENT_ID", ""),
		SpotifyClientSecret: getEnv("SPOTIFY_CLIENT_SECRET", ""),
		RedirectURI:         getEnv("REDIRECT_URI", "http://127.0.0.1:8080/callback"),
		Port:                getEnv("PORT", "8080"),
		DiscoveryPort:       getEnv("DISCOVERY_PORT", "8088"),
		CacheDir:            getEnv("CACHE_DIR", "cache"),
		YtDlpPath:           getEnv("YTDLP_PATH", "yt-dlp"),
		FFmpegPath:          getEnv("FFMPEG_PATH", "ffmpeg"),
		AudioBitrate:        getEnv("AUDIO_BITRATE", "128k"),
	}

	// Ensure cache directory exists
	_ = os.MkdirAll(cfg.CacheDir, 0755)

	return cfg
}

func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

func loadDotEnv(filepath string) {
	file, err := os.Open(filepath)
	if err != nil {
		return
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) == 2 {
			k := strings.TrimSpace(parts[0])
			v := strings.Trim(strings.TrimSpace(parts[1]), "\"'")
			if os.Getenv(k) == "" {
				os.Setenv(k, v)
			}
		}
	}
}
