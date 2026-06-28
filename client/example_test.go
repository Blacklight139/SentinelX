package client

import (
	"context"
	"time"
)

func Example() {
	cfg := &Config{
		ServerURL: "http://localhost:8080",
		AuthToken: "your-auth-token",
		Timeout:   30 * time.Second,
	}

	client, err := NewClient(cfg)
	if err != nil {
		// handle error
	}

	ctx := context.Background()

	// Health check
	health, err := client.Health(ctx)
	if err != nil {
		// handle error
	}

	// List logs
	logs, err := client.Logs().List(ctx, &LogFilter{
		Levels: []string{"error", "warn"},
		Limit:  100,
	})
	if err != nil {
		// handle error
	}

	// Get single log
	log, err := client.Logs().Get(ctx, "log-id-123")
	if err != nil {
		// handle error
	}

	// Stream logs in real-time
	err = client.Logs().Stream(ctx, nil, func(log *Log) {
		// handle streamed log
	})

	// Monitor status
	status, err := client.Monitor().Status(ctx)
	if err != nil {
		// handle error
	}

	// Start monitoring
	resp, err := client.Monitor().Start(ctx, "target-123")
	if err != nil {
		// handle error
	}

	// Stop monitoring
	_, err = client.Monitor().Stop(ctx)

	// Get stats
	stats, err := client.Stats().Get(ctx)
	if err != nil {
		// handle error
	}

	// Connect for real-time updates
	err = client.Connect(ctx)
	if err != nil {
		// handle error
	}
	defer client.Disconnect()

	_ = health
	_ = logs
	_ = log
	_ = status
	_ = resp
	_ = stats
}
