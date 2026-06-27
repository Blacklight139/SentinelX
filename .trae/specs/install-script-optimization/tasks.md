# SentinelX 多平台一键安装脚本 - 实施计划

## [ ] Task 1: 多平台入口脚本开发 (install.sh)
- **Priority**: high
- **Depends On**: None
- **Description**:
  - 创建统一的入口脚本 install.sh
  - 实现操作系统自动检测（Linux/Windows/macOS）
  - 实现跨平台函数：detect_os, show_banner, show_menu, run_install, run_uninstall
  - 实现脚本下载和执行逻辑（根据检测到的系统调用对应脚本）
  - 支持命令行参数：--docker, --binary, --uninstall, --help
  - 支持静默模式 --yes 自动确认
- **Acceptance Criteria**:
  - 自动检测当前操作系统类型
  - 显示友好的交互菜单
  - 根据选择调用对应平台的安装脚本
  - 支持 Ctrl+C 中断

## [ ] Task 2: Linux 安装脚本开发 (scripts/install-linux.sh)
- **Priority**: high
- **Depends On**: Task 1
- **Description**:
  - 支持 Ubuntu/Debian (apt-get)
  - 支持 CentOS/RHEL/Rocky/Alma (yum/dnf)
  - 支持 Fedora (dnf)
  - Docker 安装：使用 docker-compose 启动完整服务栈
  - 二进制安装：下载 release 或源码编译
  - systemd 服务配置
  - 安装前检查：端口、依赖、已安装状态
  - 安装回滚机制
- **Acceptance Criteria**:
  - 所有支持的 Linux 发行版安装正常
  - Docker 和二进制两种方式都可用
  - 服务启动后健康检查通过

## [ ] Task 3: Windows 安装脚本开发 (scripts/install-windows.ps1)
- **Priority**: high
- **Depends On**: Task 1
- **Description**:
  - PowerShell 脚本，要求 5.1+
  - 检测 Windows 版本 (Windows Server 2016/2019/2022)
  - Docker Desktop for Windows 支持
  - 二进制安装为 Windows Service (使用 NSSM 或 WinSW)
  - 端口检测和依赖检查
  - 注册表清理和 Windows Service 卸载
- **Acceptance Criteria**:
  - PowerShell 5.1+ 可正常执行
  - Docker 方式安装成功
  - 二进制方式安装成功并注册为 Windows Service

## [ ] Task 4: macOS 安装脚本开发 (scripts/install-macos.sh)
- **Priority**: high
- **Depends On**: Task 1
- **Description**:
  - Bash/Zsh 脚本，兼容 macOS 11+
  - 检测 macOS 版本
  - Homebrew 检测和安装
  - Docker Desktop for Mac 支持
  - 二进制安装为 launchd agent
  - launchd agent 卸载
- **Acceptance Criteria**:
  - macOS 11+ 可正常执行
  - Docker 方式安装成功
  - 二进制方式安装成功并注册为 launchd agent

## [ ] Task 5: 卸载功能实现
- **Priority**: high
- **Depends On**: Task 2, Task 3, Task 4
- **Description**:
  - 标准卸载：停止服务、删除程序、保留配置
  - 完全卸载：删除所有文件包括配置
  - 保留数据卸载：删除程序但保留数据目录
  - 强制卸载：忽略错误，强制清理
  - 各平台独立实现清理逻辑
- **Acceptance Criteria**:
  - 三种卸载模式正常工作
  - 卸载后无残留服务或注册表项

## [ ] Task 6: 安装前检查增强
- **Priority**: medium
- **Depends On**: Task 2, Task 3, Task 4
- **Description**:
  - 端口占用检测（8443, 9090, 6060）
  - 依赖检测（curl, docker, etc.）
  - 已安装状态检测
  - 磁盘空间检查
  - 网络连接检测
- **Acceptance Criteria**:
  - 检测到问题时显示清晰错误信息并退出

## [ ] Task 7: 进度反馈和日志优化
- **Priority**: medium
- **Depends On**: Task 2, Task 3, Task 4
- **Description**:
  - 步骤计数显示（共 N 步）
  - 进度条显示
  - 成功/失败图标
  - 日志文件输出
  - 支持 --verbose 调试模式
- **Acceptance Criteria**:
  - 用户可清晰了解安装进度
  - 支持调试模式输出详细日志

## [ ] Task 8: 测试验证
- **Priority**: high
- **Depends On**: Task 1, Task 2, Task 3, Task 4, Task 5
- **Description**:
  - Linux Docker 安装测试
  - Linux 二进制安装测试
  - Linux 卸载测试
  - Windows 安装测试（模拟环境）
  - macOS 安装测试（模拟环境）
  - 跨平台脚本下载测试
- **Acceptance Criteria**:
  - 所有平台安装/卸载测试通过
