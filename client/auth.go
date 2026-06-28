package client

import (
	"context"
	"net/http"
)

// Auth handles authentication operations.
type Auth struct {
	client *Client
}

// NewAuth creates a new Auth handler.
func NewAuth(client *Client) *Auth {
	return &Auth{client: client}
}

// ValidateToken validates the current auth token.
func (a *Auth) ValidateToken(ctx context.Context) (*ValidateTokenResponse, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", a.client.cfg.ServerURL+"/api/v1/auth/validate", nil)
	if err != nil {
		return nil, err
	}
	a.client.setAuthHeader(req)

	var resp ValidateTokenResponse
	if err := a.client.doRequest(req, &resp); err != nil {
		return nil, err
	}
	return &resp, nil
}

// ValidateTokenResponse represents the token validation response.
type ValidateTokenResponse struct {
	Valid    bool   `json:"valid"`
	UserID   string `json:"user_id"`
	Username string `json:"username"`
}
