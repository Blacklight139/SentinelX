# SentinelX - 安全流量监控与日志系统

## 📖 概述

**SentinelX** 是一个企业级的安全流量监控与日志记录系统，专门设计用于检测和记录中间商或者frpc使用者对FRP流量的恶意操控行为。系统采用端到端加密技术，确保日志数据的安全性和完整性。

### 核心特性
- 🔒 **端到端非对称加密** - 客户端与服务端之间使用RSA-2048加密通信
- 📊 **实时流量监控** - 实时记录攻击域名、被攻击域名及流量计量
- 🔐 **双重加密存储** - 主日志和访问日志分别使用不同的密钥加密
- 🛡️ **一次性下载保护** - 访问日志只能下载一次，增强安全性
- 🌐 **跨平台客户端** - 支持Windows、macOS、Linux的GUI客户端
- 📈 **可视化监控** - 客户端实时查看加密日志统计信息

## 🚀 快速开始

### 服务端安装（Ubuntu/Debian）

#### 方法一：使用安装脚本（推荐）
```bash
wget https://raw.githubusercontent.com/Blacklight139/SentinelX/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

#### 方法二：手动安装
```bash
# 1. 安装Go环境（如果未安装）
sudo apt update
sudo apt install -y golang git

# 2. 克隆仓库
git clone https://github.com/Blacklight139/SentinelX.git
cd SentinelX/server

# 3. 生成密钥
./generate_keys.sh

# 4. 编译服务端
go build -o sentinelx-server main.go

# 5. 配置服务（可选）
sudo cp sentinelx-server.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable sentinelx-server
sudo systemctl start sentinelx-server
```

### 安装脚本内容（install.sh）
```bash
#!/bin/bash

# SentinelX 服务端安装脚本
set -e

echo "正在安装 SentinelX 服务端..."

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
  echo "请使用sudo运行此脚本"
  exit 1
fi

# 更新系统
apt update && apt upgrade -y

# 安装依赖
apt install -y golang git openssl

# 创建服务用户
if ! id "sentinelx" &>/dev/null; then
    useradd -r -s /bin/false -m -d /opt/sentinelx sentinelx
fi

# 创建目录结构
mkdir -p /opt/sentinelx/{logs,data,meg,bin,config}
chown -R sentinelx:sentinelx /opt/sentinelx

# 下载源码
cd /opt/sentinelx
if [ -d "SentinelX" ]; then
    echo "更新现有代码..."
    cd SentinelX
    git pull
else
    echo "克隆仓库..."
    git clone https://github.com/Blacklight139/SentinelX.git
    cd SentinelX
fi

# 进入服务端目录
cd server

# 生成密钥
echo "生成加密密钥..."
./generate_keys.sh

# 编译服务端
echo "编译服务端..."
go build -o /opt/sentinelx/bin/sentinelx-server main.go

# 创建配置文件
if [ ! -f "/opt/sentinelx/config/config.yaml" ]; then
    cp config.yaml.example /opt/sentinelx/config/config.yaml
fi

# 复制服务文件
if [ -f "sentinelx-server.service" ]; then
    cp sentinelx-server.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable sentinelx-server
fi

# 复制密钥
cp -r keys /opt/sentinelx/config/
chmod 600 /opt/sentinelx/config/keys/*.key
chown -R sentinelx:sentinelx /opt/sentinelx/config

echo "安装完成！"
echo "请编辑配置文件: /opt/sentinelx/config/config.yaml"
echo "然后启动服务: sudo systemctl start sentinelx-server"
```

## ⚙️ 配置说明

### 服务端配置 (config.yaml)
```yaml
server:
  address: "0.0.0.0:8443"  # 监听地址
  log_dir: "/opt/sentinelx/meg"  # 加密日志存储目录
  data_dir: "/opt/sentinelx/data"  # 数据目录
  max_clients: 100  # 最大客户端连接数

security:
  rsa_key_size: 2048  # RSA密钥长度
  session_timeout: 3600  # 会话超时时间(秒)
  max_login_attempts: 5  # 最大登录尝试次数

logging:
  level: "info"  # 日志级别: debug, info, warn, error
  rotation_size: 100  # 日志轮转大小(MB)
  retention_days: 30  # 日志保留天数

monitoring:
  enable_metrics: true  # 启用指标收集
  metrics_port: 9090  # 指标端口
```

### 密钥生成 (generate_keys.sh)
```bash
#!/bin/bash

# 生成RSA密钥对
generate_keys() {
    local key_name=$1
    echo "生成 $key_name 密钥..."
    
    # 生成私钥
    openssl genrsa -out keys/${key_name}_private.key 2048
    chmod 600 keys/${key_name}_private.key
    
    # 生成公钥
    openssl rsa -in keys/${key_name}_private.key -pubout -out keys/${key_name}_public.pem
    
    echo "$key_name 密钥已生成"
}

# 创建目录
mkdir -p keys

# 生成通信密钥对
generate_keys "communication"

# 生成访问日志密钥对
generate_keys "access"

# 生成服务端TLS证书
echo "生成TLS证书..."
openssl req -x509 -newkey rsa:2048 -keyout keys/server.key -out keys/server.crt \
    -days 3650 -nodes -subj "/C=CN/ST=Beijing/L=Beijing/O=SentinelX/CN=localhost"

echo "所有密钥已生成到 keys/ 目录"
```

## 🏗️ 系统架构

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│   FRP Client    │────▶│  SentinelX      │────▶│  恶意流量       │
│                 │     │  Monitor Agent  │     │  检测引擎       │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                              │                           │
                              ▼                           ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  SentinelX      │◀────│  加密通道       │◀────│  加密存储       │
│  GUI Client     │     │  (RSA-2048)     │     │  (meg文件夹)    │
│                 │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## 🔧 数据流处理流程

### 1. 流量监控与捕获
```go
// 监控FRP流量并检测恶意行为
func monitorFRPTraffic(conn net.Conn) {
    // 解析FRP协议头
    header := parseFRPHeader(conn)
    
    // 检测中间商操控特征
    if isMaliciousManipulation(header) {
        // 记录攻击信息
        logEntry := TrafficLog{
            Timestamp:     time.Now(),
            AttackDomain:  detectAttackDomain(header),
            TargetDomain:  detectTargetDomain(header),
            TrafficBytes:  calculateTraffic(conn),
            SourceIP:      conn.RemoteAddr().String(),
            ManipulationType: detectManipulationType(header),
        }
        
        // 加密并存储日志
        encryptedLog := encryptLog(logEntry, clientPublicKey)
        storeEncryptedLog(encryptedLog)
        
        // 实时通知客户端
        notifyClient(logEntry)
    }
}
```

### 2. 加密存储机制
```go
// 双重加密存储系统
type EncryptionSystem struct {
    commPrivateKey *rsa.PrivateKey  // 通信私钥
    commPublicKey  *rsa.PublicKey   // 通信公钥
    accessPrivateKey *rsa.PrivateKey // 访问日志私钥
    accessPublicKey  *rsa.PublicKey  // 访问日志公钥
}

// 存储主日志（客户端可查看）
func (es *EncryptionSystem) storeMainLog(log TrafficLog) error {
    // 序列化日志
    data, _ := json.Marshal(log)
    
    // 使用通信公钥加密
    encryptedData, err := rsa.EncryptOAEP(
        sha256.New(),
        rand.Reader,
        es.commPublicKey,
        data,
        nil,
    )
    
    // 存储到meg文件夹
    filename := fmt.Sprintf("log_%s.enc", time.Now().Format("20060102_150405"))
    return os.WriteFile(filepath.Join("meg", filename), encryptedData, 0600)
}

// 存储访问日志（服务端可查看，一次性下载）
func (es *EncryptionSystem) storeAccessLog(access AccessLog) error {
    // 序列化访问日志
    data, _ := json.Marshal(access)
    
    // 使用访问日志公钥加密
    encryptedData, err := rsa.EncryptOAEP(
        sha256.New(),
        rand.Reader,
        es.accessPublicKey,
        data,
        nil,
    )
    
    // 生成一次性令牌
    token := generateOneTimeToken()
    
    // 存储带令牌的文件
    filename := fmt.Sprintf("access_%s_%s.enc", token, time.Now().Format("20060102"))
    return os.WriteFile(filepath.Join("meg", filename), encryptedData, 0600)
}
```

## 📦 客户端功能

### GUI客户端特性
- 🔑 **安全连接**：使用RSA密钥对建立加密连接
- 📊 **实时监控**：可视化展示流量统计和攻击检测
- 🔍 **日志查看**：解密并显示存储在meg文件夹中的日志
- ⚡ **性能监控**：实时显示系统资源使用情况
- 🛡️ **告警系统**：检测到攻击时显示实时告警

### 客户端连接示例
```python
# Python GUI客户端示例（使用Tkinter）
class SentinelXClient:
    def __init__(self):
        self.server_ip = ""
        self.server_port = 8443
        self.private_key = None
        
    def connect_to_server(self):
        # 加载私钥
        with open("client_private.key", "rb") as f:
            self.private_key = serialization.load_pem_private_key(
                f.read(),
                password=None
            )
        
        # 建立加密连接
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        
        with socket.create_connection((self.server_ip, self.server_port)) as sock:
            with context.wrap_socket(sock, server_hostname=self.server_ip) as secure_sock:
                # 执行密钥交换
                self.perform_key_exchange(secure_sock)
                
                # 开始接收实时日志
                self.start_log_receiver(secure_sock)
```

## 📊 日志格式

### 主日志格式（加密存储）
```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "event_type": "malicious_manipulation",
  "attack_domain": "malicious-proxy.com",
  "target_domain": "target-service.com",
  "traffic_bytes": 150430,
  "source_ip": "192.168.1.100:54321",
  "manipulation_type": "domain_hijacking",
  "severity": "high",
  "packet_signature": "a1b2c3d4e5f6",
  "encrypted_payload": "BASE64_ENCODED_ENCRYPTED_DATA"
}
```

### 访问日志格式
```json
{
  "timestamp": "2024-01-15T10:31:00Z",
  "client_id": "client_001",
  "action": "log_download",
  "downloaded_files": ["log_20240115_103000.enc"],
  "download_token": "one_time_token_xyz123",
  "client_ip": "192.168.1.50",
  "user_agent": "SentinelX-GUI-Client/1.0"
}
```

## 🔒 安全特性

### 多层安全防护
1. **传输层加密**：TLS 1.3 + RSA-2048密钥交换
2. **数据加密**：端到端RSA-OAEP加密
3. **存储加密**：双重加密机制分离权限
4. **访问控制**：一次性令牌下载机制
5. **完整性验证**：SHA-256哈希校验

### 密钥管理
```go
// 安全的密钥管理器
type KeyManager struct {
    keys map[string]*rsa.PrivateKey
    mu   sync.RWMutex
}

func (km *KeyManager) RotateKeys() {
    km.mu.Lock()
    defer km.mu.Unlock()
    
    // 定期轮换密钥
    newKey, _ := rsa.GenerateKey(rand.Reader, 2048)
    km.keys["current"] = newKey
    km.keys["previous"] = km.keys["current"]
    
    // 归档旧密钥
    archiveKey(km.keys["old"])
}
```

## 📈 监控与告警

### 内置监控指标
- 实时连接数
- 流量统计（攻击/正常）
- 系统资源使用率
- 加密/解密性能
- 存储空间使用

### 告警规则示例
```yaml
alerts:
  - name: "high_traffic_anomaly"
    condition: "traffic_rate > 100MBps AND attack_ratio > 0.3"
    severity: "critical"
    actions: ["email", "webhook", "log"]
    
  - name: "multiple_attack_domains"
    condition: "unique_attack_domains > 10 WITHIN 5m"
    severity: "high"
    actions: ["email", "log"]
```

## 🐳 Docker部署

```yaml
# docker-compose.yml
version: '3.8'
services:
  sentinelx-server:
    build: ./server
    ports:
      - "8443:8443"
      - "9090:9090"
    volumes:
      - ./meg:/app/meg
      - ./data:/app/data
      - ./config:/app/config
    environment:
      - LOG_LEVEL=info
      - MAX_CLIENTS=100
    restart: unless-stopped

  sentinelx-client:
    build: ./client
    environment:
      - SERVER_HOST=sentinelx-server
      - SERVER_PORT=8443
    depends_on:
      - sentinelx-server
```

## 🤝 贡献指南

我们欢迎各种形式的贡献！请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 提交 Pull Request

## 📄 许可证

本项目基于 MIT 许可证发布 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🚨 免责声明

本项目仅用于安全研究和授权的合规监控。用户需确保在合法范围内使用本系统，并遵守所有适用的法律法规。开发者不对任何滥用行为负责。

## 📞 支持与联系

- 📧 邮箱：security@blacklight139.com
- 🐛 提交 [Issue](https://github.com/Blacklight139/SentinelX/issues)
- 📚 [文档](https://github.com/Blacklight139/SentinelX/wiki)
- 💬 [Discussions](https://github.com/Blacklight139/SentinelX/discussions)

---

**注意**：部署前请确保已获得相关监控权限，并遵守当地法律法规。建议在测试环境中充分验证后再投入生产使用。
