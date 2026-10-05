package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

type SpotifyClient struct {
	clientID        string
	clientSecret    string
	redirectURI     string
	appToken        string
	appTokenExpiry  time.Time
	userToken       string
	userRefreshToken string
	userTokenExpiry time.Time
	mu              sync.Mutex
	httpClient      *http.Client
}

type Track struct {
	ID         string `json:"id"`
	Title      string `json:"title"`
	Artist     string `json:"artist"`
	Album      string `json:"album"`
	CoverURL   string `json:"cover_url"`
	DurationMs int    `json:"duration_ms"`
}

type PlaylistInfo struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	TotalTracks int   `json:"total_tracks"`
	CoverURL   string `json:"cover_url"`
}

func NewSpotifyClient(clientID, clientSecret, redirectURI string) *SpotifyClient {
	return &SpotifyClient{
		clientID:     clientID,
		clientSecret: clientSecret,
		redirectURI:  redirectURI,
		httpClient:   &http.Client{Timeout: 10 * time.Second},
	}
}

func (s *SpotifyClient) getAppAccessToken() (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.appToken != "" && time.Now().Before(s.appTokenExpiry) {
		return s.appToken, nil
	}

	auth := base64.StdEncoding.EncodeToString([]byte(s.clientID + ":" + s.clientSecret))
	data := url.Values{}
	data.Set("grant_type", "client_credentials")

	req, err := http.NewRequest("POST", "https://accounts.spotify.com/api/token", strings.NewReader(data.Encode()))
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Basic "+auth)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("spotify auth failed (%d): %s", resp.StatusCode, string(body))
	}

	var tokenRes struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&tokenRes); err != nil {
		return "", err
	}

	s.appToken = tokenRes.AccessToken
	s.appTokenExpiry = time.Now().Add(time.Duration(tokenRes.ExpiresIn-60) * time.Second)
	return s.appToken, nil
}

// User OAuth Authorization Code Flow
func (s *SpotifyClient) GetAuthURL(state string) string {
	scopes := "user-library-read playlist-read-private"
	params := url.Values{}
	params.Set("client_id", s.clientID)
	params.Set("response_type", "code")
	params.Set("redirect_uri", s.redirectURI)
	params.Set("scope", scopes)
	params.Set("state", state)
	params.Set("show_dialog", "true")

	// Spotify OAuth strictly expects %20 for spaces in scopes, not '+'
	encoded := strings.ReplaceAll(params.Encode(), "+", "%20")
	return "https://accounts.spotify.com/authorize?" + encoded
}

func (s *SpotifyClient) ExchangeCode(code string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	auth := base64.StdEncoding.EncodeToString([]byte(s.clientID + ":" + s.clientSecret))
	data := url.Values{}
	data.Set("grant_type", "authorization_code")
	data.Set("code", code)
	data.Set("redirect_uri", s.redirectURI)

	req, err := http.NewRequest("POST", "https://accounts.spotify.com/api/token", strings.NewReader(data.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Basic "+auth)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("exchange code failed (%d): %s", resp.StatusCode, string(body))
	}

	var tokenRes struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
		ExpiresIn    int    `json:"expires_in"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&tokenRes); err != nil {
		return err
	}

	s.userToken = tokenRes.AccessToken
	if tokenRes.RefreshToken != "" {
		s.userRefreshToken = tokenRes.RefreshToken
	}
	s.userTokenExpiry = time.Now().Add(time.Duration(tokenRes.ExpiresIn-60) * time.Second)
	return nil
}

func (s *SpotifyClient) getUserToken() (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.userToken != "" && time.Now().Before(s.userTokenExpiry) {
		return s.userToken, nil
	}

	if s.userRefreshToken == "" {
		return "", fmt.Errorf("user not logged in")
	}

	auth := base64.StdEncoding.EncodeToString([]byte(s.clientID + ":" + s.clientSecret))
	data := url.Values{}
	data.Set("grant_type", "refresh_token")
	data.Set("refresh_token", s.userRefreshToken)

	req, err := http.NewRequest("POST", "https://accounts.spotify.com/api/token", strings.NewReader(data.Encode()))
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Basic "+auth)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("refresh token failed (%d)", resp.StatusCode)
	}

	var tokenRes struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&tokenRes); err != nil {
		return "", err
	}

	s.userToken = tokenRes.AccessToken
	s.userTokenExpiry = time.Now().Add(time.Duration(tokenRes.ExpiresIn-60) * time.Second)
	return s.userToken, nil
}

func (s *SpotifyClient) IsUserLoggedIn() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.userRefreshToken != "" || (s.userToken != "" && time.Now().Before(s.userTokenExpiry))
}

func (s *SpotifyClient) Search(query string, limit int) ([]Track, error) {
	// Spotify Web API limits max 10 for dev apps
	if limit <= 0 || limit > 10 {
		limit = 10
	}

	token, err := s.getAppAccessToken()
	if err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("https://api.spotify.com/v1/search?q=%s&type=track&limit=%d", url.QueryEscape(query), limit)
	req, err := http.NewRequest("GET", endpoint, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("spotify search error (%d): %s", resp.StatusCode, string(body))
	}

	var searchRes struct {
		Tracks struct {
			Items []struct {
				ID      string `json:"id"`
				Name    string `json:"name"`
				Artists []struct {
					Name string `json:"name"`
				} `json:"artists"`
				Album struct {
					Name   string `json:"name"`
					Images []struct {
						URL string `json:"url"`
					} `json:"images"`
				} `json:"album"`
				DurationMs int `json:"duration_ms"`
			} `json:"items"`
		} `json:"tracks"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&searchRes); err != nil {
		return nil, err
	}

	tracks := make([]Track, 0, len(searchRes.Tracks.Items))
	for _, item := range searchRes.Tracks.Items {
		var artists []string
		for _, a := range item.Artists {
			artists = append(artists, a.Name)
		}

		cover := ""
		if len(item.Album.Images) > 0 {
			if len(item.Album.Images) > 1 {
				cover = item.Album.Images[1].URL
			} else {
				cover = item.Album.Images[0].URL
			}
		}

		tracks = append(tracks, Track{
			ID:         item.ID,
			Title:      item.Name,
			Artist:     strings.Join(artists, ", "),
			Album:      item.Album.Name,
			CoverURL:   cover,
			DurationMs: item.DurationMs,
		})
	}

	return tracks, nil
}

func (s *SpotifyClient) fetchPlaylistFromHTML(playlistID string) ([]Track, error) {
	pageURL := fmt.Sprintf("https://open.spotify.com/playlist/%s", playlistID)
	req, err := http.NewRequest("GET", pageURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)")
	req.Header.Set("Accept-Language", "tr,en;q=0.9")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	bodyStr := string(bodyBytes)
	tagStart := "application/ld+json"
	pos := strings.Index(bodyStr, tagStart)
	if pos == -1 {
		return nil, fmt.Errorf("application/ld+json not found (HTTP %d, len %d)", resp.StatusCode, len(bodyStr))
	}

	startIdx := strings.Index(bodyStr[pos:], ">")
	if startIdx == -1 {
		return nil, fmt.Errorf("malformed script tag")
	}
	startIdx += pos + 1
	endIdx := strings.Index(bodyStr[startIdx:], "</script>")
	if endIdx == -1 {
		return nil, fmt.Errorf("closing script tag not found")
	}

	jsonStr := strings.TrimSpace(bodyStr[startIdx : startIdx+endIdx])
	
	var ldData struct {
		Name  string `json:"name"`
		Track []struct {
			Name     string          `json:"name"`
			Duration string          `json:"duration"`
			URL      string          `json:"url"`
			ByArtist json.RawMessage `json:"byArtist"`
		} `json:"track"`
	}

	if err := json.Unmarshal([]byte(jsonStr), &ldData); err == nil && len(ldData.Track) > 0 {
		tracks := make([]Track, 0, len(ldData.Track))
		for _, t := range ldData.Track {
			id := t.URL
			if idx := strings.LastIndex(id, "/"); idx != -1 {
				id = id[idx+1:]
			}

			artistName := "Bilinmeyen Sanatci"
			var singleArtist struct {
				Name string `json:"name"`
			}
			var multiArtists []struct {
				Name string `json:"name"`
			}
			if err := json.Unmarshal(t.ByArtist, &multiArtists); err == nil && len(multiArtists) > 0 {
				names := make([]string, len(multiArtists))
				for i, a := range multiArtists {
					names[i] = a.Name
				}
				artistName = strings.Join(names, ", ")
			} else if err := json.Unmarshal(t.ByArtist, &singleArtist); err == nil && singleArtist.Name != "" {
				artistName = singleArtist.Name
			}

			tracks = append(tracks, Track{
				ID:         id,
				Title:      t.Name,
				Artist:     artistName,
				Album:      ldData.Name,
				DurationMs: 0,
			})
		}
		log.Printf("[Playlist] '%s' listesinden %d sarki basariyla alindi!", ldData.Name, len(tracks))
		return tracks, nil
	}

	return nil, fmt.Errorf("JSON parse failed or no tracks")
}

func (s *SpotifyClient) GetPlaylistTracks(playlistID string) ([]Track, error) {
	if tracks, err := s.fetchPlaylistFromHTML(playlistID); err == nil && len(tracks) > 0 {
		return tracks, nil
	} else if err != nil {
		log.Printf("[Playlist HTML Uyari] %v", err)
	}

	token, err := s.getAppAccessToken()
	if err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("https://api.spotify.com/v1/playlists/%s/tracks?limit=50", url.PathEscape(playlistID))
	req, err := http.NewRequest("GET", endpoint, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("spotify playlist error (%d): %s", resp.StatusCode, string(body))
	}

	var playlistRes struct {
		Items []struct {
			Track struct {
				ID      string `json:"id"`
				Name    string `json:"name"`
				Artists []struct {
					Name string `json:"name"`
				} `json:"artists"`
				Album struct {
					Name   string `json:"name"`
					Images []struct {
						URL string `json:"url"`
					} `json:"images"`
				} `json:"album"`
				DurationMs int `json:"duration_ms"`
			} `json:"track"`
		} `json:"items"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&playlistRes); err != nil {
		return nil, err
	}

	tracks := make([]Track, 0, len(playlistRes.Items))
	for _, item := range playlistRes.Items {
		if item.Track.ID == "" {
			continue
		}
		var artists []string
		for _, a := range item.Track.Artists {
			artists = append(artists, a.Name)
		}

		cover := ""
		if len(item.Track.Album.Images) > 0 {
			if len(item.Track.Album.Images) > 1 {
				cover = item.Track.Album.Images[1].URL
			} else {
				cover = item.Track.Album.Images[0].URL
			}
		}

		tracks = append(tracks, Track{
			ID:         item.Track.ID,
			Title:      item.Track.Name,
			Artist:     strings.Join(artists, ", "),
			Album:      item.Track.Album.Name,
			CoverURL:   cover,
			DurationMs: item.Track.DurationMs,
		})
	}

	return tracks, nil
}

func (s *SpotifyClient) GetUserLikedSongs(limit int) ([]Track, error) {
	token, err := s.getUserToken()
	if err != nil {
		return nil, err
	}

	if limit <= 0 || limit > 50 {
		limit = 30
	}

	endpoint := fmt.Sprintf("https://api.spotify.com/v1/me/tracks?limit=%d", limit)
	req, err := http.NewRequest("GET", endpoint, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("spotify me tracks error (%d): %s", resp.StatusCode, string(body))
	}

	var savedRes struct {
		Items []struct {
			Track struct {
				ID      string `json:"id"`
				Name    string `json:"name"`
				Artists []struct {
					Name string `json:"name"`
				} `json:"artists"`
				Album struct {
					Name   string `json:"name"`
					Images []struct {
						URL string `json:"url"`
					} `json:"images"`
				} `json:"album"`
				DurationMs int `json:"duration_ms"`
			} `json:"track"`
		} `json:"items"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&savedRes); err != nil {
		return nil, err
	}

	tracks := make([]Track, 0, len(savedRes.Items))
	for _, item := range savedRes.Items {
		var artists []string
		for _, a := range item.Track.Artists {
			artists = append(artists, a.Name)
		}

		cover := ""
		if len(item.Track.Album.Images) > 0 {
			if len(item.Track.Album.Images) > 1 {
				cover = item.Track.Album.Images[1].URL
			} else {
				cover = item.Track.Album.Images[0].URL
			}
		}

		tracks = append(tracks, Track{
			ID:         item.Track.ID,
			Title:      item.Track.Name,
			Artist:     strings.Join(artists, ", "),
			Album:      item.Track.Album.Name,
			CoverURL:   cover,
			DurationMs: item.Track.DurationMs,
		})
	}

	return tracks, nil
}

// GetUserPlaylists lists the user's private and followed playlists
func (s *SpotifyClient) GetUserPlaylists() ([]PlaylistInfo, error) {
	token, err := s.getUserToken()
	if err != nil {
		return nil, err
	}

	endpoint := "https://api.spotify.com/v1/me/playlists?limit=50"
	req, err := http.NewRequest("GET", endpoint, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("spotify me playlists error (%d): %s", resp.StatusCode, string(body))
	}

	var plRes struct {
		Items []struct {
			ID     string `json:"id"`
			Name   string `json:"name"`
			Tracks struct {
				Total int `json:"total"`
			} `json:"tracks"`
			Images []struct {
				URL string `json:"url"`
			} `json:"images"`
		} `json:"items"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&plRes); err != nil {
		return nil, err
	}

	playlists := make([]PlaylistInfo, 0, len(plRes.Items))
	for _, p := range plRes.Items {
		cover := ""
		if len(p.Images) > 0 {
			cover = p.Images[0].URL
		}
		playlists = append(playlists, PlaylistInfo{
			ID:          p.ID,
			Name:        p.Name,
			TotalTracks: p.Tracks.Total,
			CoverURL:    cover,
		})
	}

	return playlists, nil
}
