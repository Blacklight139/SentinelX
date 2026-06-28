package client

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/gorilla/websocket"
)

// WSClient handles WebSocket connections.
type WSClient struct {
	url      string
	token    string
	conn     *websocket.Conn
	handler  func([]byte)
	done     chan struct{}
}

// NewWSClient creates a new WebSocket client.
func NewWSClient(url, token string) *WSClient {
	return &WSClient{
		url:   url,
		token: token,
		done:  make(chan struct{}),
	}
}

// Connect establishes a WebSocket connection.
func (w *WSClient) Connect(ctx context.Context) error {
	header := http.Header{}
	if w.token != "" {
		header.Set("Authorization", "Bearer "+w.token)
	}

	conn, _, err := websocket.DefaultDialer.DialContext(ctx, w.url, header)
	if err != nil {
		return err
	}
	w.conn = conn
	return nil
}

// Subscribe subscribes to a channel and calls handler with received data.
func (w *WSClient) Subscribe(ctx context.Context, sub *Subscription, handler func([]byte)) error {
	w.handler = handler

	data, err := json.Marshal(sub)
	if err != nil {
		return err
	}

	if err := w.conn.WriteMessage(websocket.TextMessage, data); err != nil {
		return err
	}

	go w.readLoop()
	return nil
}

func (w *WSClient) readLoop() {
	for {
		select {
		case <-w.done:
			return
		default:
			_, msg, err := w.conn.ReadMessage()
			if err != nil {
				return
			}
			if w.handler != nil {
				w.handler(msg)
			}
		}
	}
}

// Close closes the WebSocket connection.
func (w *WSClient) Close() error {
	close(w.done)
	if w.conn != nil {
		return w.conn.Close()
	}
	return nil
}

// Subscription represents a WebSocket subscription.
type Subscription struct {
	Type   string     `json:"type"`
	Filter interface{} `json:"filter,omitempty"`
}
