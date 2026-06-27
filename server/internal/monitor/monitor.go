package monitor

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"regexp"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"github.com/sirupsen/logrus"

	"sentinelx-server/internal/models"
	"sentinelx-server/internal/storage"
	"sentinelx-server/internal/utils"
)

type DetectionRule struct {
	Name        string
	Pattern     string
	Severity    string
	Description string
}

type MonitorConfig struct {
	ListenPort    int
	TargetAddress string
	Protocol      string
	Rules         []DetectionRule
}

type FRPMonitor struct {
	config           MonitorConfig
	listener         net.Listener
	running          bool
	mu               sync.RWMutex
	logStorage       *storage.LogStorage
	bytesTotal       int64
	connectionsActive int64
	stopChan         chan struct{}
}

func NewFRPMonitor(cfg MonitorConfig, ls *storage.LogStorage) (*FRPMonitor, error) {
	if cfg.Protocol == "" {
		cfg.Protocol = "tcp"
	}
	if cfg.Rules == nil {
		cfg.Rules = []DetectionRule{}
	}

	return &FRPMonitor{
		config:     cfg,
		logStorage: ls,
		stopChan:   make(chan struct{}),
	}, nil
}

func (m *FRPMonitor) Start() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.running {
		return fmt.Errorf("monitor is already running")
	}

	listenAddr := ":" + strconv.Itoa(m.config.ListenPort)
	listener, err := net.Listen(m.config.Protocol, listenAddr)
	if err != nil {
		return fmt.Errorf("failed to listen on %s: %w", listenAddr, err)
	}

	m.listener = listener
	m.running = true
	m.stopChan = make(chan struct{})

	go m.acceptConnections()

	logrus.WithFields(logrus.Fields{
		"port":         m.config.ListenPort,
		"target":       m.config.TargetAddress,
		"protocol":     m.config.Protocol,
		"rules_count":  len(m.config.Rules),
	}).Info("FRP monitor started")

	return nil
}

func (m *FRPMonitor) Stop() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if !m.running {
		return fmt.Errorf("monitor is not running")
	}

	close(m.stopChan)

	if m.listener != nil {
		m.listener.Close()
	}

	m.running = false

	logrus.Info("FRP monitor stopped")

	return nil
}

func (m *FRPMonitor) IsRunning() bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.running
}

func (m *FRPMonitor) Stats() map[string]interface{} {
	m.mu.RLock()
	defer m.mu.RUnlock()

	return map[string]interface{}{
		"running":            m.running,
		"listen_port":        m.config.ListenPort,
		"target_address":     m.config.TargetAddress,
		"protocol":           m.config.Protocol,
		"rules_count":        len(m.config.Rules),
		"bytes_total":        atomic.LoadInt64(&m.bytesTotal),
		"connections_active": atomic.LoadInt64(&m.connectionsActive),
	}
}

func (m *FRPMonitor) acceptConnections() {
	for {
		select {
		case <-m.stopChan:
			return
		default:
		}

		conn, err := m.listener.Accept()
		if err != nil {
			select {
			case <-m.stopChan:
				return
			default:
			}
			logrus.WithError(err).Error("Failed to accept connection")
			continue
		}

		go m.handleConnection(conn)
	}
}

func (m *FRPMonitor) handleConnection(conn net.Conn) {
	atomic.AddInt64(&m.connectionsActive, 1)
	defer func() {
		atomic.AddInt64(&m.connectionsActive, -1)
		conn.Close()
	}()

	targetConn, err := net.Dial(m.config.Protocol, m.config.TargetAddress)
	if err != nil {
		logrus.WithError(err).WithField("target", m.config.TargetAddress).Error("Failed to connect to target")
		return
	}
	defer targetConn.Close()

	var totalBytes int64
	var wg sync.WaitGroup

	wg.Add(2)

	go func() {
		defer wg.Done()
		m.proxyData(conn, targetConn, "client_to_server", &totalBytes)
	}()

	go func() {
		defer wg.Done()
		m.proxyData(targetConn, conn, "server_to_client", &totalBytes)
	}()

	wg.Wait()

	atomic.AddInt64(&m.bytesTotal, totalBytes)

	logrus.WithFields(logrus.Fields{
		"remote_addr":  conn.RemoteAddr().String(),
		"bytes":        totalBytes,
	}).Debug("Connection closed")
}

func (m *FRPMonitor) proxyData(src, dst net.Conn, direction string, totalBytes *int64) {
	reader := bufio.NewReader(src)
	buf := make([]byte, 32*1024)

	for {
		select {
		case <-m.stopChan:
			return
		default:
		}

		n, err := reader.Read(buf)
		if n > 0 {
			atomic.AddInt64(totalBytes, int64(n))

			data := make([]byte, n)
			copy(data, buf[:n])

			m.detectAnomaly(data, direction)

			if _, writeErr := dst.Write(data); writeErr != nil {
				return
			}
		}

		if err != nil {
			if err != io.EOF {
				logrus.WithError(err).Debug("Proxy read error")
			}
			return
		}
	}
}

func (m *FRPMonitor) detectAnomaly(data []byte, direction string) {
	for _, rule := range m.config.Rules {
		re, err := regexp.Compile(rule.Pattern)
		if err != nil {
			logrus.WithError(err).WithField("rule", rule.Name).Warn("Invalid regex pattern")
			continue
		}

		if re.Match(data) {
			logrus.WithFields(logrus.Fields{
				"rule":      rule.Name,
				"severity":  rule.Severity,
				"direction": direction,
			}).Warn("Anomaly detected in traffic")

			m.createTrafficLog(data, rule.Name, rule.Severity)
		}
	}
}

func (m *FRPMonitor) createTrafficLog(data []byte, manipulationType string, severity string) {
	signature := utils.GenerateUUID()

	host, portStr, err := net.SplitHostPort(m.config.TargetAddress)
	if err != nil {
		host = m.config.TargetAddress
		portStr = "0"
	}
	port, _ := strconv.Atoi(portStr)

	trafficLog := models.TrafficLog{
		Timestamp:        time.Now(),
		EventID:          utils.GenerateUUID(),
		EventType:        "frp_traffic",
		AttackDomain:     "",
		TargetDomain:     host,
		TrafficBytes:     int64(len(data)),
		SourceIP:         "",
		SourcePort:       0,
		DestinationIP:    host,
		DestinationPort:  port,
		Protocol:         m.config.Protocol,
		ManipulationType: manipulationType,
		Severity:         severity,
		Confidence:       0.8,
		PacketSignature:  signature,
		EncryptedPayload: fmt.Sprintf("%x", data),
		Metadata: map[string]interface{}{
			"data_length": len(data),
			"monitor_port": m.config.ListenPort,
			"target":       m.config.TargetAddress,
		},
	}

	if m.logStorage != nil {
		if err := m.logStorage.StoreTrafficLog(trafficLog); err != nil {
			logrus.WithError(err).Error("Failed to store traffic log")
		}
	}
}
