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
	"strconv"
	"strings"
	"time"
)

type SyncedLine struct {
	Time int    `json:"time"`
	Text string `json:"text"`
}

type LyricsResponse struct {
	Plain  string       `json:"plain"`
	Synced []SyncedLine `json:"synced"`
}

type LyricsService struct {
	client   *http.Client
	cacheDir string
}

func NewLyricsService() *LyricsService {
	dir := filepath.Join("cache", "lyrics")
	_ = os.MkdirAll(dir, 0755)
	return &LyricsService{
		client:   &http.Client{Timeout: 8 * time.Second},
		cacheDir: dir,
	}
}

func parseLRC(lrcText string) []SyncedLine {
	lines := strings.Split(lrcText, "\n")
	re := regexp.MustCompile(`\[(\d+):(\d+(?:\.\d+)?)\](.*)`)
	var result []SyncedLine

	for _, line := range lines {
		line = strings.TrimSpace(line)
		matches := re.FindStringSubmatch(line)
		if len(matches) == 4 {
			min, _ := strconv.Atoi(matches[1])
			secFloat, _ := strconv.ParseFloat(matches[2], 64)
			totalMs := int((float64(min)*60.0 + secFloat) * 1000.0)
			text := strings.TrimSpace(matches[3])
			result = append(result, SyncedLine{
				Time: totalMs,
				Text: text,
			})
		}
	}
	return result
}

func (s *LyricsService) cleanText(text string) string {
	for strings.Contains(text, "%") {
		if u, err := url.QueryUnescape(text); err == nil && u != text {
			text = u
		} else {
			break
		}
	}
	return strings.TrimSpace(text)
}

func (s *LyricsService) FetchLyrics(artist, title, album string, durationSec int) (*LyricsResponse, error) {
	artist = s.cleanText(artist)
	title = s.cleanText(title)

	if artist == "" || title == "" {
		return nil, fmt.Errorf("artist and title are required")
	}

	cleanArtist := artist
	if idx := strings.Index(cleanArtist, ","); idx != -1 {
		cleanArtist = strings.TrimSpace(cleanArtist[:idx])
	}

	cleanTitle := title
	re := regexp.MustCompile(`(?i)\s*[\(\[](feat\.|ft\.|live|remastered|version).*?[\)\]]|\s*-\s*live.*`)
	cleanTitle = strings.TrimSpace(re.ReplaceAllString(cleanTitle, ""))

	cacheKey := fmt.Sprintf("%s-%s", cleanArtist, cleanTitle)
	hash := fmt.Sprintf("%x", md5.Sum([]byte(cacheKey)))
	cachePath := filepath.Join(s.cacheDir, hash+".json")

	if data, err := os.ReadFile(cachePath); err == nil && len(data) > 0 {
		var cached LyricsResponse
		if err := json.Unmarshal(data, &cached); err == nil {
			return &cached, nil
		}
	}

	queries := []string{
		fmt.Sprintf("https://lrclib.net/api/search?q=%s", url.QueryEscape(cleanArtist+" "+cleanTitle)),
		fmt.Sprintf("https://lrclib.net/api/search?track_name=%s&artist_name=%s", url.QueryEscape(cleanTitle), url.QueryEscape(cleanArtist)),
		fmt.Sprintf("https://lrclib.net/api/get?track_name=%s&artist_name=%s", url.QueryEscape(cleanTitle), url.QueryEscape(cleanArtist)),
	}

	for _, reqURL := range queries {
		resp, err := s.queryLRCLIB(reqURL)
		if err == nil && resp != nil {
			if len(resp.Synced) > 0 || resp.Plain != "" {
				if b, err := json.Marshal(resp); err == nil {
					_ = os.WriteFile(cachePath, b, 0644)
				}
				log.Printf("[Lyrics Found] Sozler basariyla alindi: "%s - %s"", cleanArtist, cleanTitle)
				return resp, nil
			}
		}
	}

	return nil, fmt.Errorf("lyrics not found for %s - %s", artist, title)
}

func (s *LyricsService) queryLRCLIB(targetURL string) (*LyricsResponse, error) {
	req, err := http.NewRequest("GET", targetURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "MeeGoify-N9-Bridge/2.0")

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil || len(body) == 0 {
		return nil, fmt.Errorf("empty body")
	}

	var searchResults []struct {
		TrackName    string `json:"trackName"`
		ArtistName   string `json:"artistName"`
		PlainLyrics  string `json:"plainLyrics"`
		SyncedLyrics string `json:"syncedLyrics"`
	}
	if err := json.Unmarshal(body, &searchResults); err == nil && len(searchResults) > 0 {
		for _, item := range searchResults {
			if item.SyncedLyrics != "" {
				return &LyricsResponse{
					Plain:  item.PlainLyrics,
					Synced: parseLRC(item.SyncedLyrics),
				}, nil
			}
			if item.PlainLyrics != "" {
				return &LyricsResponse{
					Plain:  item.PlainLyrics,
					Synced: nil,
				}, nil
			}
		}
	}

	var singleResult struct {
		TrackName    string `json:"trackName"`
		ArtistName   string `json:"artistName"`
		PlainLyrics  string `json:"plainLyrics"`
		SyncedLyrics string `json:"syncedLyrics"`
	}
	if err := json.Unmarshal(body, &singleResult); err == nil {
		if singleResult.SyncedLyrics != "" {
			return &LyricsResponse{
				Plain:  singleResult.PlainLyrics,
				Synced: parseLRC(singleResult.SyncedLyrics),
			}, nil
		}
		if singleResult.PlainLyrics != "" {
			return &LyricsResponse{
				Plain:  singleResult.PlainLyrics,
				Synced: nil,
			}, nil
		}
	}

	return nil, fmt.Errorf("no lyrics in response")
}
