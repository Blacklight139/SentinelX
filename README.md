<p align="center">
  <img src="https://img.shields.io/badge/Go-1.25.5-00ADD8?style=for-the-badge&logo=go" alt="Go Version">
  <img src="https://img.shields.io/badge/License-AGPL%203.0-green?style=for-the-badge" alt="License">
  <img src="https://img.shields.io/github/actions/workflow/status/Blacklight139/SentinelX/go.yml?style=for-the-badge&label=CI/CD" alt="CI/CD">
  <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20Windows%20%7C%20macOS-blue?style=for-the-badge" alt="Platform">
  <img src="https://img.shields.io/github/stars/Blacklight139/SentinelX?style=for-the-badge&logo=github" alt="GitHub Stars">
</p><div align="center">
  <h1>SentinelX - 企业级安全流量监控系统(重制版)</h1>
  <p>实时检测中间商恶意操控，保护您的FRP流量安全</p>English | 中文 | 文档


  
---------------
  * 本项目开始重新编写架构代码阶段
---------------



</div>📍 双仓库同步

本项目同时在 GitHub 和 Gitee 维护，您可以根据网络状况选择最合适的平台：

平台 地址 推荐用户 特点
🌍 GitHub https://github.com/Blacklight139/SentinelX 国际用户、海外用户 完整的CI/CD、自动发布、多平台构建
🇨🇳 Gitee https://gitee.com/dark-beam/SentinelX 中国大陆用户 国内镜像、加速下载、中文社区

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

商业许可

对于需要以下场景的企业用户：

· 需要闭源修改和分发
· 需要商业技术支持
· 需要定制化开发

请联系我们获取商业许可选项。

特别感谢

· Go 语言团队 - 提供优秀的编程语言和工具链
· 所有贡献者 - 感谢每一位为项目做出贡献的开发者
· 用户社区 - 感谢所有用户的反馈和支持

📞 支持与社区

文档资源

· 📖 官方文档:（未开放）
· 📚 API 文档: （未开放）

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
