package client

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
)

// Monitor handles monitoring operations.
type Monitor struct {
	client *Client
}

// NewMonitor creates a new Monitor handler.
func NewMonitor(client *Client) *Monitor {
	return &Monitor{client: client}
}

// Status returns the current monitor status.
func (m *Monitor) Status(ctx context.Context) (*MonitorStatus, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", m.client.cfg.ServerURL+"/api/v1/monitor/status", nil)
	if err != nil {
		return nil, err
	}
	m.client.setAuthHeader(req)

	var resp MonitorStatus
	if err := m.client.doRequest(req, &resp); err != nil {
		return nil, err
	}
	return &resp, nil
}

// Start starts monitoring for a target.
func (m *Monitor) Start(ctx context.Context, target string) (*MonitorResponse, error) {
	body, err := json.Marshal(&StartRequest{Target: target})
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, "POST", m.client.cfg.ServerURL+"/api/v1/monitor/start", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	m.client.setAuthHeader(req)
	req.Header.Set("Content-Type", "application/json")

	var resp MonitorResponse
	if err := m.client.doRequest(req, &resp); err != nil {
		return nil, err
	}
	return &resp, nil
}

// Stop stops the current monitoring.
func (m *Monitor) Stop(ctx context.Context) (*MonitorResponse, error) {
	req, err := http.NewRequestWithContext(ctx, "POST", m.client.cfg.ServerURL+"/api/v1/monitor/stop", nil)
	if err != nil {
		return nil, err
	}
	m.client.setAuthHeader(req)

	var resp MonitorResponse
	if err := m.client.doRequest(req, &resp); err != nil {
		return nil, err
	}
	return &resp, nil
}

// MonitorStatus represents the current monitor status.
type MonitorStatus struct {
	Running   bool   `json:"running"`
	Target    string `json:"target,omitempty"`
	StartTime int64  `json:"start_time,omitempty"`
}

// MonitorResponse represents a monitor operation response.
type MonitorResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message,omitempty"`
}

// StartRequest represents a start monitor request.
type StartRequest struct {
	Target string `json:"target"`
}
