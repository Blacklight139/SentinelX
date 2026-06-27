package client

import (
	"context"
	"encoding/json"
	"net/http"
	"net/url"
	"strconv"
)

// Logs handles log operations.
type Logs struct {
	client *Client
}

// NewLogs creates a new Logs handler.
func NewLogs(client *Client) *Logs {
	return &Logs{client: client}
}

// List returns a list of logs matching the filter.
func (l *Logs) List(ctx context.Context, filter *LogFilter) ([]Log, error) {
	url := l.client.cfg.ServerURL + "/api/v1/logs"
	if filter != nil {
		url = filter.AppendParams(url)
	}

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}
	l.client.setAuthHeader(req)

	var resp struct {
		Logs []Log `json:"logs"`
	}
	if err := l.client.doRequest(req, &resp); err != nil {
		return nil, err
	}
	return resp.Logs, nil
}

// Get returns a single log by ID.
func (l *Logs) Get(ctx context.Context, id string) (*Log, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", l.client.cfg.ServerURL+"/api/v1/logs/"+id, nil)
	if err != nil {
		return nil, err
	}
	l.client.setAuthHeader(req)

	var resp Log
	if err := l.client.doRequest(req, &resp); err != nil {
		return nil, err
	}
	return &resp, nil
}

// Stream starts a WebSocket subscription for real-time logs.
func (l *Logs) Stream(ctx context.Context, filter *LogFilter, handler func(*Log)) error {
	if l.client.wsClient == nil {
		if err := l.client.Connect(ctx); err != nil {
			return err
		}
	}

	sub := &Subscription{
		Type:   "logs",
		Filter: filter,
	}
	return l.client.wsClient.Subscribe(ctx, sub, func(data []byte) {
		var log Log
		if err := json.Unmarshal(data, &log); err == nil {
			handler(&log)
		}
	})
}

// Log represents a log entry.
type Log struct {
	ID        string                 `json:"id"`
	Timestamp int64                   `json:"timestamp"`
	Level     string                 `json:"level"`
	Message   string                 `json:"message"`
	Metadata  map[string]interface{} `json:"metadata,omitempty"`
}

// LogFilter filters log queries.
type LogFilter struct {
	Levels   []string
	StartTime int64
	EndTime   int64
	Query     string
	Limit     int
}

func (f *LogFilter) AppendParams(base string) string {
	if f == nil {
		return base
	}
	params := url.Values{}
	if len(f.Levels) > 0 {
		for _, l := range f.Levels {
			params.Add("levels", l)
		}
	}
	if f.StartTime > 0 {
		params.Set("start_time", formatInt64(f.StartTime))
	}
	if f.EndTime > 0 {
		params.Set("end_time", formatInt64(f.EndTime))
	}
	if f.Query != "" {
		params.Set("query", f.Query)
	}
	if f.Limit > 0 {
		params.Set("limit", formatInt(f.Limit))
	}
	if len(params) > 0 {
		return base + "?" + params.Encode()
	}
	return base
}

func formatInt64(v int64) string {
	return strconv.FormatInt(v, 10)
}

func formatInt(v int) string {
	return strconv.Itoa(v)
}
