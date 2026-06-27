# SentinelX 代码框架优化与功能延伸 - 产品需求文档

## Overview
- **Summary**: 对 SentinelX 服务端代码进行框架优化（模块化重构），并根据 README 中已声明的功能延伸实现缺失的核心组件，包括 WebSocket 处理、FRP 流量监控、RESTful API 处理器、告警系统等。
- **Purpose**: 当前代码所有逻辑集中在单个 main.go 文件中，多个核心组件（WebSocketHandler、FRPMonitor、API handlers）仅有声明无实现，需要重构为清晰的模块化架构并补全功能，使项目达到 README 所承诺的可用状态。
- **Target Users**: 项目开发者、运维人员、安全团队

## Goals
- 将单文件代码重构为清晰的模块化目录结构
- 实现所有 README 中声明但缺失的核心功能组件
- 保持向后兼容，不破坏现有配置接口
- 提升代码可维护性和可测试性
- 确保所有 API 端点可用且行为符合预期

## Non-Goals (Out of Scope)
- 不改变编程语言（保持 Go）
- 不重写已有的加密系统和日志存储逻辑
- 不实现 README 中标注为"开发中"或"规划中"的功能（三端互通、机器学习检测、分布式部署）
- 不引入新的前端界面
- 不改变许可证

## Background & Context
- 当前项目代码全部位于 [main.go](file:///workspace/server/main.go)（约 886 行），包含配置、加密、缓存、日志存储、服务器等所有逻辑
- 以下组件仅有类型/变量声明，无具体实现：
  - `WebSocketHandler` - WebSocket 连接处理器
  - `FRPMonitor` - FRP 流量监控器
  - `handleLogsAPI` - 日志 API 处理函数
  - `handleStatsAPI` - 统计 API 处理函数
  - `handleStartMonitor` - 启动监控 API
  - `handleStopMonitor` - 停止监控 API
  - `handleHealthCheck` - 健康检查 API
- README 中承诺的功能包括：RESTful API、Prometheus 集成、智能告警系统、FRP 流量监控
- docker-compose.yml 中配置了 PostgreSQL、Redis、Prometheus、Grafana，但代码中尚未集成
- 使用 Go 1.25，已利用泛型特性实现 SafeMap 和 Cache

## Functional Requirements

- **FR-1**: 代码模块化重构 - 将 main.go 拆分为多个职责单一的包/文件
- **FR-2**: WebSocket 处理器实现 - 实现 WebSocket 实时日志推送和客户端通信
- **FR-3**: FRP 流量监控器实现 - 实现 FRP 端口流量监听和异常检测
- **FR-4**: RESTful API 完整实现 - 实现所有声明的 API 端点处理函数
- **FR-5**: 健康检查端点 - 实现 /api/v1/health 端点
- **FR-6**: 告警系统基础框架 - 实现基于规则的异常检测和告警机制
- **FR-7**: 认证系统基础 - 实现 API 访问认证中间件

## Non-Functional Requirements

- **NFR-1**: 代码可维护性 - 每个模块职责单一，文件不超过 500 行
- **NFR-2**: 向后兼容 - 配置文件格式和命令行参数保持不变
- **NFR-3**: 可测试性 - 核心模块具备单元测试能力
- **NFR-4**: 性能 - 重构后性能不低于现有实现
- **NFR-5**: 安全性 - 所有 API 访问需认证，敏感操作需鉴权

## Constraints
- **Technical**: 
  - 必须使用 Go 1.25+
  - 保持现有依赖（gorilla/websocket, prometheus, logrus, yaml.v3）
  - 不引入额外的大型框架（如 Gin），保持标准库 + 轻量依赖的风格
- **Business**: 
  - 保持 AGPL-3.0 许可证
  - 配置接口不变，确保现有用户平滑升级
- **Dependencies**: 
  - gorilla/websocket v1.5.2
  - prometheus/client_golang v1.20.0
  - sirupsen/logrus v1.9.3
  - yaml.v3 v3.0.1

## Assumptions
- 用户使用 config.yaml 配置文件启动服务
- TLS 证书通过 generate_keys.sh 或 openssl 生成
- FRP 监控基于网络端口监听和流量模式分析
- 告警系统初期基于规则匹配，不涉及机器学习
- 认证使用 Token 机制（Bearer Token）

## Acceptance Criteria

### AC-1: 模块化代码结构
- **Given**: 现有单文件 main.go 代码
- **When**: 完成重构后
- **Then**: 代码被拆分为多个包/文件，每个模块职责清晰，单个文件不超过 500 行
- **Verification**: `programmatic`
- **Notes**: 检查目录结构和文件行数

### AC-2: WebSocket 连接可用
- **Given**: 服务已启动
- **When**: 客户端通过 /ws 建立 WebSocket 连接
- **Then**: 连接成功建立，可接收实时日志推送
- **Verification**: `programmatic`
- **Notes**: 使用 WebSocket 客户端测试连接和消息收发

### AC-3: FRP 监控可启动/停止
- **Given**: 服务已启动，提供目标端口
- **When**: 调用 /api/v1/monitor/start 启动监控
- **Then**: 返回成功，监控状态变为 active；调用 stop 后状态变为 stopped
- **Verification**: `programmatic`
- **Notes**: 通过 API 测试启停功能

### AC-4: 日志 API 可用
- **Given**: 服务已启动且有日志数据
- **When**: 调用 GET /api/v1/logs
- **Then**: 返回日志列表，支持分页和筛选
- **Verification**: `programmatic`

### AC-5: 统计 API 可用
- **Given**: 服务已运行一段时间
- **When**: 调用 GET /api/v1/stats
- **Then**: 返回连接数、流量、安全事件等统计数据
- **Verification**: `programmatic`

### AC-6: 健康检查端点
- **Given**: 服务正常运行
- **When**: 调用 GET /api/v1/health
- **Then**: 返回 200 状态码和健康状态信息
- **Verification**: `programmatic`

### AC-7: 配置兼容性
- **Given**: 现有 config.yaml 配置文件
- **When**: 使用相同配置启动重构后的服务
- **Then**: 服务正常启动，所有配置项生效
- **Verification**: `programmatic`

### AC-8: 认证中间件
- **Given**: 服务已启动，需要认证的 API
- **When**: 请求不带有效 Token
- **Then**: 返回 401 Unauthorized
- **Verification**: `programmatic`

### AC-9: 告警规则检测
- **Given**: 服务运行中，配置了检测规则
- **When**: 流量匹配告警规则
- **Then**: 生成告警事件并记录
- **Verification**: `programmatic`

### AC-10: 代码可编译通过
- **Given**: 重构后的代码
- **When**: 执行 go build
- **Then**: 编译成功，无错误
- **Verification**: `programmatic`

## Open Questions
- [ ] 认证系统是否需要完整的用户管理（注册/修改密码），还是仅需静态 Token？
- [ ] FRP 监控是主动监听端口还是被动接收 FRP 日志？
- [ ] 告警通知渠道（邮件/短信/Webhook）是否需要实现？
- [ ] 是否需要集成 PostgreSQL 和 Redis（docker-compose 已配置但代码未用）？
