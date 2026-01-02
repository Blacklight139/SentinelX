package main

import (
    "crypto/rsa"
    "crypto/sha256"
    "crypto/tls"
    "encoding/json"
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
)

// ==================== 配置结构 ====================
type Config struct {
    Server struct {
        Address      string `yaml:"address"`
        LogDir       string `yaml:"log_dir"`
        DataDir      string `yaml:"data_dir"`
        MaxClients   int    `yaml:"max_clients"`
    } `yaml:"server"`
    
    Security struct {
        RSAKeySize      int `yaml:"rsa_key_size"`
        SessionTimeout  int `yaml:"session_timeout"`
        MaxLoginAttempts int `yaml:"max_login_attempts"`
    } `yaml:"security"`
    
    Logging struct {
        Level        string `yaml:"level"`
        RotationSize int    `yaml:"rotation_size"`
        RetentionDays int   `yaml:"retention_days"`
    } `yaml:"logging"`
    
    Monitoring struct {
        EnableMetrics bool   `yaml:"enable_metrics"`
        MetricsPort   int    `yaml:"metrics_port"`
    } `yaml:"monitoring"`
}

// ==================== 数据结构 ====================
type TrafficLog struct {
    Timestamp         time.Time `json:"timestamp"`
    EventType         string    `json:"event_type"`
    AttackDomain      string    `json:"attack_domain"`
    TargetDomain      string    `json:"target_domain"`
    TrafficBytes      int64     `json:"traffic_bytes"`
    SourceIP          string    `json:"source_ip"`
    ManipulationType  string    `json:"manipulation_type"`
    Severity          string    `json:"severity"`
    PacketSignature   string    `json:"packet_signature"`
    EncryptedPayload  string    `json:"encrypted_payload"`
}

type AccessLog struct {
    Timestamp       time.Time `json:"timestamp"`
    ClientID        string    `json:"client_id"`
    Action          string    `json:"action"`
    DownloadedFiles []string  `json:"downloaded_files"`
    DownloadToken   string    `json:"download_token"`
    ClientIP        string    `json:"client_ip"`
    UserAgent       string    `json:"user_agent"`
}

// ==================== 加密系统 ====================
type EncryptionSystem struct {
    commPrivateKey    *rsa.PrivateKey
    commPublicKey     *rsa.PublicKey
    accessPrivateKey  *rsa.PrivateKey
    accessPublicKey   *rsa.PublicKey
    keyMutex          sync.RWMutex
}

func NewEncryptionSystem() (*EncryptionSystem, error) {
    es := &EncryptionSystem{}
    
    // 加载通信密钥
    commPrivateKey, err := loadPrivateKey("keys/communication_private.key")
    if err != nil {
        return nil, fmt.Errorf("加载通信私钥失败: %v", err)
    }
    es.commPrivateKey = commPrivateKey
    
    commPublicKey, err := loadPublicKey("keys/communication_public.pem")
    if err != nil {
        return nil, fmt.Errorf("加载通信公钥失败: %v", err)
    }
    es.commPublicKey = commPublicKey
    
    // 加载访问日志密钥
    accessPrivateKey, err := loadPrivateKey("keys/access_private.key")
    if err != nil {
        return nil, fmt.Errorf("加载访问日志私钥失败: %v", err)
    }
    es.accessPrivateKey = accessPrivateKey
    
    accessPublicKey, err := loadPublicKey("keys/access_public.pem")
    if err != nil {
        return nil, fmt.Errorf("加载访问日志公钥失败: %v", err)
    }
    es.accessPublicKey = accessPublicKey
    
    return es, nil
}

// ==================== 日志存储系统 ====================
type LogStorage struct {
    logDir       string
    es           *EncryptionSystem
    logMutex     sync.RWMutex
    accessTokens map[string]bool  // 记录已使用的下载令牌
}

func NewLogStorage(logDir string, es *EncryptionSystem) (*LogStorage, error) {
    // 创建日志目录
    if err := os.MkdirAll(logDir, 0700); err != nil {
        return nil, err
    }
    
    return &LogStorage{
        logDir:       logDir,
        es:           es,
        accessTokens: make(map[string]bool),
    }, nil
}

func (ls *LogStorage) StoreTrafficLog(log TrafficLog) error {
    ls.logMutex.Lock()
    defer ls.logMutex.Unlock()
    
    // 序列化日志
    data, err := json.Marshal(log)
    if err != nil {
        return fmt.Errorf("序列化日志失败: %v", err)
    }
    
    // 加密数据
    encryptedData, err := rsa.EncryptOAEP(
        sha256.New(),
        rand.Reader,
        ls.es.commPublicKey,
        data,
        nil,
    )
    if err != nil {
        return fmt.Errorf("加密日志失败: %v", err)
    }
    
    // 生成文件名
    filename := fmt.Sprintf("traffic_%s_%s.enc", 
        time.Now().Format("20060102_150405"),
        log.PacketSignature[:8],
    )
    
    // 写入文件
    filePath := filepath.Join(ls.logDir, filename)
    if err := os.WriteFile(filePath, encryptedData, 0600); err != nil {
        return fmt.Errorf("写入日志文件失败: %v", err)
    }
    
    log.Printf("已存储流量日志: %s", filename)
    return nil
}

func (ls *LogStorage) StoreAccessLog(log AccessLog) error {
    ls.logMutex.Lock()
    defer ls.logMutex.Unlock()
    
    // 检查令牌是否已使用
    if ls.accessTokens[log.DownloadToken] {
        return fmt.Errorf("下载令牌已使用: %s", log.DownloadToken)
    }
    
    // 序列化访问日志
    data, err := json.Marshal(log)
    if err != nil {
        return fmt.Errorf("序列化访问日志失败: %v", err)
    }
    
    // 使用访问日志公钥加密
    encryptedData, err := rsa.EncryptOAEP(
        sha256.New(),
        rand.Reader,
        ls.es.accessPublicKey,
        data,
        nil,
    )
    if err != nil {
        return fmt.Errorf("加密访问日志失败: %v", err)
    }
    
    // 生成文件名
    filename := fmt.Sprintf("access_%s_%s.enc",
        log.DownloadToken,
        time.Now().Format("20060102"),
    )
    
    // 写入文件
    filePath := filepath.Join(ls.logDir, filename)
    if err := os.WriteFile(filePath, encryptedData, 0600); err != nil {
        return fmt.Errorf("写入访问日志失败: %v", err)
    }
    
    // 标记令牌已使用
    ls.accessTokens[log.DownloadToken] = true
    
    log.Printf("已存储访问日志: %s", filename)
    return nil
}

// ==================== FRP流量监控 ====================
type FRPMonitor struct {
    targetIP   string
    targetPort int
    logStorage *LogStorage
    running    bool
    stopChan   chan struct{}
}

func NewFRPMonitor(ip string, port int, ls *LogStorage) *FRPMonitor {
    return &FRPMonitor{
        targetIP:   ip,
        targetPort: port,
        logStorage: ls,
        stopChan:   make(chan struct{}),
    }
}

func (fm *FRPMonitor) Start() error {
    fm.running = true
    go fm.monitorLoop()
    return nil
}

func (fm *FRPMonitor) Stop() {
    if fm.running {
        close(fm.stopChan)
        fm.running = false
    }
}

func (fm *FRPMonitor) monitorLoop() {
    // 这里实现FRP流量监控逻辑
    // 由于具体监控逻辑依赖于FRP协议解析，这里提供框架
    for {
        select {
        case <-fm.stopChan:
            return
        default:
            // 模拟检测恶意流量
            if fm.detectMaliciousTraffic() {
                fm.handleMaliciousTraffic()
            }
            time.Sleep(1 * time.Second)
        }
    }
}

func (fm *FRPMonitor) detectMaliciousTraffic() bool {
    // 实现恶意流量检测逻辑
    // 这里可以检查域名劫持、流量重定向等特征
    return false
}

func (fm *FRPMonitor) handleMaliciousTraffic() {
    logEntry := TrafficLog{
        Timestamp:        time.Now(),
        EventType:        "malicious_manipulation",
        AttackDomain:     "detected-malicious-domain.com",
        TargetDomain:     "original-service.com",
        TrafficBytes:     1024 * 100, // 100KB
        SourceIP:         fmt.Sprintf("%s:%d", fm.targetIP, fm.targetPort),
        ManipulationType: "domain_hijacking",
        Severity:         "high",
        PacketSignature:  generatePacketSignature(),
    }
    
    if err := fm.logStorage.StoreTrafficLog(logEntry); err != nil {
        log.Printf("存储流量日志失败: %v", err)
    }
}

// ==================== WebSocket 处理器 ====================
type WebSocketHandler struct {
    upgrader   websocket.Upgrader
    clients    map[*websocket.Conn]bool
    clientsMu  sync.Mutex
    logStorage *LogStorage
}

func NewWebSocketHandler(ls *LogStorage) *WebSocketHandler {
    return &WebSocketHandler{
        upgrader: websocket.Upgrader{
            CheckOrigin: func(r *http.Request) bool {
                return true // 在生产环境中应限制来源
            },
        },
        clients:    make(map[*websocket.Conn]bool),
        logStorage: ls,
    }
}

func (wsh *WebSocketHandler) HandleConnection(w http.ResponseWriter, r *http.Request) {
    conn, err := wsh.upgrader.Upgrade(w, r, nil)
    if err != nil {
        log.Printf("WebSocket升级失败: %v", err)
        return
    }
    
    wsh.clientsMu.Lock()
    wsh.clients[conn] = true
    wsh.clientsMu.Unlock()
    
    defer func() {
        wsh.clientsMu.Lock()
        delete(wsh.clients, conn)
        wsh.clientsMu.Unlock()
        conn.Close()
    }()
    
    // 处理客户端消息
    for {
        _, message, err := conn.ReadMessage()
        if err != nil {
            break
        }
        wsh.handleClientMessage(conn, message)
    }
}

func (wsh *WebSocketHandler) handleClientMessage(conn *websocket.Conn, message []byte) {
    // 处理客户端请求
    var req map[string]interface{}
    if err := json.Unmarshal(message, &req); err != nil {
        log.Printf("解析客户端消息失败: %v", err)
        return
    }
    
    action, ok := req["action"].(string)
    if !ok {
        return
    }
    
    switch action {
    case "get_logs":
        wsh.sendLogs(conn)
    case "get_stats":
        wsh.sendStats(conn)
    case "download_access_log":
        wsh.handleAccessLogDownload(conn, req)
    }
}

func (wsh *WebSocketHandler) sendLogs(conn *websocket.Conn) {
    // 获取最新的日志文件列表
    files, err := filepath.Glob(filepath.Join(wsh.logStorage.logDir, "traffic_*.enc"))
    if err != nil {
        conn.WriteJSON(map[string]interface{}{
            "error": "获取日志文件失败",
        })
        return
    }
    
    conn.WriteJSON(map[string]interface{}{
        "type": "logs_list",
        "data": files,
    })
}

// ==================== API服务器 ====================
type APIServer struct {
    config      *Config
    logStorage  *LogStorage
    encryption  *EncryptionSystem
    wsHandler   *WebSocketHandler
    frpMonitors map[string]*FRPMonitor
    server      *http.Server
}

func NewAPIServer(cfg *Config) (*APIServer, error) {
    // 初始化加密系统
    es, err := NewEncryptionSystem()
    if err != nil {
        return nil, err
    }
    
    // 初始化日志存储
    ls, err := NewLogStorage(cfg.Server.LogDir, es)
    if err != nil {
        return nil, err
    }
    
    // 初始化WebSocket处理器
    wsHandler := NewWebSocketHandler(ls)
    
    return &APIServer{
        config:      cfg,
        logStorage:  ls,
        encryption:  es,
        wsHandler:   wsHandler,
        frpMonitors: make(map[string]*FRPMonitor),
    }, nil
}

func (s *APIServer) Start() error {
    mux := http.NewServeMux()
    
    // 注册路由
    mux.HandleFunc("/ws", s.wsHandler.HandleConnection)
    mux.HandleFunc("/api/logs", s.handleLogsAPI)
    mux.HandleFunc("/api/stats", s.handleStatsAPI)
    mux.HandleFunc("/api/monitor/start", s.handleStartMonitor)
    mux.HandleFunc("/api/monitor/stop", s.handleStopMonitor)
    
    // 加载TLS证书
    cert, err := tls.LoadX509KeyPair("keys/server.crt", "keys/server.key")
    if err != nil {
        return fmt.Errorf("加载TLS证书失败: %v", err)
    }
    
    // 配置TLS
    tlsConfig := &tls.Config{
        Certificates: []tls.Certificate{cert},
        MinVersion:   tls.VersionTLS12,
    }
    
    // 创建HTTP服务器
    s.server = &http.Server{
        Addr:      s.config.Server.Address,
        Handler:   mux,
        TLSConfig: tlsConfig,
    }
    
    log.Printf("SentinelX 服务端启动，监听地址: %s", s.config.Server.Address)
    return s.server.ListenAndServeTLS("", "")
}

func (s *APIServer) Stop() {
    if s.server != nil {
        s.server.Close()
    }
    
    // 停止所有监控器
    for _, monitor := range s.frpMonitors {
        monitor.Stop()
    }
}

func (s *APIServer) handleLogsAPI(w http.ResponseWriter, r *http.Request) {
    if r.Method != "GET" {
        http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
        return
    }
    
    // 验证客户端身份
    clientID := r.Header.Get("X-Client-ID")
    token := r.Header.Get("X-Access-Token")
    
    if !s.validateClient(clientID, token) {
        http.Error(w, "未授权的访问", http.StatusUnauthorized)
        return
    }
    
    // 获取日志文件列表
    files, err := filepath.Glob(filepath.Join(s.logStorage.logDir, "traffic_*.enc"))
    if err != nil {
        http.Error(w, "获取日志失败", http.StatusInternalServerError)
        return
    }
    
    response := map[string]interface{}{
        "status": "success",
        "data":   files,
        "count":  len(files),
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func (s *APIServer) handleStartMonitor(w http.ResponseWriter, r *http.Request) {
    if r.Method != "POST" {
        http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
        return
    }
    
    var req struct {
        IP   string `json:"ip"`
        Port int    `json:"port"`
    }
    
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "无效的请求", http.StatusBadRequest)
        return
    }
    
    monitorKey := fmt.Sprintf("%s:%d", req.IP, req.Port)
    
    if _, exists := s.frpMonitors[monitorKey]; exists {
        w.WriteHeader(http.StatusOK)
        json.NewEncoder(w).Encode(map[string]string{
            "status": "already_running",
        })
        return
    }
    
    monitor := NewFRPMonitor(req.IP, req.Port, s.logStorage)
    if err := monitor.Start(); err != nil {
        http.Error(w, "启动监控失败", http.StatusInternalServerError)
        return
    }
    
    s.frpMonitors[monitorKey] = monitor
    
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(map[string]string{
        "status": "started",
        "key":    monitorKey,
    })
}

func (s *APIServer) validateClient(clientID, token string) bool {
    // 实现客户端验证逻辑
    // 这里可以验证客户端证书或预共享密钥
    return true // 简化版本
}

// ==================== 工具函数 ====================
func loadConfig(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }
    
    var config Config
    if err := yaml.Unmarshal(data, &config); err != nil {
        return nil, err
    }
    
    return &config, nil
}

func generatePacketSignature() string {
    // 生成数据包签名
    hash := sha256.New()
    hash.Write([]byte(time.Now().String()))
    return fmt.Sprintf("%x", hash.Sum(nil))
}

func loadPrivateKey(path string) (*rsa.PrivateKey, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }
    
    return x509.ParsePKCS1PrivateKey(data)
}

func loadPublicKey(path string) (*rsa.PublicKey, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }
    
    return x509.ParsePKCS1PublicKey(data)
}

// ==================== 主函数 ====================
func main() {
    // 解析命令行参数
    configPath := flag.String("config", "config.yaml", "配置文件路径")
    genKeys := flag.Bool("generate-keys", false, "生成新的密钥对")
    flag.Parse()
    
    if *genKeys {
        if err := generateKeyPairs(); err != nil {
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
    
    // 创建必要的目录
    if err := os.MkdirAll(config.Server.LogDir, 0700); err != nil {
        log.Fatalf("创建日志目录失败: %v", err)
    }
    if err := os.MkdirAll(config.Server.DataDir, 0700); err != nil {
        log.Fatalf("创建数据目录失败: %v", err)
    }
    
    // 创建API服务器
    server, err := NewAPIServer(config)
    if err != nil {
        log.Fatalf("创建服务器失败: %v", err)
    }
    
    // 启动服务器
    if err := server.Start(); err != nil {
        log.Fatalf("服务器启动失败: %v", err)
    }
}