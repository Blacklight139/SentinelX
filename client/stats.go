package client

import (
	"context"
	"net/http"
)

// Stats handles statistics operations.
type Stats struct {
	client *Client
}

// NewStats creates a new Stats handler.
func NewStats(client *Client) *Stats {
	return &Stats{client: client}
}

// Get returns the current statistics.
func (s *Stats) Get(ctx context.Context) (*StatsResponse, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", s.client.cfg.ServerURL+"/api/v1/stats", nil)
	if err != nil {
		return nil, err
	}
	s.client.setAuthHeader(req)

	var resp StatsResponse
	if err := s.client.doRequest(req, &resp); err != nil {
		return nil, err
	}
	return &resp, nil
}

// StatsResponse represents statistics response.
type StatsResponse struct {
	TotalLogs     int64            `json:"total_logs"`
	TotalAlerts   int64            `json:"total_alerts"`
	ActiveMonitors int              `json:"active_monitors"`
	Uptime        int64            `json:"uptime"`
}
