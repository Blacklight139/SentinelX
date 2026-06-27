# SentinelX 多平台一键安装脚本 - 产品需求文档

## Why
用户需要一个统一的一键安装脚本，能够：
1. 自动检测当前操作系统（Windows Server、Ubuntu、Debian、macOS 等）
2. 显示友好的交互菜单
3. 根据检测结果调用对应平台的安装脚本
4. 支持 Docker 和二进制两种安装方式
5. 支持卸载功能

## What Changes

### 多平台入口脚本 (install.sh)
- 自动检测操作系统类型（Linux 发行版、Windows、macOS）
- 显示统一的交互菜单
- 根据选择的安装方式和检测到的系统，调用对应脚本

### 平台检测逻辑
| 检测结果 | 调用脚本 |
|---------|---------|
| Ubuntu/Debian | install-linux.sh (Bash) |
| CentOS/RHEL/Rocky/Alma | install-linux.sh (Bash) |
| Fedora | install-linux.sh (Bash) |
| Windows Server | install-windows.ps1 (PowerShell) |
| macOS | install-macos.sh (Bash/Zsh) |

### 交互菜单选项
```
╔═══════════════════════════════════════════════════════════════╗
║                    SentinelX 安装程序                         ║
╠═══════════════════════════════════════════════════════════════╣
║  检测到系统: Ubuntu 22.04 LTS                                 ║
╠═══════════════════════════════════════════════════════════════╣
║  1) 🚀 Docker 安装 (推荐 - 隔离环境，快速部署)                 ║
║  2) 📦 二进制安装 (本地安装，适合生产环境)                     ║
║  3) 🔄 升级 SentinelX                                         ║
║  4) 🗑️  卸载 SentinelX                                        ║
║  ─────────────────────────────────────────────────────────── ║
║  0) ❌ 退出                                                   ║
╚═══════════════════════════════════════════════════════════════╝
请选择 [0-4]:
```

### 卸载菜单选项
```
╔═══════════════════════════════════════════════════════════════╗
║                    SentinelX 卸载程序                         ║
╠═══════════════════════════════════════════════════════════════╣
║  1) 🔹 标准卸载 - 保留配置文件                                ║
║  2) 🔸 完全卸载 - 删除所有文件（包括配置）                    ║
║  3) 💾 保留数据卸载 - 保留数据目录                            ║
║  ─────────────────────────────────────────────────────────── ║
║  0) ↩️ 返回主菜单                                            ║
╚═══════════════════════════════════════════════════════════════╝
```

## Impact
- Affected specs: code-optimization
- Affected code:
  - `/workspace/install.sh` - 多平台入口脚本（重构）
  - `/workspace/scripts/install-linux.sh` - Linux 安装脚本（新增）
  - `/workspace/scripts/install-windows.ps1` - Windows 安装脚本（新增）
  - `/workspace/scripts/install-macos.sh` - macOS 安装脚本（新增）

## ADDED Requirements

### Requirement: 系统自动检测
脚本 SHALL 自动检测以下操作系统：

#### Scenario: Linux 检测
- **WHEN** 在 Linux 系统执行 install.sh
- **THEN** 检测发行版（Ubuntu/Debian/CentOS/RHEL/Fedora）并显示

#### Scenario: Windows 检测
- **WHEN** 在 Windows 系统执行 install.ps1 或 .\install.bat
- **THEN** 检测 Windows 版本并显示

#### Scenario: macOS 检测
- **WHEN** 在 macOS 系统执行 install.sh
- **THEN** 检测 macOS 版本并显示

### Requirement: 交互式菜单
菜单 SHALL 提供以下功能：

#### Scenario: 主菜单显示
- **WHEN** 用户运行安装脚本
- **THEN** 显示检测到的系统、版本和可用选项

#### Scenario: 安装选项
- **WHEN** 用户选择安装选项
- **THEN** 调用对应平台的安装函数

#### Scenario: 升级选项
- **WHEN** 用户选择升级
- **THEN** 检测已安装版本并提示升级

#### Scenario: 卸载选项
- **WHEN** 用户选择卸载
- **THEN** 显示卸载选项菜单，确认后执行

### Requirement: 跨平台一致性
所有平台 SHALL 保持一致：
- 相同的菜单交互体验
- 相同的配置格式
- 相同的 API 接口
- 相同的日志格式

## Constraints
- 入口脚本 (install.sh) 需要 Bash 兼容环境
- Windows 脚本需要 PowerShell 5.1+
- macOS 脚本需要 macOS 11+
- 所有平台需要网络连接以下载依赖

## Assumptions
- 用户有管理员/root/sudo 权限
- 系统有网络连接
- Docker 安装需要对应平台的 Docker Desktop（Windows/macOS）
