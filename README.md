SentinelX - 安全流量监控与日志系统

<p align="center">
  <img src="https://img.shields.io/badge/Go-1.25.5-00ADD8?style=for-the-badge&logo=go" alt="Go Version">
  <img src="https://img.shields.io/badge/License-AGPL%203.0-green?style=for-the-badge" alt="License">
  <img src="https://img.shields.io/github/actions/workflow/status/Blacklight139/SentinelX/go.yml?style=for-the-badge&label=CI/CD" alt="CI/CD">
  <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20Windows%20%7C%20macOS-blue?style=for-the-badge" alt="Platform">
  <img src="https://img.shields.io/github/stars/Blacklight139/SentinelX?style=for-the-badge&logo=github" alt="GitHub Stars">
  <img src="https://img.shields.io/gitee/stars/dark-beam/SentinelX?style=for-the-badge&logo=gitee" alt="Gitee Stars">
</p><div align="center">
  <h1>SentinelX - 企业级安全流量监控系统</h1>
  <p>实时检测中间商恶意操控，保护您的FRP流量安全</p>English | 中文 | 文档

</div>📍 双仓库同步

本项目同时在 GitHub 和 Gitee 维护，您可以根据网络状况选择最合适的平台：

平台 地址 推荐用户 特点
🌍 GitHub https://github.com/Blacklight139/SentinelX 国际用户、海外用户 完整的CI/CD、自动发布、多平台构建
🇨🇳 Gitee https://gitee.com/dark-beam/SentinelX 中国大陆用户 国内镜像、加速下载、中文社区

🚀 快速开始

一键安装（推荐）

中国大陆用户（使用 Gitee 镜像）

```bash
curl -sSL https://gitee.com/dark-beam/SentinelX/raw/main/install.sh | sudo bash
```

国际用户（使用 GitHub）

```bash
curl -sSL https://raw.githubusercontent.com/Blacklight139/SentinelX/main/install.sh | sudo bash
```

Docker 快速部署

```bash
# 使用 GitHub Docker Hub
docker run -d \
  --name sentinelx \
  -p 8443:8443 \
  -p 9090:9090 \
  ghcr.io/blacklight139/sentinelx:latest

# 或者使用 Docker Compose
git clone https://github.com/Blacklight139/SentinelX.git
cd SentinelX
docker-compose up -d
```

✨ 核心特性

🔒 安全监控

· 端到端加密通信: 使用 RSA-2048 + AES-256 双重加密
· 实时流量分析: 实时监控 FRP 流量，检测中间商操控和域名劫持攻击
· 加密日志存储: 日志文件采用双重加密，存储在安全的 meg 文件夹中
· 智能告警系统: 基于规则的异常检测，实时告警推送

📊 系统功能

· Go语言客户端: 高性能的Go客户端，支持跨平台部署
· RESTful API: 完整的API接口支持，便于集成和扩展
· Prometheus集成: 完整的监控指标导出
· 多平台支持: Linux、Windows、macOS全平台支持
· 容器化部署: 支持Docker和Kubernetes部署

🚧 开发中功能

· 三端互通: Web、移动端、桌面端统一管理界面（开发中）
· 机器学习检测: 基于机器学习的异常流量检测（规划中）
· 分布式部署: 支持多节点集群部署（规划中）

🏗️ 系统架构

架构概览

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
│  Go Client      │     │  (RSA-2048)     │     │  (meg文件夹)    │
│                 │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

组件说明

组件 功能 端口 部署方式
sentinelx-server 主应用服务器，处理所有业务逻辑 8443 Docker/二进制
sentinelx-client Go语言客户端，提供命令行接口 - 二进制
PostgreSQL 关系型数据库，存储配置和元数据 5432 Docker/外部
Redis 缓存和消息队列 6379 Docker/外部
Prometheus 指标收集和监控 9090 Docker/外部

⚙️ 配置说明

基础配置文件

创建 /etc/sentinelx/config.yaml：

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

📡 API 文档

基础认证

```bash
# 获取访问令牌
curl -X POST https://localhost:8443/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"your-password"}'

# 使用令牌访问 API
curl -H "Authorization: Bearer <token>" \
  https://localhost:8443/api/v1/logs
```

主要 API 端点

端点 方法 描述
/api/v1/health GET 健康检查
/api/v1/auth/login POST 用户登录
/api/v1/logs GET 获取日志列表
/api/v1/logs/{id} GET 获取特定日志
/api/v1/stats GET 获取统计信息
/api/v1/alerts GET 获取告警列表
/api/v1/monitor/start POST 启动监控
/api/v1/monitor/stop POST 停止监控

🔧 Go 客户端使用

安装 Go 客户端

```bash
# 从源码编译
go install github.com/Blacklight139/SentinelX/client@latest

# 或下载预编译版本
# Linux
wget https://github.com/Blacklight139/SentinelX/releases/latest/download/sentinelx-client-linux-amd64
# Windows
wget https://github.com/Blacklight139/SentinelX/releases/latest/download/sentinelx-client-windows-amd64.exe
# macOS
wget https://github.com/Blacklight139/SentinelX/releases/latest/download/sentinelx-client-darwin-amd64
```

客户端命令

```bash
# 连接到服务端
sentinelx-client connect --server https://your-server.com:8443 --token your-token

# 查看监控状态
sentinelx-client monitor status

# 获取日志
sentinelx-client logs list --severity high --last 24h

# 启动流量监控
sentinelx-client monitor start --target 192.168.1.100:7000

# 查看系统统计
sentinelx-client stats

# 导出加密日志
sentinelx-client logs export --output ./logs.tar.gz
```

Go 客户端 SDK 示例

```go
package main

import (
    "context"
    "fmt"
    "log"
    "github.com/Blacklight139/SentinelX/client"
)

func main() {
    // 创建客户端
    cfg := &client.Config{
        ServerURL: "https://your-server.com:8443",
        AuthToken: "your-auth-token",
    }
    
    cli, err := client.NewClient(cfg)
    if err != nil {
        log.Fatal(err)
    }
    
    // 获取监控状态
    status, err := cli.Monitor.Status(context.Background())
    if err != nil {
        log.Fatal(err)
    }
    
    fmt.Printf("监控状态: %v\n", status)
    
    // 获取最近的高危日志
    logs, err := cli.Logs.List(context.Background(), &client.LogFilter{
        Severity: []string{"high", "critical"},
        Limit:    50,
    })
    if err != nil {
        log.Fatal(err)
    }
    
    fmt.Printf("找到 %d 条日志\n", len(logs))
    
    // 订阅实时日志
    stream, err := cli.Logs.Stream(context.Background(), &client.LogStreamFilter{})
    if err != nil {
        log.Fatal(err)
    }
    
    for log := range stream {
        fmt.Printf("新日志: %+v\n", log)
    }
}
```

🐳 容器化部署

Docker Compose 部署

```yaml
version: '3.8'

services:
  sentinelx:
    image: ghcr.io/blacklight139/sentinelx:latest
    container_name: sentinelx-server
    restart: unless-stopped
    ports:
      - "8443:8443"
      - "9090:9090"
    volumes:
      - sentinelx_data:/var/lib/sentinelx
      - sentinelx_config:/etc/sentinelx
    environment:
      - SENTINELX_DB_HOST=postgres
      - SENTINELX_DB_PASSWORD=yourpassword
    networks:
      - sentinelx-network

  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: sentinelx
      POSTGRES_USER: sentinelx
      POSTGRES_PASSWORD: yourpassword
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - sentinelx-network

volumes:
  sentinelx_data:
  sentinelx_config:
  postgres_data:

networks:
  sentinelx-network:
    driver: bridge
```

🔧 运维管理

日常维护

```bash
# 查看服务状态
systemctl status sentinelx-server

# 查看日志
journalctl -u sentinelx-server -f

# 备份数据
sentinelx-cli backup --output /backup/sentinelx-$(date +%Y%m%d).tar.gz

# 更新系统
sentinelx-cli update --version latest
```

监控指标

SentinelX 提供 Prometheus 指标：

```bash
# 访问指标端点
curl http://localhost:9090/metrics

# 主要指标
# sentinelx_connections_active     当前活跃连接数
# sentinelx_connections_total      总连接数
# sentinelx_traffic_bytes_total    总流量字节数
# sentinelx_security_events_total  安全事件总数
# sentinelx_logs_stored_total      存储的日志总数
```

🤝 开发与贡献

开发环境设置

```bash
# 1. 克隆仓库
git clone https://github.com/Blacklight139/SentinelX.git
cd SentinelX

# 2. 安装依赖
cd server
go mod download

# 3. 启动开发服务器
go run main.go --dev
```

贡献流程

1. Fork 本项目
2. 创建功能分支 (git checkout -b feature/AmazingFeature)
3. 提交更改 (git commit -m 'Add some AmazingFeature')
4. 推送到分支 (git push origin feature/AmazingFeature)
5. 创建 Pull Request

📄 许可证

本项目采用 GNU Affero General Public License v3.0 (AGPL-3.0) 许可证。

AGPL-3.0 许可证要点

· ✅ 自由使用: 可以自由使用、修改和分发本软件
· ✅ 开源要求: 任何修改后的版本必须以相同许可证开源
· ✅ 网络服务条款: 即使通过网络提供服务，也必须提供源代码
· ✅ 专利授权: 包含明确的专利授权条款

完整的许可证文本

```
SentinelX - 安全流量监控与日志系统
Copyright (C) 2024 Blacklight139

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
```

商业许可

对于需要以下场景的企业用户：

· 需要闭源修改和分发
· 需要商业技术支持
· 需要定制化开发

请联系我们获取商业许可选项。

🏆 致谢

核心贡献者

· @Blacklight139 - 项目创建者和维护者
· @Blacklight - 中文社区维护

使用的开源项目

项目 用途 许可证
Go 编程语言 BSD-3-Clause
Gorilla WebSocket WebSocket 通信 BSD-2-Clause
Gin Web 框架 MIT
GORM ORM 框架 MIT
Prometheus 监控指标 Apache-2.0

特别感谢

· Go 语言团队 - 提供优秀的编程语言和工具链
· 所有贡献者 - 感谢每一位为项目做出贡献的开发者
· 用户社区 - 感谢所有用户的反馈和支持

📞 支持与社区

文档资源

· 📖 官方文档: https://sentinelx.darkbeam.cn/docs（未开放）
· 📚 API 文档: https://api.sentinelx.darkbeam.cn/docs（未开放）

社区支持

平台 链接 描述
💬 GitHub Discussions https://github.com/Blacklight139/SentinelX/discussions 技术讨论、Q&A
🐛 GitHub Issues https://github.com/Blacklight139/SentinelX/issues Bug 报告、功能请求
💬 Gitee Issues https://gitee.com/dark-beam/SentinelX/issues 中文问题反馈

---

<div align="center">⭐ 支持我们

如果 SentinelX 对您有帮助，请给我们一个 Star！ ⭐

GitHub: https://github.com/Blacklight139/SentinelX
Gitee: https://gitee.com/dark-beam/SentinelX

SentinelX - 守护您的网络流量安全 🔒

</div>
