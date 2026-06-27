package models

import "time"

type TrafficLog struct {
	Timestamp         time.Time              `json:"timestamp"`
	EventID           string                 `json:"event_id"`
	EventType         string                 `json:"event_type"`
	AttackDomain      string                 `json:"attack_domain"`
	TargetDomain      string                 `json:"target_domain"`
	TrafficBytes      int64                  `json:"traffic_bytes"`
	SourceIP          string                 `json:"source_ip"`
	SourcePort        int                    `json:"source_port"`
	DestinationIP     string                 `json:"destination_ip"`
	DestinationPort   int                    `json:"destination_port"`
	Protocol          string                 `json:"protocol"`
	ManipulationType  string                 `json:"manipulation_type"`
	Severity          string                 `json:"severity"`
	Confidence        float64                `json:"confidence"`
	PacketSignature   string                 `json:"packet_signature"`
	EncryptedPayload  string                 `json:"encrypted_payload"`
	Metadata          map[string]interface{} `json:"metadata"`
}

type AccessLog struct {
	Timestamp       time.Time `json:"timestamp"`
	LogID           string    `json:"log_id"`
	ClientID        string    `json:"client_id"`
	ClientVersion   string    `json:"client_version"`
	Action          string    `json:"action"`
	Resource        string    `json:"resource"`
	Status          string    `json:"status"`
	DownloadedFiles []string  `json:"downloaded_files"`
	DownloadToken   string    `json:"download_token"`
	ClientIP        string    `json:"client_ip"`
	UserAgent       string    `json:"user_agent"`
	ProcessingTime  int64     `json:"processing_time_ms"`
	ErrorMessage    string    `json:"error_message,omitempty"`
}
