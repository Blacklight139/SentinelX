# SentinelX Code Wiki

## 项目概述

**SentinelX** 是一个企业级安全流量监控系统，使用 Go 1.25 开发，用于实时检测中间商恶意操控，保护 FRP 流量安全。

- **项目类型**: Go 后端服务 + 安全监控
- **许可证**: AGPL-3.0
- **Go 版本**: 1.25+

---

## 项目结构

```
/workspace/
├── server/                          # 服务端主目录
│   ├── main.go                      # 程序入口
│   ├── optimize.go                   # Go 1.25 新特性演示
│   ├── benchmark_test.go            # 性能测试
│   ├── go.mod                       # Go 模块定义
│   ├── config.yaml.example          # 配置文件示例
│   ├── Dockerfile                   # Docker 构建文件
│   ├── docker-compose.yml           # Docker Compose 配置
│   ├── build.sh                     # 构建脚本
│   ├── install.sh                   # 安装脚本
│   ├── generate_keys.sh             # 密钥生成脚本
│   ├── sentinelx-server.service    # systemd 服务文件
│   └── benchmark_test.go           # 性能测试
├── .github/workflows/               # CI/CD 工作流
│   ├── go.yml                      # Go CI
│   ├── docker.yml                  # Docker 构建
│   ├── multi-platform.yml          # 多平台构建
│   ├── release.yml                 # 发布流程
│   └── security.yml                # 安全扫描
├── install.sh                      # 根目录安装脚本
└── online_install.sh               # 在线安装脚本
```

---

## 整体架构

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   FRP Client    │────▶│  SentinelX      │────▶│  恶意流量       │
│                 │     │  Monitor Agent   │     │  检测引擎       │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                              │                           │
                              ▼                           ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  SentinelX      │◀────│  加密通道       │◀────│  加密存储       │
│  Go Client      │     │  (RSA-2048)     │     │  (meg文件夹)    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### 组件说明

| 组件 | 功能 | 端口 |
|------|------|------|
| sentinelx-server | 主应用服务器，处理所有业务逻辑 | 8443 |
| Prometheus Metrics | 监控指标导出 | 9090 |
| Pprof | 性能分析 | 6060 |

---

## 主要模块

### 1. 配置系统 (`Config`)

**文件**: [main.go](file:///workspace/server/main.go#L63-L109)

```go
type Config struct {
    Server struct {
        Address      string   // 服务地址 (0.0.0.0:8443)
        LogDir       string   // 日志目录
        DataDir      string   // 数据目录
        MaxClients   int      // 最大客户端数
        ReadTimeout  int      // 读取超时(秒)
        WriteTimeout int      // 写入超时(秒)
        IdleTimeout  int      // 空闲超时(秒)
    }
    Security struct {
        RSAKeySize      int    // RSA密钥大小
        SessionTimeout  int    // 会话超时
        MaxLoginAttempts int   // 最大登录尝试
        EnableMTLS      bool   // 启用mTLS
    }
    Logging struct {
        Level        string  // 日志级别
        Format       string  // 日志格式
        RotationSize int     // 轮转大小
        RetentionDays int    // 保留天数
    }
    Monitoring struct {
        EnableMetrics bool   // 启用指标
        MetricsPort   int     // 指标端口
        EnablePprof   bool   // 启用性能分析
        PprofPort     int     // Pprof端口
    }
    Cache struct {
        Enabled bool         // 启用缓存
        SizeMB  int          // 缓存大小(MB)
        TTL     int          // TTL(秒)
    }
    Database struct {
        Type     string      // 数据库类型
        Host     string      // 主机
        Port     int          // 端口
        Name     string      // 数据库名
        User     string      // 用户
        Password string      // 密码
    }
}
```

### 2. 加密系统 (`EncryptionSystem`)

**文件**: [main.go](file:///workspace/server/main.go#L221-L361)

**职责**: RSA-2048 密钥对生成与管理，数据加密解密

**关键方法**:

| 方法 | 说明 |
|------|------|
| `NewEncryptionSystem()` | 创建加密系统实例，加载或生成密钥 |
| `loadOrGenerateKeys()` | 尝试加载密钥，失败则生成新密钥 |
| `generateKeys()` | 生成新的 RSA-2048 密钥对 |
| `saveKeysToFiles()` | 保存密钥到 `keys/` 目录 |
| `EncryptWithKey(data, publicKey)` | 使用 OAEP 模式加密数据 |
| `DecryptWithKey(encrypted, privateKey)` | 使用 OAEP 模式解密数据 |

**密钥文件**:
- `keys/communication_private.pem` - 通信私钥
- `keys/communication_public.pem` - 通信公钥
- `keys/access_private.pem` - 访问日志私钥
- `keys/access_public.pem` - 访问日志公钥

### 3. 缓存系统 (`Cache<K, V>`)

**文件**: [main.go](file:///workspace/server/main.go#L112-L181)

**职责**: 泛型线程安全缓存，支持 TTL 和容量限制

**关键方法**:

| 方法 | 说明 |
|------|------|
| `NewCache(capacity)` | 创建指定容量的缓存 |
| `Set(key, value, ttl)` | 设置缓存，自动清理过期和超容 |
| `Get(key)` | 获取缓存值，检查过期 |
| `cleanup()` | 清理所有过期条目 |
| `evict()` | 使用简单 LRU 策略驱逐条目 |

### 4. 线程安全 Map (`SafeMap<K, V>`)

**文件**: [main.go](file:///workspace/server/main.go#L32-L60)

**职责**: 泛型读写锁保护的 Map

**关键方法**:

| 方法 | 说明 |
|------|------|
| `NewSafeMap()` | 创建新的 SafeMap |
| `Set(key, value)` | 写入（加锁） |
| `Get(key)` | 读取（读锁） |
| `Delete(key)` | 删除（写锁） |

### 5. 日志存储系统 (`LogStorage`)

**文件**: [main.go](file:///workspace/server/main.go#L408-L536)

**职责**: 加密日志存储与管理

**关键方法**:

| 方法 | 说明 |
|------|------|
| `NewLogStorage(logDir, es)` | 创建日志存储实例 |
| `StoreTrafficLog(log)` | 存储流量日志（加密后写入文件） |
| `startCleanupTask()` | 启动定期清理任务（每小时） |
| `cleanupExpiredTokens()` | 清理过期访问令牌 |
| `updateStorageMetrics()` | 更新存储指标 |

### 6. 服务器核心 (`Server`)

**文件**: [main.go](file:///workspace/server/main.go#L539-L692)

**职责**: HTTP 服务器，管理所有组件

**关键方法**:

| 方法 | 说明 |
|------|------|
| `NewServer(cfg)` | 创建服务器实例 |
| `Start()` | 启动服务器（HTTPS + TLS 1.3） |
| `startMetricsServer()` | 启动 Prometheus 指标服务器 |
| `startPprofServer()` | 启动性能分析服务器 |

**路由**:

| 路由 | 方法 | 说明 |
|------|------|------|
| `/ws` | WebSocket | WebSocket 连接处理 |
| `/api/v1/logs` | GET | 获取日志列表 |
| `/api/v1/stats` | GET | 获取统计信息 |
| `/api/v1/monitor/start` | POST | 启动监控 |
| `/api/v1/monitor/stop` | POST | 停止监控 |
| `/api/v1/health` | GET | 健康检查 |
| `/metrics` | GET | Prometheus 指标 |

**中间件**:

| 中间件 | 说明 |
|--------|------|
| `withLogging` | 请求日志记录 |
| `withMetrics` | Prometheus 指标收集 |
| `withRecovery` | 恐慌恢复 |

---

## 数据结构

### TrafficLog (流量日志)

**文件**: [main.go](file:///workspace/server/main.go#L184-L202)

```go
type TrafficLog struct {
    Timestamp         time.Time              // 时间戳
    EventID           string                 // 事件ID
    EventType         string                 // 事件类型
    AttackDomain      string                 // 攻击域名
    TargetDomain      string                 // 目标域名
    TrafficBytes      int64                  // 流量字节数
    SourceIP          string                 // 源IP
    SourcePort        int                    // 源端口
    DestinationIP     string                 // 目标IP
    DestinationPort   int                    // 目标端口
    Protocol          string                 // 协议
    ManipulationType  string                 // 操控类型
    Severity          string                 // 严重程度
    Confidence        float64                // 置信度
    PacketSignature   string                 // 数据包签名
    EncryptedPayload  string                 // 加密载荷
    Metadata          map[string]interface{} // 元数据
}
```

### AccessLog (访问日志)

**文件**: [main.go](file:///workspace/server/main.go#L204-L218)

```go
type AccessLog struct {
    Timestamp       time.Time // 时间戳
    LogID           string    // 日志ID
    ClientID        string    // 客户端ID
    ClientVersion   string    // 客户端版本
    Action          string    // 动作
    Resource        string    // 资源
    Status          string    // 状态
    DownloadedFiles []string  // 下载的文件
    DownloadToken   string    // 下载令牌
    ClientIP        string    // 客户端IP
    UserAgent       string    // User-Agent
    ProcessingTime  int64     // 处理时间(ms)
    ErrorMessage    string    // 错误信息
}
```

---

## Prometheus 指标

**文件**: [main.go](file:///workspace/server/main.go#L364-L405)

| 指标名 | 类型 | 说明 |
|--------|------|------|
| `sentinelx_connections_active` | Gauge | 当前活跃连接数 |
| `sentinelx_connections_total` | Counter | 总连接数 |
| `sentinelx_traffic_bytes_total` | CounterVec | 总流量字节数 (labels: type, protocol) |
| `sentinelx_security_events_total` | CounterVec | 安全事件总数 (labels: severity, type) |
| `sentinelx_request_duration_seconds` | HistogramVec | 请求处理时间 (labels: endpoint, method) |
| `sentinelx_cache_hits_total` | Counter | 缓存命中次数 |
| `sentinelx_cache_misses_total` | Counter | 缓存未命中次数 |
| `sentinelx_logs_stored_total` | Counter | 存储的日志总数 |
| `sentinelx_storage_size_bytes` | Gauge | 日志存储大小 |
| `sentinelx_encryption_time_seconds` | Histogram | 加密耗时 |

---

## 依赖关系

**Go 模块**: `sentinelx-server`
**Go 版本**: 1.25

### 直接依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| github.com/gorilla/websocket | v1.5.2 | WebSocket 通信 |
| gopkg.in/yaml.v3 | v3.0.1 | YAML 配置解析 |
| golang.org/x/crypto | v0.28.0 | 加密功能 |
| golang.org/x/net | v0.28.0 | 网络功能 |
| github.com/prometheus/client_golang | v1.20.0 | Prometheus 指标 |
| github.com/sirupsen/logrus | v1.9.3 | 日志记录 |

### 间接依赖

| 依赖 | 用途 |
|------|------|
| github.com/beorn7/perks | Prometheus 指标工具 |
| github.com/cespare/xxhash/v2 | 高效哈希 |
| github.com/prometheus/client_model | Prometheus 数据模型 |
| github.com/prometheus/common | Prometheus 公共库 |
| github.com/prometheus/procfs | 系统指标收集 |
| golang.org/x/sys | 系统调用 |
| golang.org/x/term | 终端处理 |
| google.golang.org/protobuf | Protocol Buffers |

---

## 项目运行方式

### 1. 二进制部署

```bash
# 安装
cd server
./install.sh

# 或手动安装
go build -o sentinelx-server main.go
sudo ./install.sh

# 生成密钥
./sentinelx-server --generate-keys

# 启动服务
./sentinelx-server --config /etc/sentinelx/config.yaml
```

### 2. Docker 部署

```bash
# 拉取镜像
docker run -d \
  --name sentinelx \
  -p 8443:8443 \
  -p 9090:9090 \
  ghcr.io/blacklight139/sentinelx:latest

# 或使用 docker-compose
docker-compose up -d
```

### 3. 命令行参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--config` | 配置文件路径 | `config.yaml` |
| `--generate-keys` | 生成新的密钥对 | false |
| `--version` | 显示版本信息 | false |
| `--log-level` | 日志级别 (debug, info, warn, error) | "" |

### 4. 配置示例

**文件**: `/etc/sentinelx/config.yaml`

```yaml
server:
  address: "0.0.0.0:8443"
  log_dir: "/var/lib/sentinelx/meg"
  data_dir: "/var/lib/sentinelx/data"
  max_clients: 100

security:
  rsa_key_size: 2048
  session_timeout: 3600
  max_login_attempts: 5
  enable_mtls: false

logging:
  level: "info"
  rotation_size: 100
  retention_days: 30

monitoring:
  enable_metrics: true
  metrics_port: 9090
  enable_pprof: false
  pprof_port: 6060

cache:
  enabled: true
  size_mb: 100
  ttl_seconds: 3600

frp_monitoring:
  enabled: true
  monitor_ports:
    - 7000
    - 7001
    - 8080
```

---

## 安全特性

### TLS 配置

- **最低版本**: TLS 1.3
- **支持的密码套件**:
  - `TLS_AES_128_GCM_SHA256`
  - `TLS_AES_256_GCM_SHA384`
  - `TLS_CHACHA20_POLY1305_SHA256`
- **支持的曲线**:
  - `X25519`
  - `CurveP256`
  - `CurveP384`

### 加密方案

- **密钥交换**: RSA-2048 (OAEP 模式)
- **哈希算法**: SHA-256
- **密钥版本**: `v1_{timestamp}`

### mTLS 支持

可选启用双向 TLS 认证：
```yaml
security:
  enable_mtls: true
```

---

## 性能优化

### Go 1.25 新特性

**文件**: [optimize.go](file:///workspace/server/main.go)

1. **泛型函数**: `GenericFilter<T>` - 类型安全的过滤
2. **泛型缓存**: `GenericCache<K, V>` - 线程安全缓存
3. **atomic 改进**: `SafeCounter` - 原子操作计数器
4. **改进的错误处理**: `OperationResult<T>` - 结果封装

### 性能测试

**文件**: [benchmark_test.go](file:///workspace/server/benchmark_test.go)

```bash
# 运行基准测试
go test -bench=. -benchmem
```

---

## CI/CD 流程

### GitHub Actions 工作流

| 工作流 | 触发 | 说明 |
|--------|------|------|
| `go.yml` | push/PR | Go 测试和构建 |
| `docker.yml` | push | Docker 镜像构建 |
| `multi-platform.yml` | tag | 多平台二进制构建 |
| `release.yml` | tag | GitHub Release |
| `security.yml` | schedule | 安全扫描 |

---

## 许可证

AGPL-3.0 (GNU Affero General Public License v3.0)

关键要点：
- 自由使用、修改和分发
- 修改后必须以相同许可证开源
- 网络服务也必须提供源代码
- 包含明确的专利授权条款
