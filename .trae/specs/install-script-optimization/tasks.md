# SentinelX 安装脚本优化与功能延伸 - 实施计划

## [ ] Task 1: 安装脚本重构 - 模块化函数设计
- **Priority**: high
- **Depends On**: None
- **Description**:
  - 重构 install.sh，将安装逻辑拆分为独立函数
  - 设计公共函数库：日志输出、颜色定义、环境检测
  - 设计安装函数：pre_install_check, install_docker, install_binary, post_install
  - 设计卸载函数：pre_uninstall, uninstall_service, uninstall_docker, cleanup_files
  - 支持多平台检测（Linux/Windows/macOS）
- **Acceptance Criteria**:
  - 每个函数职责单一，可独立测试
  - 支持 `--verbose` 调试模式
  - 支持 `--skip-confirmation` 非交互模式
  - 可检测当前操作系统类型

## [ ] Task 2: 安装前检查增强
- **Priority**: high
- **Depends On**: Task 1
- **Description**:
  - 添加端口占用检测（8443, 9090, 6060）
  - 添加依赖检测（curl, wget, tar, openssl, docker 等）
  - 添加已安装状态检测
  - 添加磁盘空间检查
  - 添加网络连接检测
  - Windows: 检测 PowerShell 版本、Docker Desktop、端口占用
  - macOS: 检测 Homebrew、Docker Desktop、端口占用
- **Acceptance Criteria**:
  - 检测到问题时报错退出，不继续安装
  - 显示清晰的错误信息和解决建议

## [ ] Task 3: 安装进度与反馈优化
- **Priority**: medium
- **Depends On**: Task 1
- **Description**:
  - 添加安装步骤计数（共 N 步）
  - 添加进度条显示
  - 优化日志输出格式
  - 添加成功/失败状态图标
- **Acceptance Criteria**:
  - 用户可清晰了解安装进度
  - 成功/失败状态一目了然

## [ ] Task 4: 安装回滚机制
- **Priority**: high
- **Depends On**: Task 2
- **Description**:
  - 记录安装过程中创建的文件和目录
  - 安装失败时自动清理
  - 支持 Ctrl+C 中断并清理
  - 卸载时正确清理所有创建的资源
- **Acceptance Criteria**:
  - 安装失败后可完全回滚，无残留
  - 中断安装后无残留文件

## [ ] Task 5: 卸载功能增强
- **Priority**: high
- **Depends On**: Task 1
- **Description**:
  - 添加 `--remove-config` 完全卸载选项
  - 添加 `--force` 强制卸载选项
  - 添加 `--keep-data` 保留数据选项
  - 改进卸载确认提示
  - 卸载后显示清理建议
  - Windows: 清理注册表、Windows 服务
  - macOS: 清理 launchd agents
- **Acceptance Criteria**:
  - 支持三种卸载模式：标准、完全、保留数据
  - 卸载后无残留服务

## [ ] Task 6: Docker 安装流程优化
- **Priority**: high
- **Depends On**: Task 1, Task 2
- **Description**:
  - 优化 Docker 检测和安装流程
  - 支持 Docker Compose V2 (docker compose)
  - 添加镜像拉取进度显示
  - 优化容器启动等待逻辑
  - 添加健康检查验证
  - Windows: 安装 Docker Desktop 配置
  - macOS: 安装 Docker Desktop 配置
- **Acceptance Criteria**:
  - Docker 方式安装成功
  - 服务启动后健康检查通过

## [ ] Task 7: 二进制安装流程优化
- **Priority**: high
- **Depends On**: Task 1, Task 2
- **Description**:
  - 优化版本检测和下载逻辑
  - 添加 SHA256 校验
  - 优化密钥生成流程
  - 改进服务配置（Linux: systemd, Windows: Windows Service, macOS: launchd）
  - 添加服务启动验证
- **Acceptance Criteria**:
  - 二进制方式安装成功
  - 服务启动后健康检查通过

## [ ] Task 8: Windows Server 安装脚本开发
- **Priority**: high
- **Depends On**: Task 1-7
- **Description**:
  - 创建 install-windows.ps1 PowerShell 脚本
  - 实现跨平台检测逻辑
  - 支持 Docker Desktop for Windows
  - 支持二进制方式安装为 Windows Service
  - 实现 Windows 特定清理逻辑
- **Acceptance Criteria**:
  - PowerShell 5.1+ 可正常执行
  - Docker 方式安装成功
  - 二进制方式安装成功并注册为 Windows Service
  - 卸载干净，无残留

## [ ] Task 9: macOS 安装脚本开发
- **Priority**: high
- **Depends On**: Task 1-7
- **Description**:
  - 创建 install-macos.sh Bash/Zsh 脚本
  - 实现 Homebrew 检测和安装
  - 支持 Docker Desktop for Mac
  - 支持二进制方式安装为 launchd agent
  - 实现 macOS 特定清理逻辑
- **Acceptance Criteria**:
  - macOS 11+ 可正常执行
  - Docker 方式安装成功
  - 二进制方式安装成功并注册为 launchd agent
  - 卸载干净，无残留

## [ ] Task 10: 在线安装脚本同步
- **Priority**: medium
- **Depends On**: Task 8, Task 9
- **Description**:
  - 将 Linux 优化同步到 online_install.sh
  - 确保所有脚本功能一致
  - 添加 Go 1.25 安装支持（如果需要）
- **Acceptance Criteria**:
  - online_install.sh 包含所有优化
  - 可通过 curl 远程执行

## [ ] Task 11: 测试验证
- **Priority**: high
- **Depends On**: Task 6, Task 7, Task 8, Task 9
- **Description**:
  - 测试 Linux Docker 安装流程
  - 测试 Linux 二进制安装流程
  - 测试 Windows Docker 安装流程（如果有环境）
  - 测试 Windows 二进制安装流程（如果有环境）
  - 测试 macOS Docker 安装流程（如果有环境）
  - 测试 macOS 二进制安装流程（如果有环境）
  - 测试卸载流程（标准、完全、保留数据）
  - 测试安装回滚机制
- **Acceptance Criteria**:
  - 所有平台安装方式测试通过
  - 所有卸载方式测试通过
  - 回滚机制正常工作
