package main

import (
    "crypto/rsa"
    "crypto/rand"
    "crypto/sha256"
    "crypto/tls"
    "crypto/x509"
    "encoding/json"
    "encoding/pem"
    "flag"
    "fmt"
    "io"
    "log"
    "net"
    "net/http"
    "os"
    "path/filepath"
    "sync"
    "time"
    
    "github.com/gorilla/websocket"
    "gopkg.in/yaml.v3"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
    "github.com/prometheus/client_golang/prometheus/promhttp"
    "github.com/sirupsen/logrus"
)

// 添加 Go 1.25 的新特性支持
// 使用泛型改进数据结构
type SafeMap[K comparable, V any] struct {
    mu   sync.RWMutex
    data map[K]V
}

func NewSafeMap[K comparable, V any]() *SafeMap[K, V] {
    return &SafeMap[K, V]{
        data: make(map[K]V),
    }
}

func (m *SafeMap[K, V]) Set(key K, value V) {
    m.mu.Lock()
    defer m.mu.Unlock()
    m.data[key] = value
}

func (m *SafeMap[K, V]) Get(key K) (V, bool) {
    m.mu.RLock()
    defer m.mu.RUnlock()
    val, ok := m.data[key]
    return val, ok
}

func (m *SafeMap[K, V]) Delete(key K) {
    m.mu.Lock()
    defer m.mu.Unlock()
    delete(m.data, key)
}

// ==================== 配置结构 ====================
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
        RSAKeySize      int `yaml:"rsa_key_size"`
        SessionTimeout  int `yaml:"session_timeout"`
        MaxLoginAttempts int `yaml:"max_login_attempts"`
        EnableMTLS      bool `yaml:"enable_mtls"`
    } `yaml:"security"`
    
    Logging struct {
        Level        string `yaml:"level"`
        Format       string `yaml:"format"`
        RotationSize int    `yaml:"rotation_size"`
        RetentionDays int   `yaml:"retention_days"`
    } `yaml:"logging"`
    
    Monitoring struct {
        EnableMetrics bool   `yaml:"enable_metrics"`
        MetricsPort   int    `yaml:"metrics_port"`
        EnablePprof   bool   `yaml:"enable_pprof"`
        PprofPort     int    `yaml:"pprof_port"`
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
}

// ==================== 使用泛型改进的缓存系统 ====================
type Cache[K comparable, V any] struct {
    mu       sync.RWMutex
    data     map[K]cacheEntry[V]
    capacity int
}

type cacheEntry[V any] struct {
    value     V
    expiresAt time.Time
}

func NewCache[K comparable, V any](capacity int) *Cache[K, V] {
    return &Cache[K, V]{
        data:     make(map[K]cacheEntry[V]),
        capacity: capacity,
    }
}

func (c *Cache[K, V]) Set(key K, value V, ttl time.Duration) {
    c.mu.Lock()
    defer c.mu.Unlock()
    
    // 清理过期条目
    c.cleanup()
    
    // 检查容量
    if len(c.data) >= c.capacity {
        c.evict()
    }
    
    c.data[key] = cacheEntry[V]{
        value:     value,
        expiresAt: time.Now().Add(ttl),
    }
}

func (c *Cache[K, V]) Get(key K) (V, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    
    entry, ok := c.data[key]
    if !ok {
        var zero V
        return zero, false
    }
    
    if time.Now().After(entry.expiresAt) {
        var zero V
        return zero, false
    }
    
    return entry.value, true
}

func (c *Cache[K, V]) cleanup() {
    now := time.Now()
    for key, entry := range c.data {
        if now.After(entry.expiresAt) {
            delete(c.data, key)
        }
    }
}

func (c *Cache[K, V]) evict() {
    // 简单的LRU策略：删除第一个条目
    for key := range c.data {
        delete(c.data, key)
        break
    }
}

// ==================== 数据结构 ====================
type TrafficLog struct {
    Timestamp         time.Time `json:"timestamp"`
    EventID           string    `json:"event_id"`
    EventType         string    `json:"event_type"`
    AttackDomain      string    `json:"attack_domain"`
    TargetDomain      string    `json:"target_domain"`
    TrafficBytes      int64     `json:"traffic_bytes"`
    SourceIP          string    `json:"source_ip"`
    SourcePort        int       `json:"source_port"`
    DestinationIP     string    `json:"destination_ip"`
    DestinationPort   int       `json:"destination_port"`
    Protocol          string    `json:"protocol"`
    ManipulationType  string    `json:"manipulation_type"`
    Severity          string    `json:"severity"`
    Confidence        float64   `json:"confidence"`
    PacketSignature   string    `json:"packet_signature"`
    EncryptedPayload  string    `json:"encrypted_payload"`
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

// ==================== 加密系统（使用 Go 1.25 改进） ====================
type EncryptionSystem struct {
    commPrivateKey    *rsa.PrivateKey
    commPublicKey     *rsa.PublicKey
    accessPrivateKey  *rsa.PrivateKey
    accessPublicKey   *rsa.PublicKey
    keyCache          *Cache[string, []byte]
    keyVersion        string
    keyMutex          sync.RWMutex
}

func NewEncryptionSystem() (*EncryptionSystem, error) {
    es := &EncryptionSystem{
        keyCache:   NewCache[string, []byte](100),
        keyVersion: fmt.Sprintf("v1_%d", time.Now().Unix()),
    }
    
    // 加载或生成密钥
    if err := es.loadOrGenerateKeys(); err != nil {
        return nil, fmt.Errorf("初始化加密系统失败: %w", err)
    }
    
    return es, nil
}

func (es *EncryptionSystem) loadOrGenerateKeys() error {
    // 优先尝试从文件加载
    if err := es.loadKeysFromFiles(); err != nil {
        logrus.Warnf("从文件加载密钥失败: %v，将生成新密钥", err)
        return es.generateKeys()
    }
    return nil
}

func (es *EncryptionSystem) loadKeysFromFiles() error {
    // 实现密钥加载逻辑
    // ...
    return nil
}

func (es *EncryptionSystem) generateKeys() error {
    logrus.Info("生成新的RSA密钥对...")
    
    // 生成通信密钥
    commKey, err := rsa.GenerateKey(rand.Reader, 2048)
    if err != nil {
        return fmt.Errorf("生成通信密钥失败: %w", err)
    }
    es.commPrivateKey = commKey
    es.commPublicKey = &commKey.PublicKey
    
    // 生成访问日志密钥
    accessKey, err := rsa.GenerateKey(rand.Reader, 2048)
    if err != nil {
        return fmt.Errorf("生成访问日志密钥失败: %w", err)
    }
    es.accessPrivateKey = accessKey
    es.accessPublicKey = &accessKey.PublicKey
    
    // 保存密钥到文件
    if err := es.saveKeysToFiles(); err != nil {
        logrus.Warnf("保存密钥到文件失败: %v", err)
    }
    
    return nil
}

func (es *EncryptionSystem) saveKeysToFiles() error {
    // 创建目录
    if err := os.MkdirAll("keys", 0700); err != nil {
        return err
    }
    
    // 保存通信私钥
    commPrivatePEM := &pem.Block{
        Type:  "RSA PRIVATE KEY",
        Bytes: x509.MarshalPKCS1PrivateKey(es.commPrivateKey),
    }
    if err := os.WriteFile("keys/communication_private.pem", 
        pem.EncodeToMemory(commPrivatePEM), 0600); err != nil {
        return err
    }
    
    // 保存通信公钥
    commPublicPEM := &pem.Block{
        Type:  "RSA PUBLIC KEY",
        Bytes: x509.MarshalPKCS1PublicKey(es.commPublicKey),
    }
    if err := os.WriteFile("keys/communication_public.pem",
        pem.EncodeToMemory(commPublicPEM), 0644); err != nil {
        return err
    }
    
    // 保存访问日志密钥
    accessPrivatePEM := &pem.Block{
        Type:  "RSA PRIVATE KEY",
        Bytes: x509.MarshalPKCS1PrivateKey(es.accessPrivateKey),
    }
    if err := os.WriteFile("keys/access_private.pem",
        pem.EncodeToMemory(accessPrivatePEM), 0600); err != nil {
        return err
    }
    
    accessPublicPEM := &pem.Block{
        Type:  "RSA PUBLIC KEY",
        Bytes: x509.MarshalPKCS1PublicKey(es.accessPublicKey),
    }
    if err := os.WriteFile("keys/access_public.pem",
        pem.EncodeToMemory(accessPublicPEM), 0644); err != nil {
        return err
    }
    
    logrus.Info("密钥已保存到 keys/ 目录")
    return nil
}

// 使用 Go 1.25 的改进加密函数
func (es *EncryptionSystem) EncryptWithKey(data []byte, publicKey *rsa.PublicKey) ([]byte, error) {
    hash := sha256.New()
    label := []byte(es.keyVersion)
    
    // 使用 OAEP 加密
    encrypted, err := rsa.EncryptOAEP(hash, rand.Reader, publicKey, data, label)
    if err != nil {
        return nil, fmt.Errorf("RSA加密失败: %w", err)
    }
    
    return encrypted, nil
}

func (es *EncryptionSystem) DecryptWithKey(encrypted []byte, privateKey *rsa.PrivateKey) ([]byte, error) {
    hash := sha256.New()
    label := []byte(es.keyVersion)
    
    // 使用 OAEP 解密
    decrypted, err := rsa.DecryptOAEP(hash, rand.Reader, privateKey, encrypted, label)
    if err != nil {
        return nil, fmt.Errorf("RSA解密失败: %w", err)
    }
    
    return decrypted, nil
}

// ==================== 监控指标（使用 Prometheus） ====================
var (
    // 连接相关指标
    activeConnections = promauto.NewGauge(prometheus.GaugeOpts{
        Name: "sentinelx_connections_active",
        Help: "当前活跃连接数",
    })
    
    totalConnections = promauto.NewCounter(prometheus.CounterOpts{
        Name: "sentinelx_connections_total",
        Help: "总连接数",
    })
    
    // 流量相关指标
    trafficBytes = promauto.NewCounterVec(prometheus.CounterOpts{
        Name: "sentinelx_traffic_bytes_total",
        Help: "总流量字节数",
    }, []string{"type", "protocol"})
    
    // 安全事件指标
    securityEvents = promauto.NewCounterVec(prometheus.CounterOpts{
        Name: "sentinelx_security_events_total",
        Help: "安全事件总数",
    }, []string{"severity", "type"})
    
    // 性能指标
    requestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
        Name:    "sentinelx_request_duration_seconds",
        Help:    "请求处理时间",
        Buckets: prometheus.DefBuckets,
    }, []string{"endpoint", "method"})
    
    // 缓存指标
    cacheHits = promauto.NewCounter(prometheus.CounterOpts{
        Name: "sentinelx_cache_hits_total",
        Help: "缓存命中次数",
    })
    
    cacheMisses = promauto.NewCounter(prometheus.CounterOpts{
        Name: "sentinelx_cache_misses_total",
        Help: "缓存未命中次数",
    })
)

// ==================== 日志存储系统 ====================
type LogStorage struct {
    logDir       string
    es           *EncryptionSystem
    logCache     *Cache[string, []byte]
    accessTokens *SafeMap[string, bool]
    metrics      struct {
        logsStored      prometheus.Counter
        storageSize     prometheus.Gauge
        encryptionTime  prometheus.Histogram
    }
}

func NewLogStorage(logDir string, es *EncryptionSystem) (*LogStorage, error) {
    // 创建日志目录
    if err := os.MkdirAll(logDir, 0700); err != nil {
        return nil, fmt.Errorf("创建日志目录失败: %w", err)
    }
    
    ls := &LogStorage{
        logDir:       logDir,
        es:           es,
        logCache:     NewCache[string, []byte](500),
        accessTokens: NewSafeMap[string, bool](),
    }
    
    // 初始化指标
    ls.metrics.logsStored = promauto.NewCounter(prometheus.CounterOpts{
        Name: "sentinelx_logs_stored_total",
        Help: "存储的日志总数",
    })
    
    ls.metrics.storageSize = promauto.NewGauge(prometheus.GaugeOpts{
        Name: "sentinelx_storage_size_bytes",
        Help: "日志存储大小",
    })
    
    ls.metrics.encryptionTime = promauto.NewHistogram(prometheus.HistogramOpts{
        Name:    "sentinelx_encryption_time_seconds",
        Help:    "加密耗时",
        Buckets: prometheus.DefBuckets,
    })
    
    // 启动定期清理任务
    go ls.startCleanupTask()
    
    return ls, nil
}

func (ls *LogStorage) startCleanupTask() {
    ticker := time.NewTicker(1 * time.Hour)
    defer ticker.Stop()
    
    for range ticker.C {
        ls.cleanupExpiredTokens()
        ls.updateStorageMetrics()
    }
}

func (ls *LogStorage) cleanupExpiredTokens() {
    // 清理过期的访问令牌
    // 实现逻辑...
}

func (ls *LogStorage) updateStorageMetrics() {
    // 更新存储指标
    var totalSize int64
    filepath.Walk(ls.logDir, func(path string, info os.FileInfo, err error) error {
        if err != nil {
            return err
        }
        if !info.IsDir() {
            totalSize += info.Size()
        }
        return nil
    })
    
    ls.metrics.storageSize.Set(float64(totalSize))
}

func (ls *LogStorage) StoreTrafficLog(log TrafficLog) error {
    start := time.Now()
    defer func() {
        ls.metrics.encryptionTime.Observe(time.Since(start).Seconds())
    }()
    
    // 生成事件ID
    if log.EventID == "" {
        log.EventID = generateUUID()
    }
    
    // 序列化日志
    data, err := json.Marshal(log)
    if err != nil {
        return fmt.Errorf("序列化日志失败: %w", err)
    }
    
    // 加密数据
    encryptedData, err := ls.es.EncryptWithKey(data, ls.es.commPublicKey)
    if err != nil {
        return fmt.Errorf("加密日志失败: %w", err)
    }
    
    // 生成文件名
    filename := fmt.Sprintf("traffic_%s_%s.enc",
        time.Now().Format("20060102_150405"),
        log.PacketSignature[:8],
    )
    
    // 写入文件
    filePath := filepath.Join(ls.logDir, filename)
    if err := os.WriteFile(filePath, encryptedData, 0600); err != nil {
        return fmt.Errorf("写入日志文件失败: %w", err)
    }
    
    // 更新指标
    ls.metrics.logsStored.Inc()
    trafficBytes.WithLabelValues("encrypted", "tcp").Add(float64(len(encryptedData)))
    
    // 缓存最近日志
    ls.logCache.Set(log.EventID, encryptedData, 24*time.Hour)
    
    logrus.WithFields(logrus.Fields{
        "event_id":   log.EventID,
        "file":       filename,
        "size_bytes": len(encryptedData),
    }).Info("已存储流量日志")
    
    return nil
}

// ==================== 主服务器结构 ====================
type Server struct {
    config      *Config
    logStorage  *LogStorage
    encryption  *EncryptionSystem
    wsHandler   *WebSocketHandler
    frpMonitors *SafeMap[string, *FRPMonitor]
    httpServer  *http.Server
    logger      *logrus.Logger
    metricsPort int
    pprofPort   int
}

func NewServer(cfg *Config) (*Server, error) {
    // 配置日志
    logger := logrus.New()
    logger.SetFormatter(&logrus.JSONFormatter{
        TimestampFormat: "2006-01-02 15:04:05",
    })
    
    level, err := logrus.ParseLevel(cfg.Logging.Level)
    if err != nil {
        level = logrus.InfoLevel
    }
    logger.SetLevel(level)
    
    // 初始化加密系统
    es, err := NewEncryptionSystem()
    if err != nil {
        return nil, fmt.Errorf("初始化加密系统失败: %w", err)
    }
    
    // 初始化日志存储
    ls, err := NewLogStorage(cfg.Server.LogDir, es)
    if err != nil {
        return nil, fmt.Errorf("初始化日志存储失败: %w", err)
    }
    
    return &Server{
        config:      cfg,
        logStorage:  ls,
        encryption:  es,
        wsHandler:   NewWebSocketHandler(ls),
        frpMonitors: NewSafeMap[string, *FRPMonitor](),
        logger:      logger,
        metricsPort: cfg.Monitoring.MetricsPort,
        pprofPort:   cfg.Monitoring.PprofPort,
    }, nil
}

func (s *Server) Start() error {
    // 启动指标服务器
    if s.config.Monitoring.EnableMetrics {
        go s.startMetricsServer()
    }
    
    // 启动性能分析服务器
    if s.config.Monitoring.EnablePprof {
        go s.startPprofServer()
    }
    
    // 创建路由器
    mux := http.NewServeMux()
    
    // 注册路由
    mux.HandleFunc("/ws", s.wsHandler.HandleConnection)
    mux.HandleFunc("/api/v1/logs", s.handleLogsAPI)
    mux.HandleFunc("/api/v1/stats", s.handleStatsAPI)
    mux.HandleFunc("/api/v1/monitor/start", s.handleStartMonitor)
    mux.HandleFunc("/api/v1/monitor/stop", s.handleStopMonitor)
    mux.HandleFunc("/api/v1/health", s.handleHealthCheck)
    
    // 中间件链
    handler := s.withLogging(s.withMetrics(s.withRecovery(mux)))
    
    // 加载TLS证书
    cert, err := tls.LoadX509KeyPair("keys/server.crt", "keys/server.key")
    if err != nil {
        return fmt.Errorf("加载TLS证书失败: %w", err)
    }
    
    // 配置TLS（使用Go 1.25推荐的配置）
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
    
    // 创建HTTP服务器
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

// ==================== 中间件 ====================
func (s *Server) withLogging(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        
        // 创建自定义的ResponseWriter以捕获状态码
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
        requestDuration.WithLabelValues(r.URL.Path, r.Method).Observe(duration.Seconds())
    })
}

func (s *Server) withRecovery(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        defer func() {
            if err := recover(); err != nil {
                s.logger.WithFields(logrus.Fields{
                    "error": err,
                    "stack": getStack(),
                }).Error("HTTP处理器崩溃")
                
                http.Error(w, "内部服务器错误", http.StatusInternalServerError)
            }
        }()
        
        next.ServeHTTP(w, r)
    })
}

// ==================== 工具函数 ====================
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

func generateUUID() string {
    b := make([]byte, 16)
    rand.Read(b)
    b[6] = (b[6] & 0x0f) | 0x40
    b[8] = (b[8] & 0x3f) | 0x80
    return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:16])
}

func getStack() string {
    buf := make([]byte, 4096)
    n := runtime.Stack(buf, false)
    return string(buf[:n])
}

// ==================== 主函数 ====================
func main() {
    var (
        configPath = flag.String("config", "config.yaml", "配置文件路径")
        genKeys    = flag.Bool("generate-keys", false, "生成新的密钥对")
        version    = flag.Bool("version", false, "显示版本信息")
        logLevel   = flag.String("log-level", "", "日志级别(debug, info, warn, error)")
    )
    flag.Parse()
    
    // 显示版本
    if *version {
        fmt.Printf("SentinelX v2.0.0 (Go %s)\n", runtime.Version())
        fmt.Printf("Build: %s\n", buildInfo())
        return
    }
    
    // 生成密钥
    if *genKeys {
        es, err := NewEncryptionSystem()
        if err != nil {
            log.Fatalf("生成密钥失败: %v", err)
        }
        log.Println("密钥已生成到 keys/ 目录")
        return
    }
    
    // 加载配置
    config, err := loadConfig(*configPath)
    if err != nil {
        log.Fatalf("加载配置失败: %v", err)
    }
    
    // 覆盖日志级别
    if *logLevel != "" {
        config.Logging.Level = *logLevel
    }
    
    // 创建必要的目录
    if err := os.MkdirAll(config.Server.LogDir, 0700); err != nil {
        log.Fatalf("创建日志目录失败: %v", err)
    }
    if err := os.MkdirAll(config.Server.DataDir, 0700); err != nil {
        log.Fatalf("创建数据目录失败: %v", err)
    }
    if err := os.MkdirAll("keys", 0700); err != nil {
        log.Fatalf("创建密钥目录失败: %v", err)
    }
    
    // 创建服务器
    server, err := NewServer(config)
    if err != nil {
        log.Fatalf("创建服务器失败: %v", err)
    }
    
    // 启动服务器
    if err := server.Start(); err != nil && err != http.ErrServerClosed {
        log.Fatalf("服务器启动失败: %v", err)
    }
}

func loadConfig(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }
    
    var config Config
    if err := yaml.Unmarshal(data, &config); err != nil {
        return nil, err
    }
    
    // 设置默认值
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

func buildInfo() string {
    info, ok := debug.ReadBuildInfo()
    if !ok {
        return "unknown"
    }
    
    var revision, time string
    for _, setting := range info.Settings {
        switch setting.Key {
        case "vcs.revision":
            revision = setting.Value
        case "vcs.time":
            time = setting.Value
        }
    }
    
    return fmt.Sprintf("%s @ %s", revision[:8], time)
}