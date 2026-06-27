# SentinelX 代码框架优化与功能延伸 - 实施计划

## [x] Task 1: 代码模块化重构 - 目录结构与包划分
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 创建 `server/internal/` 目录结构，将现有代码拆分为多个包
  - 包结构：`config`(配置)、`crypto`(加密)、`cache`(缓存)、`storage`(日志存储)、`models`(数据模型)
  - 保持现有功能不变，仅做代码迁移和包导出
  - main.go 仅保留入口逻辑和 Server 组装
- **Acceptance Criteria Addressed**: AC-1, AC-7, AC-10
- **Test Requirements**:
  - `programmatic` TR-1.1: `go build` 编译成功，无错误
  - `programmatic` TR-1.2: 每个文件行数不超过 500 行
  - `programmatic` TR-1.3: 使用原 config.yaml 可正常启动
  - `human-judgement` TR-1.4: 代码结构清晰，每个包职责单一，命名规范一致
- **Notes**: 先创建空包结构，再逐步迁移代码，确保每步都能编译通过

## [x] Task 2: 数据模型与工具函数抽离
- **Priority**: high
- **Depends On**: Task 1
- **Description**: 
  - 创建 `internal/models/` 包，包含 TrafficLog、AccessLog 等数据结构
  - 创建 `internal/utils/` 包，包含 generateUUID、getStack 等工具函数
  - 创建 `internal/safemap/` 包，包含 SafeMap 泛型实现
  - 创建 `internal/cache/` 包，包含 Cache 泛型实现
- **Acceptance Criteria Addressed**: AC-1, AC-10
- **Test Requirements**:
  - `programmatic` TR-2.1: 所有数据结构可正常序列化/反序列化 JSON
  - `programmatic` TR-2.2: SafeMap 和 Cache 的单元测试通过
  - `programmatic` TR-2.3: `go build` 编译成功
- **Notes**: 为基础数据结构编写简单的单元测试

## [x] Task 3: 加密系统模块抽离
- **Priority**: high
- **Depends On**: Task 2
- **Description**: 
  - 创建 `internal/crypto/` 包，包含 EncryptionSystem
  - 导出必要的方法和类型
  - 保持密钥生成、加载、加密解密功能不变
- **Acceptance Criteria Addressed**: AC-1, AC-10
- **Test Requirements**:
  - `programmatic` TR-3.1: 加密后的数据可正确解密还原
  - `programmatic` TR-3.2: 密钥文件生成格式正确（PEM）
  - `programmatic` TR-3.3: `go build` 编译成功
- **Notes**: 编写加密解密的往返测试

## [x] Task 4: 日志存储系统模块抽离
- **Priority**: high
- **Depends On**: Task 3
- **Description**: 
  - 创建 `internal/storage/` 包，包含 LogStorage
  - 导出 StoreTrafficLog 等核心方法
  - 保持加密存储和文件管理逻辑不变
- **Acceptance Criteria Addressed**: AC-1, AC-10
- **Test Requirements**:
  - `programmatic` TR-4.1: 存储日志后文件存在且可读（加密状态）
  - `programmatic` TR-4.2: 存储指标正确更新
  - `programmatic` TR-4.3: `go build` 编译成功
- **Notes**: 测试使用临时目录，避免污染环境

## [x] Task 5: WebSocketHandler 实现
- **Priority**: high
- **Depends On**: Task 4
- **Description**: 
  - 创建 `internal/ws/` 包，实现 WebSocketHandler
  - 支持客户端连接管理、心跳检测
  - 支持实时日志推送（新日志产生时主动推送）
  - 支持客户端订阅/取消订阅特定类型日志
- **Acceptance Criteria Addressed**: AC-2, AC-10
- **Test Requirements**:
  - `programmatic` TR-5.1: WebSocket 可正常建立连接
  - `programmatic` TR-5.2: 新日志产生时已连接客户端收到推送
  - `programmatic` TR-5.3: 连接断开后资源正确清理
  - `programmatic` TR-5.4: `go build` 编译成功
- **Notes**: 使用 gorilla/websocket 库，实现连接池管理

## [x] Task 6: FRP 流量监控器实现
- **Priority**: high
- **Depends On**: Task 4
- **Description**: 
  - 创建 `internal/monitor/` 包，实现 FRPMonitor
  - 支持对指定端口的流量监听（TCP 代理模式）
  - 支持基于规则的流量模式匹配检测
  - 支持启动/停止监控状态管理
  - 检测到异常时生成 TrafficLog 并存储
- **Acceptance Criteria Addressed**: AC-3, AC-9, AC-10
- **Test Requirements**:
  - `programmatic` TR-6.1: 监控可正常启动和停止
  - `programmatic` TR-6.2: 流量经过监控器时产生日志记录
  - `programmatic` TR-6.3: 匹配规则的流量产生告警级别的日志
  - `programmatic` TR-6.4: `go build` 编译成功
- **Notes**: 初期实现 TCP 流量转发+检测模式，类似简单代理

## [x] Task 7: RESTful API 处理器实现
- **Priority**: high
- **Depends On**: Task 6, Task 5
- **Description**: 
  - 创建 `internal/api/` 包，实现所有 API 处理函数
  - 实现 `handleHealthCheck` - 返回服务健康状态
  - 实现 `handleLogsAPI` - GET 获取日志列表（支持分页、筛选）
  - 实现 `handleStatsAPI` - GET 获取统计信息
  - 实现 `handleStartMonitor` - POST 启动监控
  - 实现 `handleStopMonitor` - POST 停止监控
  - 统一 JSON 响应格式
- **Acceptance Criteria Addressed**: AC-4, AC-5, AC-6, AC-10
- **Test Requirements**:
  - `programmatic` TR-7.1: GET /api/v1/health 返回 200 和正确 JSON
  - `programmatic` TR-7.2: GET /api/v1/logs 返回日志列表 JSON
  - `programmatic` TR-7.3: GET /api/v1/stats 返回统计数据 JSON
  - `programmatic` TR-7.4: POST /api/v1/monitor/start 启动成功
  - `programmatic` TR-7.5: POST /api/v1/monitor/stop 停止成功
  - `programmatic` TR-7.6: `go build` 编译成功
- **Notes**: 所有响应使用统一的 JSON 格式 { "code": 0, "message": "ok", "data": ... }

## [x] Task 8: 认证中间件实现
- **Priority**: medium
- **Depends On**: Task 7
- **Description**: 
  - 实现 Bearer Token 认证中间件
  - 从配置读取允许的 Token 列表
  - 对需要认证的 API 端点进行 Token 校验
  - 健康检查端点不需要认证
  - 无效 Token 返回 401
- **Acceptance Criteria Addressed**: AC-8, AC-10
- **Test Requirements**:
  - `programmatic` TR-8.1: 带有效 Token 的请求正常通过
  - `programmatic` TR-8.2: 不带 Token 的受保护请求返回 401
  - `programmatic` TR-8.3: 带无效 Token 的请求返回 401
  - `programmatic` TR-8.4: 健康检查端点无需认证
  - `programmatic` TR-8.5: `go build` 编译成功
- **Notes**: 初期使用配置文件中的静态 Token 列表，后续可扩展为用户系统

## [x] Task 9: 告警系统框架实现
- **Priority**: medium
- **Depends On**: Task 6
- **Description**: 
  - 创建 `internal/alert/` 包，实现告警规则引擎
  - 支持从配置加载检测规则
  - 支持按规则匹配流量并生成告警事件
  - 告警事件存储到日志系统
  - 提供告警查询 API（集成到 handleLogsAPI 或新增 endpoint）
- **Acceptance Criteria Addressed**: AC-9, AC-10
- **Test Requirements**:
  - `programmatic` TR-9.1: 配置中的规则可正确加载
  - `programmatic` TR-9.2: 匹配规则的流量生成告警事件
  - `programmatic` TR-9.3: 不匹配的流量不生成告警
  - `programmatic` TR-9.4: `go build` 编译成功
- **Notes**: 规则支持 severity 分级（low/medium/high/critical）

## [x] Task 10: 服务器组装与 main.go 精简
- **Priority**: high
- **Depends On**: Task 8, Task 9
- **Description**: 
  - 精简 main.go，仅保留命令行解析和 Server 启动
  - Server 结构体使用内部包的组件进行组装
  - 保持所有命令行参数不变
  - 确保配置加载、目录创建、服务启动流程完整
- **Acceptance Criteria Addressed**: AC-1, AC-7, AC-10
- **Test Requirements**:
  - `programmatic` TR-10.1: `go build` 编译成功
  - `programmatic` TR-10.2: 使用 --version 显示版本信息
  - `programmatic` TR-10.3: 使用 --generate-keys 生成密钥
  - `programmatic` TR-10.4: 使用 --config 指定配置可正常启动
  - `programmatic` TR-10.5: main.go 文件行数小于 200 行
- **Notes**: 确保重构前后的命令行接口完全一致

## [x] Task 11: 基准测试与性能验证
- **Priority**: medium
- **Depends On**: Task 10
- **Description**: 
  - 更新 benchmark_test.go，适配新的包结构
  - 运行基准测试，确保性能不下降
  - 验证加密、缓存、SafeMap 等核心组件性能
- **Acceptance Criteria Addressed**: AC-10
- **Test Requirements**:
  - `programmatic` TR-11.1: `go test -bench=.` 运行成功
  - `programmatic` TR-11.2: 所有基准测试无崩溃或错误
  - `human-judgement` TR-11.3: 性能与重构前相当（无显著下降）
- **Notes**: 基准测试使用临时目录，不影响正式数据

## [x] Task 12: 配置文件更新与文档同步
- **Priority**: medium
- **Depends On**: Task 10
- **Description**: 
  - 更新 config.yaml.example，添加新增的配置项（auth tokens、alert rules 等）
  - 确保配置文件有合理的默认值
  - 配置向后兼容，缺失的配置项使用默认值
- **Acceptance Criteria Addressed**: AC-7, AC-10
- **Test Requirements**:
  - `programmatic` TR-12.1: 使用旧版配置文件可正常启动（向后兼容）
  - `programmatic` TR-12.2: 使用新版完整配置文件所有功能正常
  - `programmatic` TR-12.3: 缺失配置项时有合理默认值
- **Notes**: 配置加载时设置默认值，确保旧配置不报错
