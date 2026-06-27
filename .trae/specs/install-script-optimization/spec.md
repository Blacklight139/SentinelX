# SentinelX 安装脚本优化与功能延伸 - 产品需求文档

## Why
当前的一键安装脚本虽然功能完整，但存在以下问题：
1. 缺少对已安装状态的检测（重复安装处理）
2. 缺少安装前环境检查
3. 缺少回滚机制
4. 缺少详细的安装进度反馈
5. Docker 和二进制安装流程可以更模块化

README 中声明的部分功能（如 Go Client SDK）尚未实现，需要延伸新代码。

## What Changes

### 安装脚本优化
- 优化菜单交互，增加状态检测
- 添加安装前环境检查（端口占用、依赖检测）
- 添加安装进度条和详细日志
- 添加安装回滚机制（失败时清理）
- 模块化 Docker 和二进制安装函数
- 优化卸载流程，添加更多选项（保留配置、强制卸载）
- 添加 `--verbose` 调试模式
- 添加 `--skip-confirmation` 非交互模式

### 代码延伸（按 README 要求）
- 实现 Go Client SDK 示例代码
- 添加 PostgreSQL/Redis 集成初始化代码（docker-compose 已配置但代码未集成）

## Impact
- Affected specs: code-optimization（继承其模块化成果）
- Affected code:
  - `/workspace/install.sh` - 重构优化
  - `/workspace/online_install.sh` - 同步优化
  - `/workspace/server/install.sh` - 同步优化

## ADDED Requirements

### Requirement: 增强型安装脚本
安装脚本 SHALL 提供以下功能：

#### Scenario: 全新安装
- **WHEN** 用户选择安装且系统未安装过 SentinelX
- **THEN** 执行完整安装流程，安装成功后显示访问信息

#### Scenario: 已安装检测
- **WHEN** 用户选择安装但系统已安装 SentinelX
- **THEN** 提示用户已安装，询问是否要重新安装或升级

#### Scenario: 环境检查失败
- **WHEN** 安装前检测到端口被占用或依赖缺失
- **THEN** 显示详细错误信息并退出，不执行安装

#### Scenario: 安装失败回滚
- **WHEN** 安装过程中发生错误
- **THEN** 自动清理已创建的目录和服务，恢复到安装前状态

### Requirement: 卸载脚本增强
卸载脚本 SHALL 提供以下选项：

#### Scenario: 标准卸载
- **WHEN** 用户选择卸载
- **THEN** 停止服务、删除文件、保留配置文件

#### Scenario: 完全卸载
- **WHEN** 用户选择完全卸载并确认
- **THEN** 删除所有文件包括配置文件

#### Scenario: 强制卸载
- **WHEN** 用户选择强制卸载（忽略错误）
- **THEN** 尽力删除所有相关文件和配置

## MODIFIED Requirements

### Requirement: 一键安装脚本
安装脚本 SHALL 支持以下安装方式：

#### Scenario: Docker 安装
- **GIVEN** 系统已安装 Docker
- **WHEN** 用户选择 Docker 安装
- **THEN** 使用 docker-compose 启动完整服务栈（Server + PostgreSQL + Redis + Prometheus + Grafana）

#### Scenario: 二进制安装
- **GIVEN** 系统无 Docker 或用户选择二进制安装
- **WHEN** 用户选择二进制安装
- **THEN** 下载/编译二进制，配置 systemd 服务

## Constraints
- 必须保持向后兼容，不改变现有配置格式
- 脚本必须在 Ubuntu/Debian/CentOS/RHEL/Fedora 上正常工作
- 安装路径保持不变：`/opt/sentinelx`, `/etc/sentinelx`, `/var/lib/sentinelx`
- Docker 安装使用 docker-compose v2+

## Assumptions
- 用户有 sudo 权限
- 系统有网络连接以下载依赖
- Docker 安装需要 root 权限
