# SentinelX - 安全流量监控与日志系统

## 🌟 项目简介

**SentinelX** 是一个企业级的安全流量监控与日志记录系统，专门设计用于检测和记录中间商（如mefrp）对FRP流量的恶意操控行为。系统采用端到端加密技术，确保日志数据的安全性和完整性。

### 核心特性
- 🔒 **端到端非对称加密** - 客户端与服务端之间使用RSA-2048加密通信
- 📊 **实时流量监控** - 实时记录攻击域名、被攻击域名及流量计量
- 🔐 **双重加密存储** - 主日志和访问日志分别使用不同的密钥加密
- 🛡️ **一次性下载保护** - 访问日志只能下载一次，增强安全性
- 🌐 **跨平台客户端** - 支持Windows、macOS、Linux的GUI客户端
- 📈 **可视化监控** - 客户端实时查看加密日志统计信息

## 🚀 快速安装

### 方式一：一键在线安装（推荐）
```bash
# 使用 Gitee（国内推荐，速度更快）
curl -sSL https://gitee.com/dark-beam/SentinelX/raw/main/install.sh | sudo bash

# 或使用 GitHub（国际用户）
curl -sSL https://raw.githubusercontent.com/Blacklight139/SentinelX/main/install.sh | sudo bash
```

### 方式二：完整在线安装脚本
```bash
# 1. 下载完整安装脚本
wget https://gitee.com/dark-beam/SentinelX/raw/main/online_install.sh

# 2. 赋予执行权限
chmod +x online_install.sh

# 3. 执行安装（支持多种选项）
sudo ./online_install.sh                    # 使用预编译包
sudo ./online_install.sh --source           # 从源码编译安装
sudo ./online_install.sh --help             # 查看帮助信息
```

### 方式三：Docker快速部署
```bash
# 一键Docker安装
curl -sSL https://gitee.com/dark-beam/SentinelX/raw/main/docker_install.sh | bash
```

### 方式四：手动源码安装
```bash
# 1. 克隆仓库
git clone https://gitee.com/dark-beam/SentinelX.git
cd SentinelX

# 2. 生成加密密钥
cd server
chmod +x generate_keys.sh
./generate_keys.sh

# 3. 编译安装
go build -o sentinelx-server main.go
sudo ./install.sh
```

## 📋 系统要求

### 服务端要求
- **操作系统**: Ubuntu 18.04+, CentOS 7+, RHEL 8+, Debian 10+
- **CPU**: 双核 2.0GHz 或更高
- **内存**: 至少 2GB RAM（推荐 4GB）
- **存储**: 至少 20GB 可用空间（日志存储）
- **网络**: 需要开放 8443（HTTPS）和 9090（Metrics）端口

### 客户端要求
- **操作系统**: Windows 10+, macOS 10.15+, Linux（各发行版）
- **内存**: 至少 1GB RAM
- **网络**: 能够访问 SentinelX 服务端

### 开发环境要求
- **Go**: 1.19 或更高版本
- **Docker**: 20.10+（可选，用于容器化部署）
- **OpenSSL**: 用于生成加密密钥

## ⚙️ 安装选项详解

### 1. 一键安装选项
```bash
# 基本安装
curl -sSL https://gitee.com/dark-beam/SentinelX/raw/main/install.sh | sudo bash

# 带参数安装
curl -sSL https://gitee.com/dark-beam/SentinelX/raw/main/install.sh | sudo bash -s -- \
  --source \          # 从源码编译
  --log-level info \   # 设置日志级别
  --no-firewall       # 不配置防火墙
```

### 2. 高级安装选项
```bash
# 自定义安装目录
export SENTINELX_HOME=/opt/custom_path
sudo ./online_install.sh

# 指定配置文件
sudo ./online_install.sh --config /path/to/config.yaml

# 跳过密钥生成（使用现有密钥）
sudo ./online_install.sh --skip-keys
```

### 3. 生产环境部署
```bash
# 创建专用用户和组
sudo groupadd sentinelx
sudo useradd -r -g sentinelx -s /bin/false sentinelx

# 安装服务
sudo ./online_install.sh --production --user sentinelx --group sentinelx

# 配置日志轮转
sudo cp server/logrotate.conf /etc/logrotate.d/sentinelx
```

## 🏗️ 系统架构

### 总体架构
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

### 组件说明

| 组件 | 功能描述 | 端口 |
|------|----------|------|
| **SentinelX Server** | 主服务器，处理所有监控逻辑 | 8443 (HTTPS) |
| **WebSocket Service** | 实时数据传输服务 | 8443 (WSS) |
| **Metrics Exporter** | 性能指标导出 | 9090 (HTTP) |
| **Key Management** | 密钥管理与轮换 | 内部 |
| **Log Storage** | 加密日志存储 | 文件系统 |

## 🔧 配置说明

### 基本配置文件 (`config.yaml`)
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

logging:
  level: "info"
  rotation_size: 100
  retention_days: 30

monitoring:
  enable_metrics: true
  metrics_port: 9090

frp_monitoring:
  enabled: true
  monitor_ports:
    - 7000
    - 7001
    - 8080
```

### 环境变量配置
```bash
# 启动时覆盖配置
export SENTINELX_LOG_LEVEL=debug
export SENTINELX_SERVER_ADDR=:9443
export SENTINELX_LOG_DIR=/data/sentinelx/logs

# 启动服务
./sentinelx-server
```

## 📊 数据流处理流程

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
```

## 🔐 安全特性

### 多层安全防护
1. **传输层加密**：TLS 1.3 + RSA-2048密钥交换
2. **数据加密**：端到端RSA-OAEP加密
3. **存储加密**：双重加密机制分离权限
4. **访问控制**：一次性令牌下载机制
5. **完整性验证**：SHA-256哈希校验

### 密钥管理策略
```bash
# 密钥生成
./generate_keys.sh

# 密钥轮换（生产环境建议每月轮换）
./rotate_keys.sh --type communication --backup

# 密钥备份
tar -czf keys_backup_$(date +%Y%m%d).tar.gz /etc/sentinelx/keys/
```

## 🖥️ 客户端使用

### GUI客户端功能
- 🔑 **安全连接**：使用RSA密钥对建立加密连接
- 📊 **实时监控**：可视化展示流量统计和攻击检测
- 🔍 **日志查看**：解密并显示存储在meg文件夹中的日志
- ⚡ **性能监控**：实时显示系统资源使用情况
- 🛡️ **告警系统**：检测到攻击时显示实时告警

### 客户端连接配置
```json
{
  "server": {
    "address": "your-server.com:8443",
    "timeout": 30,
    "reconnect_interval": 5
  },
  "encryption": {
    "public_key_path": "keys/communication_public.pem",
    "private_key_path": "keys/client_private.key",
    "access_public_key_path": "keys/access_public.pem"
  },
  "monitoring": {
    "target_ip": "127.0.0.1",
    "target_ports": [7000, 7001, 8080],
    "check_interval": 10
  }
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

### Docker Compose配置
```yaml
version: '3.8'
services:
  sentinelx-server:
    image: sentinelx/server:latest
    ports:
      - "8443:8443"
      - "9090:9090"
    volumes:
      - ./data:/var/lib/sentinelx
      - ./config:/etc/sentinelx
    environment:
      - LOG_LEVEL=info
      - TZ=Asia/Shanghai
    restart: unless-stopped
```

### 快速启动
```bash
# 创建必要目录
mkdir -p sentinelx/{data,config,logs}

# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f sentinelx-server
```

## 🔄 备份与恢复

### 自动备份脚本
```bash
#!/bin/bash
# 每日自动备份
BACKUP_DIR="/opt/sentinelx/backup"
DATE=$(date +%Y%m%d_%H%M%S)

# 停止服务
systemctl stop sentinelx-server

# 创建备份
tar -czf $BACKUP_DIR/backup_$DATE.tar.gz \
  /etc/sentinelx \
  /var/lib/sentinelx \
  /opt/sentinelx/config

# 启动服务
systemctl start sentinelx-server

# 清理旧备份（保留7天）
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
```

### 数据恢复
```bash
# 停止服务
systemctl stop sentinelx-server

# 恢复备份
tar -xzf backup_20240115_143022.tar.gz -C /

# 恢复权限
chown -R sentinelx:sentinelx /etc/sentinelx /var/lib/sentinelx

# 启动服务
systemctl start sentinelx-server
```

## 🐛 故障排除

### 常见问题

#### 1. 服务启动失败
```bash
# 查看日志
journalctl -u sentinelx-server -f

# 检查端口占用
netstat -tlnp | grep :8443

# 检查密钥权限
ls -la /etc/sentinelx/keys/
```

#### 2. 客户端连接失败
```bash
# 测试端口连通性
openssl s_client -connect your-server.com:8443

# 检查防火墙
sudo ufw status
sudo firewall-cmd --list-all
```

#### 3. 存储空间不足
```bash
# 清理旧日志
find /var/lib/sentinelx/meg -name "*.enc" -mtime +30 -delete

# 查看存储使用
du -sh /var/lib/sentinelx/meg/
```

## 📚 文档资源

### 在线文档
- 📖 **项目主页**: [https://gitee.com/dark-beam/SentinelX](https://gitee.com/dark-beam/SentinelX)
- 📚 **安装指南**: [https://gitee.com/dark-beam/SentinelX/wiki/Installation](https://gitee.com/dark-beam/SentinelX/wiki/Installation)
- 🔧 **配置文档**: [https://gitee.com/dark-beam/SentinelX/wiki/Configuration](https://gitee.com/dark-beam/SentinelX/wiki/Configuration)
- 🐛 **故障排除**: [https://gitee.com/dark-beam/SentinelX/wiki/Troubleshooting](https://gitee.com/dark-beam/SentinelX/wiki/Troubleshooting)

### 命令行工具
```bash
# 查看系统状态
sentinelx-cli status

# 查看日志统计
sentinelx-cli logs --stats

# 测试监控规则
sentinelx-cli test-rule --file rule.yaml

# 生成配置模板
sentinelx-cli config generate
```

## 🤝 贡献指南

我们欢迎各种形式的贡献！请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

### 开发环境搭建
```bash
# 1. Fork 本仓库
git clone https://gitee.com/YOUR_USERNAME/SentinelX.git
cd SentinelX

# 2. 安装依赖
cd server
go mod download

# 3. 启动开发服务器
go run main.go --dev

# 4. 运行测试
go test ./...
```

### 代码规范
- 使用 `go fmt` 格式化代码
- 提交前运行 `go vet` 和 `go test`
- 遵循 Go 语言官方代码规范
- 为新增功能编写单元测试

## 📄 许可证

本项目基于 MIT 许可证发布 - 查看 [LICENSE](LICENSE) 文件了解详情。

```
MIT License

Copyright (c) 2024 Dark Beam

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

## 🚨 免责声明

本项目仅用于安全研究和授权的合规监控。用户需确保在合法范围内使用本系统，并遵守所有适用的法律法规。开发者不对任何滥用行为负责。

**重要提示**：
- 部署前请确保已获得相关监控权限
- 遵守当地法律法规
- 建议在测试环境中充分验证后再投入生产使用
- 定期更新系统和安全补丁

## 📞 支持与联系

### 社区支持
- 🐛 **问题反馈**: 国内渠道：[https://gitee.com/dark-beam/SentinelX/issues](https://gitee.com/dark-beam/SentinelX/issues)
- 国外渠道：[https://github.com/Blacklight139/SentinelX/issues](https://github.com/Blacklight139/SentinelX/issues)
- 💬 **讨论区**: 国内渠道：[https://gitee.com/dark-beam/SentinelX/pulls](https://gitee.com/dark-beam/SentinelX/pulls)
- 国外渠道：[https://github.com/Blacklight139/SentinelX/pulls](https://github.com/Blacklight139/SentinelX/pulls)
- 📧 **邮箱**: 3056319173@qq.com

### 商业支持
如需商业支持、定制开发或企业版授权，请联系：
- **官网**: (暂未开放)
- **商务合作**: 
- **技术支持**: 3056319173@qq.com

### 更新日志
查看最新版本和更新内容：（无）

---

**SentinelX** - 守护您的网络流量安全 🛡️
