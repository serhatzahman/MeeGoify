package main

import (
	"bytes"
	"crypto/sha1"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

type Streamer struct {
	ytDlpPath  string
	ffmpegPath string
	bitrate    string
	cacheDir   string
	activeJobs sync.Map
}

func NewStreamer(ytDlpPath, ffmpegPath, bitrate, cacheDir string) *Streamer {
	return &Streamer{
		ytDlpPath:  ytDlpPath,
		ffmpegPath: ffmpegPath,
		bitrate:    bitrate,
		cacheDir:   cacheDir,
	}
}

func (s *Streamer) cleanQuery(q string) string {
	for strings.Contains(q, "%") {
		if u, err := url.QueryUnescape(q); err == nil && u != q {
			q = u
		} else {
			break
		}
	}
	return strings.TrimSpace(q)
}

func (s *Streamer) getCacheFilename(query string) string {
	query = s.cleanQuery(query)
	hasher := sha1.New()
	hasher.Write([]byte(query))
	return filepath.Join(s.cacheDir, hex.EncodeToString(hasher.Sum(nil))+".mp3")
}

// Prefetch downloads and transcodes a track in the background for gapless playback.
func (s *Streamer) Prefetch(query string) {
	query = s.cleanQuery(query)
	cachedFile := s.getCacheFilename(query)
	if _, err := os.Stat(cachedFile); err == nil {
		return // Already cached
	}

	go func() {
		log.Printf("[Prefetch] Pre-buffering track in background: '%s'", query)
		_, _ = s.ensureCached(query)
	}()
}

// ensureCached guarantees the MP3 file is present in the cache, downloading/transcoding if needed.
func (s *Streamer) ensureCached(query string) (string, error) {
	query = s.cleanQuery(query)
	cachedFile := s.getCacheFilename(query)

	// Check if already completely cached
	if info, err := os.Stat(cachedFile); err == nil && info.Size() > 1024 {
		return cachedFile, nil
	}

	// Avoid duplicate concurrent conversions for the same track
	lockKey := cachedFile + ".lock"
	actualLock, _ := s.activeJobs.LoadOrStore(lockKey, &sync.Mutex{})
	jobMutex := actualLock.(*sync.Mutex)
	jobMutex.Lock()
	defer jobMutex.Unlock()

	// Double check after acquiring lock
	if info, err := os.Stat(cachedFile); err == nil && info.Size() > 1024 {
		return cachedFile, nil
	}

	// Unique temp file per attempt to avoid Windows file lock collisions
	tempFile := fmt.Sprintf("%s.%d.tmp", cachedFile, time.Now().UnixNano())
	defer func() { _ = os.Remove(tempFile) }()

	log.Printf("[Transcode] Downloading and transcoding '%s' to cache...", query)

	ytCmd := exec.Command(s.ytDlpPath,
		"--default-search", "ytsearch1",
		"--format", "bestaudio/best",
		"--extractor-args", "youtube:player_client=android,web",
		"--no-playlist",
		"--no-warnings",
		"-o", "-",
		query,
	)

	var ytStderr bytes.Buffer
	ytCmd.Stderr = &ytStderr

	ffmpegCmd := exec.Command(s.ffmpegPath,
		"-i", "pipe:0",
		"-f", "mp3",
		"-acodec", "libmp3lame",
		"-b:a", s.bitrate,
		"-ar", "44100",
		"-ac", "2",
		"-vn",
		tempFile,
	)

	pipeReader, pipeWriter := io.Pipe()
	ytCmd.Stdout = pipeWriter
	ffmpegCmd.Stdin = pipeReader

	if err := ytCmd.Start(); err != nil {
		return "", fmt.Errorf("yt-dlp failed to start: %w", err)
	}

	if err := ffmpegCmd.Start(); err != nil {
		_ = ytCmd.Process.Kill()
		return "", fmt.Errorf("ffmpeg failed to start: %w", err)
	}

	go func() {
		defer pipeWriter.Close()
		_ = ytCmd.Wait()
	}()

	if err := ffmpegCmd.Wait(); err != nil {
		return "", fmt.Errorf("ffmpeg encoding error: %w (yt-dlp: %s)", err, strings.TrimSpace(ytStderr.String()))
	}

	// Move completed temp file to final cache destination
	_ = os.Remove(cachedFile)
	if err := os.Rename(tempFile, cachedFile); err != nil {
		return "", fmt.Errorf("failed to finalize cache file: %w", err)
	}

	log.Printf("[Cache SAVED] Successfully cached '%s' -> %s", query, cachedFile)
	return cachedFile, nil
}

// StreamMP3 serves the audio track with full HTTP Range (206) support for fast seeking on Nokia N9.
func (s *Streamer) StreamMP3(w http.ResponseWriter, r *http.Request, query string) {
	query = s.cleanQuery(query)
	cachedFile := s.getCacheFilename(query)

	if _, err := os.Stat(cachedFile); err == nil {
		log.Printf("[Cache HIT] Serving '%s'", query)
		http.ServeFile(w, r, cachedFile)
		return
	}

	log.Printf("[Cache MISS] Generating audio on demand for '%s'", query)
	finalFile, err := s.ensureCached(query)
	if err != nil {
		log.Printf("[Stream Error] %v", err)
		http.Error(w, fmt.Sprintf("Stream error: %v", err), http.StatusInternalServerError)
		return
	}

	http.ServeFile(w, r, finalFile)
}
