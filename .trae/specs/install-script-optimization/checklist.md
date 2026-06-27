# SentinelX 多平台一键安装脚本 - 验证清单

## 入口脚本验证 (install.sh)
- [ ] 自动检测操作系统类型（Linux/Windows/macOS）
- [ ] 显示友好的交互菜单
- [ ] 支持命令行参数（--docker, --binary, --uninstall, --help）
- [ ] 支持静默模式 --yes 自动确认
- [ ] 支持 Ctrl+C 中断

## Linux 安装脚本验证 (scripts/install-linux.sh)
- [ ] Ubuntu 系统安装正常
- [ ] Debian 系统安装正常
- [ ] CentOS/RHEL 系统安装正常
- [ ] Fedora 系统安装正常
- [ ] Docker 方式安装成功
- [ ] 二进制方式安装成功
- [ ] 服务启动后健康检查通过

## Windows 安装脚本验证 (scripts/install-windows.ps1)
- [ ] PowerShell 5.1+ 可正常执行
- [ ] 检测 Windows Server 版本
- [ ] Docker Desktop 方式安装成功
- [ ] 二进制方式安装成功并注册为 Windows Service

## macOS 安装脚本验证 (scripts/install-macos.sh)
- [ ] macOS 11+ 可正常执行
- [ ] 检测 macOS 版本
- [ ] Docker Desktop 方式安装成功
- [ ] 二进制方式安装成功并注册为 launchd agent

## 卸载功能验证
- [ ] Linux 标准卸载正常（保留配置）
- [ ] Linux 完全卸载正常（删除配置）
- [ ] Linux 保留数据卸载正常
- [ ] Windows 卸载正常
- [ ] macOS 卸载正常
- [ ] 卸载后无残留服务

## 安装前检查验证
- [ ] 端口占用检测正常（8443, 9090, 6060）
- [ ] 依赖检测正常
- [ ] 已安装状态检测正常
- [ ] 检测失败时正确退出

## 进度反馈验证
- [ ] 步骤计数显示
- [ ] 进度条显示
- [ ] 成功/失败图标
- [ ] --verbose 调试模式正常

## 回滚机制验证
- [ ] 安装失败时正确清理
- [ ] Ctrl+C 中断时正确清理
