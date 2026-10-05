package main

import (
	"crypto/md5"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

type ImageProxy struct {
	client   *http.Client
	cacheDir string
}

func NewImageProxy() *ImageProxy {
	dir := filepath.Join("cache", "covers")
	_ = os.MkdirAll(dir, 0755)
	return &ImageProxy{
		client:   &http.Client{Timeout: 10 * time.Second},
		cacheDir: dir,
	}
}

// 1x1 transparent GIF fallback (43 bytes) to satisfy Qt Quick Image without throwing HTTP errors
var fallbackGIF = []byte{
	0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00,
	0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0x21,
	0xf9, 0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x2c, 0x00, 0x00,
	0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x02, 0x44,
	0x01, 0x00, 0x3b,
}

func (p *ImageProxy) ServeImage(w http.ResponseWriter, r *http.Request, rawURL string) {
	artist := cleanParam(r.URL.Query().Get("artist"))
	title := cleanParam(r.URL.Query().Get("title"))

	// 1. Direct URL provided and valid
	if rawURL != "" && (strings.HasPrefix(rawURL, "http://") || strings.HasPrefix(rawURL, "https://")) {
		if p.serveCachedOrFetch(w, r, rawURL, rawURL) {
			return
		}
	}

	// 2. Fallback: Search by Artist & Title (Deezer -> iTunes)
	if artist != "" || title != "" {
		resolvedURL := p.resolveCover(artist, title)
		if resolvedURL != "" {
			cacheKey := fmt.Sprintf("%s-%s", artist, title)
			if p.serveCachedOrFetch(w, r, cacheKey, resolvedURL) {
				return
			}
		}
	}

	// 3. Fallback: Serve transparent 1x1 GIF with HTTP 200 OK so QML doesn't log Bad Request
	w.Header().Set("Content-Type", "image/gif")
	w.Header().Set("Cache-Control", "public, max-age=86400")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(fallbackGIF)
}

func (p *ImageProxy) serveCachedOrFetch(w http.ResponseWriter, r *http.Request, cacheKey, targetURL string) bool {
	hash := fmt.Sprintf("%x", md5.Sum([]byte(cacheKey)))
	cachePath := filepath.Join(p.cacheDir, hash+".jpg")

	// Check disk cache
	if fi, err := os.Stat(cachePath); err == nil && fi.Size() > 0 {
		w.Header().Set("Content-Type", "image/jpeg")
		w.Header().Set("Cache-Control", "public, max-age=86400")
		http.ServeFile(w, r, cachePath)
		return true
	}

	// Fetch from target URL
	req, err := http.NewRequestWithContext(r.Context(), "GET", targetURL, nil)
	if err != nil {
		return false
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
	req.Header.Set("Accept", "image/*,*/*;q=0.8")

	resp, err := p.client.Do(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		if resp != nil {
			resp.Body.Close()
		}
		return false
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil || len(data) == 0 {
		return false
	}

	// Save to disk cache
	_ = os.WriteFile(cachePath, data, 0644)

	contentType := resp.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "image/jpeg"
	}

	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Cache-Control", "public, max-age=86400")
	_, _ = w.Write(data)
	return true
}

func (p *ImageProxy) resolveCover(artist, title string) string {
	// Clean query for search
	cleanArtist := artist
	if idx := strings.Index(cleanArtist, ","); idx != -1 {
		cleanArtist = strings.TrimSpace(cleanArtist[:idx])
	}
	cleanTitle := title
	re := regexp.MustCompile(`(?i)\s*[\(\[](feat\.|ft\.|live|remastered|version).*?[\)\]]|\s*-\s*live.*`)
	cleanTitle = strings.TrimSpace(re.ReplaceAllString(cleanTitle, ""))

	queries := []string{
		fmt.Sprintf("%s %s", cleanArtist, cleanTitle),
		fmt.Sprintf("%s %s", artist, title),
		cleanTitle,
	}

	for _, q := range queries {
		q = strings.TrimSpace(q)
		if q == "" {
			continue
		}

		// Try Deezer
		if u := p.searchDeezer(q); u != "" {
			log.Printf("[Cover Resolved] Deezer found cover for '%s'", q)
			return u
		}

		// Try iTunes
		if u := p.searchITunes(q); u != "" {
			log.Printf("[Cover Resolved] iTunes found cover for '%s'", q)
			return u
		}
	}
	return ""
}

func (p *ImageProxy) searchDeezer(query string) string {
	apiURL := "https://api.deezer.com/search?q=" + url.QueryEscape(query)
	req, err := http.NewRequest("GET", apiURL, nil)
	if err != nil {
		return ""
	}
	req.Header.Set("User-Agent", "Mozilla/5.0")

	resp, err := p.client.Do(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		if resp != nil {
			resp.Body.Close()
		}
		return ""
	}
	defer resp.Body.Close()

	var result struct {
		Data []struct {
			Album struct {
				CoverBig    string `json:"cover_big"`
				CoverMedium string `json:"cover_medium"`
				Cover       string `json:"cover"`
			} `json:"album"`
		} `json:"data"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err == nil && len(result.Data) > 0 {
		album := result.Data[0].Album
		if album.CoverBig != "" {
			return album.CoverBig
		}
		if album.CoverMedium != "" {
			return album.CoverMedium
		}
		return album.Cover
	}
	return ""
}

func (p *ImageProxy) searchITunes(query string) string {
	apiURL := "https://itunes.apple.com/search?term=" + url.QueryEscape(query) + "&media=music&entity=song&limit=1"
	req, err := http.NewRequest("GET", apiURL, nil)
	if err != nil {
		return ""
	}
	req.Header.Set("User-Agent", "Mozilla/5.0")

	resp, err := p.client.Do(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		if resp != nil {
			resp.Body.Close()
		}
		return ""
	}
	defer resp.Body.Close()

	var result struct {
		Results []struct {
			ArtworkUrl100 string `json:"artworkUrl100"`
		} `json:"results"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err == nil && len(result.Results) > 0 {
		art := result.Results[0].ArtworkUrl100
		if art != "" {
			return strings.ReplaceAll(art, "100x100bb.jpg", "400x400bb.jpg")
		}
	}
	return ""
}
