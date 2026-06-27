package server

import (
	"crypto/tls"
	"fmt"
	"log"
	"net/http"
	"os"
	"runtime/debug"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/sirupsen/logrus"
	"gopkg.in/yaml.v3"

	"sentinelx-server/internal/alert"
	"sentinelx-server/internal/api"
	"sentinelx-server/internal/crypto"
	"sentinelx-server/internal/middleware"
	"sentinelx-server/internal/monitor"
	"sentinelx-server/internal/safemap"
	"sentinelx-server/internal/storage"
	"sentinelx-server/internal/utils"
	"sentinelx-server/internal/ws"
)

type Config struct {
	Server struct {
		Address      string `yaml:"address"`
		LogDir       string `yaml:"log_dir"`
		DataDir      string `yaml:"data_dir"`
		MaxClients   int    `yaml:"max_clients"`
		ReadTimeout  int    `yaml:"read_timeout"`
		WriteTimeout int    `yaml:"write_timeout"`
		IdleTimeout  int    `yaml:"idle_timeout"`
	} `yaml:"server"`

	Security struct {
		RSAKeySize      int  `yaml:"rsa_key_size"`
		SessionTimeout  int  `yaml:"session_timeout"`
		MaxLoginAttempts int `yaml:"max_login_attempts"`
		EnableMTLS      bool `yaml:"enable_mtls"`
	} `yaml:"security"`

	Logging struct {
		Level         string `yaml:"level"`
		Format        string `yaml:"format"`
		RotationSize  int    `yaml:"rotation_size"`
		RetentionDays int    `yaml:"retention_days"`
	} `yaml:"logging"`

	Monitoring struct {
		EnableMetrics bool `yaml:"enable_metrics"`
		MetricsPort   int  `yaml:"metrics_port"`
		EnablePprof   bool `yaml:"enable_pprof"`
		PprofPort     int  `yaml:"pprof_port"`
	} `yaml:"monitoring"`

	Cache struct {
		Enabled bool `yaml:"enabled"`
		SizeMB  int  `yaml:"size_mb"`
		TTL     int  `yaml:"ttl_seconds"`
	} `yaml:"cache"`

	Database struct {
		Type     string `yaml:"type"`
		Host     string `yaml:"host"`
		Port     int    `yaml:"port"`
		Name     string `yaml:"name"`
		User     string `yaml:"user"`
		Password string `yaml:"password"`
	} `yaml:"database"`

	Auth struct {
		Tokens []string `yaml:"tokens"`
	} `yaml:"auth"`

	FRPMonitoring struct {
		Enabled        bool                      `yaml:"enabled"`
		MonitorPorts   []int                     `yaml:"monitor_ports"`
		DetectionRules []monitor.DetectionRule   `yaml:"detection_rules"`
	} `yaml:"frp_monitoring"`
}

var (
	ActiveConnections = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "sentinelx_connections_active",
		Help: "当前活跃连接数",
	})

	TotalConnections = promauto.NewCounter(prometheus.CounterOpts{
		Name: "sentinelx_connections_total",
		Help: "总连接数",
	})

	TrafficBytes = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "sentinelx_traffic_bytes_total",
		Help: "总流量字节数",
	}, []string{"type", "protocol"})

	SecurityEvents = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "sentinelx_security_events_total",
		Help: "安全事件总数",
	}, []string{"severity", "type"})

	RequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "sentinelx_request_duration_seconds",
		Help:    "请求处理时间",
		Buckets: prometheus.DefBuckets,
	}, []string{"endpoint", "method"})

	CacheHits = promauto.NewCounter(prometheus.CounterOpts{
		Name: "sentinelx_cache_hits_total",
		Help: "缓存命中次数",
	})

	CacheMisses = promauto.NewCounter(prometheus.CounterOpts{
		Name: "sentinelx_cache_misses_total",
		Help: "缓存未命中次数",
	})
)

type Server struct {
	config         *Config
	logStorage     *storage.LogStorage
	encryption     *crypto.EncryptionSystem
	wsHandler      *ws.WebSocketHandler
	frpMonitors    *safemap.SafeMap[string, *monitor.FRPMonitor]
	alertEngine    *alert.AlertEngine
	apiHandler     *api.APIHandler
	authMiddleware *middleware.AuthMiddleware
	httpServer     *http.Server
	logger         *logrus.Logger
	metricsPort    int
	pprofPort      int
}

func NewServer(cfg *Config) (*Server, error) {
	logger := logrus.New()
	logger.SetFormatter(&logrus.JSONFormatter{
		TimestampFormat: "2006-01-02 15:04:05",
	})

	level, err := logrus.ParseLevel(cfg.Logging.Level)
	if err != nil {
		level = logrus.InfoLevel
	}
	logger.SetLevel(level)

	es, err := crypto.NewEncryptionSystem()
	if err != nil {
		return nil, fmt.Errorf("初始化加密系统失败: %w", err)
	}

	ls, err := storage.NewLogStorage(cfg.Server.LogDir, es)
	if err != nil {
		return nil, fmt.Errorf("初始化日志存储失败: %w", err)
	}

	frpMonitors := safemap.NewSafeMap[string, *monitor.FRPMonitor]()
	wsHandler := ws.NewWebSocketHandler(ls)
	apiHandler := api.NewAPIHandler(ls, frpMonitors, wsHandler)
	alertEngine := alert.NewAlertEngine(ls)

	for i, rule := range cfg.FRPMonitoring.DetectionRules {
		alertRule := alert.AlertRule{
			ID:          fmt.Sprintf("rule_%d", i),
			Name:        rule.Name,
			Pattern:     rule.Pattern,
			Severity:    rule.Severity,
			Description: rule.Description,
			Enabled:     true,
		}
		if err := alertEngine.AddRule(alertRule); err != nil {
			logger.WithError(err).WithField("rule", rule.Name).Warn("添加告警规则失败")
		}
	}

	authCfg := middleware.AuthConfig{
		Tokens:        cfg.Auth.Tokens,
		ExcludedPaths: []string{"/api/v1/health"},
	}
	authMiddleware := middleware.NewAuthMiddleware(authCfg)

	return &Server{
		config:         cfg,
		logStorage:     ls,
		encryption:     es,
		wsHandler:      wsHandler,
		frpMonitors:    frpMonitors,
		alertEngine:    alertEngine,
		apiHandler:     apiHandler,
		authMiddleware: authMiddleware,
		logger:         logger,
		metricsPort:    cfg.Monitoring.MetricsPort,
		pprofPort:      cfg.Monitoring.PprofPort,
	}, nil
}

func (s *Server) Start() error {
	if s.config.Monitoring.EnableMetrics {
		go s.startMetricsServer()
	}

	if s.config.Monitoring.EnablePprof {
		go s.startPprofServer()
	}

	mux := http.NewServeMux()

	mux.HandleFunc("/ws", s.wsHandler.HandleConnection)
	mux.HandleFunc("/api/v1/health", s.apiHandler.HandleHealthCheck)
	mux.HandleFunc("/api/v1/logs", s.apiHandler.HandleLogs)
	mux.HandleFunc("/api/v1/stats", s.apiHandler.HandleStats)
	mux.HandleFunc("/api/v1/monitor/start", s.apiHandler.HandleStartMonitor)
	mux.HandleFunc("/api/v1/monitor/stop", s.apiHandler.HandleStopMonitor)

	handler := s.withLogging(s.withMetrics(s.withRecovery(s.authMiddleware.Middleware(mux))))

	cert, err := tls.LoadX509KeyPair("keys/server.crt", "keys/server.key")
	if err != nil {
		return fmt.Errorf("加载TLS证书失败: %w", err)
	}

	tlsConfig := &tls.Config{
		Certificates: []tls.Certificate{cert},
		MinVersion:   tls.VersionTLS13,
		CipherSuites: []uint16{
			tls.TLS_AES_128_GCM_SHA256,
			tls.TLS_AES_256_GCM_SHA384,
			tls.TLS_CHACHA20_POLY1305_SHA256,
		},
		CurvePreferences: []tls.CurveID{
			tls.X25519,
			tls.CurveP256,
			tls.CurveP384,
		},
		PreferServerCipherSuites: true,
	}

	if s.config.Security.EnableMTLS {
		tlsConfig.ClientAuth = tls.RequireAndVerifyClientCert
	}

	s.httpServer = &http.Server{
		Addr:         s.config.Server.Address,
		Handler:      handler,
		TLSConfig:    tlsConfig,
		ReadTimeout:  time.Duration(s.config.Server.ReadTimeout) * time.Second,
		WriteTimeout: time.Duration(s.config.Server.WriteTimeout) * time.Second,
		IdleTimeout:  time.Duration(s.config.Server.IdleTimeout) * time.Second,
		ErrorLog:     log.New(s.logger.Writer(), "", 0),
	}

	s.logger.WithFields(logrus.Fields{
		"address": s.config.Server.Address,
		"tls":     "enabled",
		"metrics": s.config.Monitoring.EnableMetrics,
	}).Info("SentinelX 服务端启动")

	return s.httpServer.ListenAndServeTLS("", "")
}

func (s *Server) startMetricsServer() {
	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())

	server := &http.Server{
		Addr:    fmt.Sprintf(":%d", s.metricsPort),
		Handler: mux,
	}

	s.logger.WithField("port", s.metricsPort).Info("启动指标服务器")

	if err := server.ListenAndServe(); err != nil {
		s.logger.WithError(err).Error("指标服务器启动失败")
	}
}

func (s *Server) startPprofServer() {
	mux := http.NewServeMux()
	mux.HandleFunc("/debug/pprof/", func(w http.ResponseWriter, r *http.Request) {
		http.DefaultServeMux.ServeHTTP(w, r)
	})

	server := &http.Server{
		Addr:    fmt.Sprintf(":%d", s.pprofPort),
		Handler: mux,
	}

	s.logger.WithField("port", s.pprofPort).Info("启动性能分析服务器")

	if err := server.ListenAndServe(); err != nil {
		s.logger.WithError(err).Error("性能分析服务器启动失败")
	}
}

func (s *Server) withLogging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		rw := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}

		next.ServeHTTP(rw, r)

		duration := time.Since(start)

		s.logger.WithFields(logrus.Fields{
			"method":      r.Method,
			"path":        r.URL.Path,
			"remote_addr": r.RemoteAddr,
			"user_agent":  r.UserAgent(),
			"status":      rw.statusCode,
			"duration":    duration.Seconds(),
		}).Info("HTTP请求")
	})
}

func (s *Server) withMetrics(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		next.ServeHTTP(w, r)

		duration := time.Since(start)
		RequestDuration.WithLabelValues(r.URL.Path, r.Method).Observe(duration.Seconds())
	})
}

func (s *Server) withRecovery(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if err := recover(); err != nil {
				s.logger.WithFields(logrus.Fields{
					"error": err,
					"stack": utils.GetStack(),
				}).Error("HTTP处理器崩溃")

				http.Error(w, "内部服务器错误", http.StatusInternalServerError)
			}
		}()

		next.ServeHTTP(w, r)
	})
}

type responseWriter struct {
	http.ResponseWriter
	statusCode int
	written    int64
}

func (rw *responseWriter) WriteHeader(statusCode int) {
	rw.statusCode = statusCode
	rw.ResponseWriter.WriteHeader(statusCode)
}

func (rw *responseWriter) Write(b []byte) (int, error) {
	n, err := rw.ResponseWriter.Write(b)
	rw.written += int64(n)
	return n, err
}

func LoadConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var config Config
	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, err
	}

	if config.Server.ReadTimeout == 0 {
		config.Server.ReadTimeout = 30
	}
	if config.Server.WriteTimeout == 0 {
		config.Server.WriteTimeout = 30
	}
	if config.Server.IdleTimeout == 0 {
		config.Server.IdleTimeout = 120
	}
	if config.Logging.Format == "" {
		config.Logging.Format = "json"
	}
	if config.Cache.TTL == 0 {
		config.Cache.TTL = 3600
	}

	return &config, nil
}

func BuildInfo() string {
	info, ok := debug.ReadBuildInfo()
	if !ok {
		return "unknown"
	}

	var revision, timeStr string
	for _, setting := range info.Settings {
		switch setting.Key {
		case "vcs.revision":
			revision = setting.Value
		case "vcs.time":
			timeStr = setting.Value
		}
	}

	if len(revision) >= 8 {
		return fmt.Sprintf("%s @ %s", revision[:8], timeStr)
	}
	return fmt.Sprintf("%s @ %s", revision, timeStr)
}
