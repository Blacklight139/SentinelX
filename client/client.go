package client

import (
	"context"
	"net/http"
	"time"
)

// Config holds the client configuration.
type Config struct {
	ServerURL string
	AuthToken string
	Timeout   time.Duration
}

// Client is the SentinelX client.
type Client struct {
	cfg        *Config
	httpClient *http.Client
	wsClient   *WSClient
}

// NewClient creates a new SentinelX client.
func NewClient(cfg *Config) (*Client, error) {
	if cfg.ServerURL == "" {
		cfg.ServerURL = "http://localhost:8080"
	}
	if cfg.Timeout == 0 {
		cfg.Timeout = 30 * time.Second
	}

	return &Client{
		cfg: cfg,
		httpClient: &http.Client{
			Timeout: cfg.Timeout,
		},
	}, nil
}

// Connect establishes WebSocket connection for real-time updates.
func (c *Client) Connect(ctx context.Context) error {
	wsURL := c.cfg.ServerURL
	if len(wsURL) > 7 && wsURL[:7] == "http://" {
		wsURL = "ws://" + wsURL[7:]
	} else if len(wsURL) > 8 && wsURL[:8] == "https://" {
		wsURL = "wss://" + wsURL[8:]
	}

	c.wsClient = NewWSClient(wsURL+"/ws", c.cfg.AuthToken)
	return c.wsClient.Connect(ctx)
}

// Disconnect closes the WebSocket connection.
func (c *Client) Disconnect() error {
	if c.wsClient != nil {
		return c.wsClient.Close()
	}
	return nil
}

// Health checks the service health.
func (c *Client) Health(ctx context.Context) (*HealthResponse, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", c.cfg.ServerURL+"/api/v1/health", nil)
	if err != nil {
		return nil, err
	}
	c.setAuthHeader(req)

	var resp HealthResponse
	if err := c.doRequest(req, &resp); err != nil {
		return nil, err
	}
	return &resp, nil
}

func (c *Client) setAuthHeader(req *http.Request) {
	if c.cfg.AuthToken != "" {
		req.Header.Set("Authorization", "Bearer "+c.cfg.AuthToken)
	}
}

func (c *Client) doRequest(req *http.Request, v interface{}) error {
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return &APIError{StatusCode: resp.StatusCode}
	}

	return decodeJSON(resp.Body, v)
}

// HealthResponse represents the health check response.
type HealthResponse struct {
	Status  string `json:"status"`
	Version string `json:"version"`
}

// APIError represents an API error.
type APIError struct {
	StatusCode int
}

func (e *APIError) Error() string {
	return http.StatusText(e.StatusCode)
}

// Logs returns the Logs handler.
func (c *Client) Logs() *Logs {
	return NewLogs(c)
}

// Monitor returns the Monitor handler.
func (c *Client) Monitor() *Monitor {
	return NewMonitor(c)
}

// Stats returns the Stats handler.
func (c *Client) Stats() *Stats {
	return NewStats(c)
}

// Auth returns the Auth handler.
func (c *Client) Auth() *Auth {
	return NewAuth(c)
}
