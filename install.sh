#!/bin/bash
#
# SentinelX 多平台安装入口脚本
# 支持: Linux | Windows | macOS
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
REPO_GITHUB="https://raw.githubusercontent.com/Blacklight139/SentinelX/main"
REPO_GITEE="https://gitee.com/dark-beam/SentinelX/raw/main"
SCRIPT_BASE="${REPO_GITHUB}/scripts"
INSTALL_DIR="/opt/sentinelx"
CONFIG_DIR="/etc/sentinelx"
DATA_DIR="/var/lib/sentinelx"
LOG_DIR="/var/log/sentinelx"
SERVICE_NAME="sentinelx-server"

# 标志
NON-interactive=false
SKIP_CONFIRM=false

# Ctrl+C 中断处理
trap 'echo -e "\n${YELLOW}安装已中断${NC}"; exit 130' INT TERM

# 输出函数
print_banner() {
    echo -e "${CYAN}"
    echo "  ███████╗██╗   ██╗███████╗████████╗███████╗███╗   ███╗"
    echo "  ██╔════╝╚██╗ ██╔╝██╔════╝╚══██╔══╝██╔════╝████╗ ████║"
    echo "  ███████╗ ╚████╔╝ ███████╗   ██║   █████╗  ██╔████╔██║"
    echo "  ╚════██║  ╚██╔╝  ╚════██║   ██║   ██╔══╝  ██║╚██╔╝██║"
    echo "  ███████║   ██║   ███████║   ██║   ███████╗██║ ╚═╝ ██║"
    echo "  ╚══════╝   ╚═╝   ╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚═╝"
    echo -e "${NC}"
    echo -e "${BLUE}  企业级安全流量监控系统${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助
show_help() {
    print_banner
    echo -e "${GREEN}用法:${NC} $0 [选项]"
    echo ""
    echo -e "${GREEN}选项:${NC}"
    echo -e "  ${CYAN}--docker${NC}       使用 Docker 方式安装"
    echo -e "  ${CYAN}--binary${NC}       使用二进制方式安装"
    echo -e "  ${CYAN}--uninstall${NC}    卸载 SentinelX"
    echo -e "  ${CYAN}--upgrade${NC}      升级 SentinelX"
    echo -e "  ${CYAN}--yes${NC}          自动确认所有提示"
    echo -e "  ${CYAN}--help${NC}        显示此帮助信息"
    echo ""
    echo -e "${GREEN}示例:${NC}"
    echo -e "  $0                  # 交互式安装"
    echo -e "  $0 --docker         # Docker 安装（非交互）"
    echo -e "  $0 --binary --yes   # 二进制安装（自动确认）"
    echo -e "  $0 --uninstall      # 卸载"
    echo ""
}

# 检测操作系统
detect_os() {
    case "$(uname -s)" in
        Linux*)
            OS="linux"
            ;;
        Darwin*)
            OS="macos"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            OS="windows"
            ;;
        *)
            OS="unknown"
            ;;
    esac
    print_info "检测到操作系统: ${CYAN}$OS${NC}"
}

# 检测是否已安装
check_installed() {
    case "$OS" in
        linux|macos)
            if [ -f "/opt/sentinelx/bin/sentinelx-server" ] || [ -f "$HOME/sentinelx/bin/sentinelx-server" ]; then
                return 0
            fi
            if systemctl is-active --quiet sentinelx-server 2>/dev/null; then
                return 0
            fi
            return 1
            ;;
        windows)
            if [ -f "$PROGRAMFILES/SentinelX/sentinelx-server.exe" ]; then
                return 0
            fi
            return 1
            ;;
    esac
    return 1
}

# 下载脚本（支持 GitHub 和 Gitee 回退）
download_script() {
    local script_name=$1
    local dest=$2
    local source=""

    print_info "下载安装脚本: ${CYAN}$script_name${NC}"

    # 尝试 GitHub
    source="${REPO_GITHUB}/$script_name"
    if curl -fsSL "$source" -o "$dest" 2>/dev/null; then
        print_success "从 GitHub 下载成功"
        chmod +x "$dest"
        return 0
    fi

    # 回退到 Gitee
    source="${REPO_GITEE}/$script_name"
    if curl -fsSL "$source" -o "$dest" 2>/dev/null; then
        print_success "从 Gitee 下载成功"
        chmod +x "$dest"
        return 0
    fi

    print_error "无法下载脚本: $script_name"
    return 1
}

# 主菜单
show_main_menu() {
    clear
    print_banner

    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  1)${NC} 🚀 Docker 安装 (推荐 - 隔离环境，快速部署)"
    echo -e "${GREEN}  2)${NC} 📦 二进制安装 (本地安装，适合生产环境)"
    echo -e "${YELLOW}  3)${NC} 🔄 升级 SentinelX"
    echo -e "${RED}  4)${NC} 🗑️  卸载 SentinelX"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  0)${NC} ❌ 退出"
    echo ""
}

# 卸载子菜单
show_uninstall_menu() {
    clear
    print_banner

    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  卸载 SentinelX${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}  1)${NC} 标准卸载 (删除程序和配置，保留数据)"
    echo -e "${RED}  2)${NC} 完全卸载 (删除所有内容，包括数据)"
    echo -e "${YELLOW}  3)${NC} 保留数据卸载 (仅删除程序，保留配置和数据)"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  0)${NC} 返回主菜单"
    echo ""
}

# Docker 安装
do_docker_install() {
    print_info "开始 Docker 方式安装..."

    local script_file="/tmp/sentinelx-install-docker.sh"

    if download_script "scripts/install-linux.sh" "$script_file"; then
        if [ "$NON-interactive" = true ]; then
            bash "$script_file" --docker --yes
        else
            bash "$script_file" --docker
        fi
        rm -f "$script_file"
    else
        print_error "Docker 安装脚本下载失败"
        exit 1
    fi
}

# 二进制安装
do_binary_install() {
    print_info "开始二进制方式安装..."

    local script_file="/tmp/sentinelx-install-binary.sh"
    local script_name=""

    case "$OS" in
        linux)
            script_name="scripts/install-linux.sh"
            ;;
        macos)
            script_name="scripts/install-macos.sh"
            ;;
        windows)
            script_name="scripts/install-windows.ps1"
            ;;
    esac

    if [ -z "$script_name" ]; then
        print_error "不支持的操作系统: $OS"
        exit 1
    fi

    if download_script "$script_name" "$script_file"; then
        if [ "$OS" = "windows" ]; then
            if [ "$NON-interactive" = true ]; then
                powershell -ExecutionPolicy Bypass -File "$script_file" -AutoConfirm
            else
                powershell -ExecutionPolicy Bypass -File "$script_file"
            fi
        else
            if [ "$NON-interactive" = true ]; then
                bash "$script_file" --yes
            else
                bash "$script_file"
            fi
        fi
        rm -f "$script_file"
    else
        print_error "二进制安装脚本下载失败"
        exit 1
    fi
}

# 升级
do_upgrade() {
    print_info "开始升级 SentinelX..."

    if ! check_installed; then
        print_error "SentinelX 未安装，请先安装"
        echo -e "${YELLOW}提示: 运行 $0 --docker 或 $0 --binary 安装${NC}"
        exit 1
    fi

    local script_file="/tmp/sentinelx-upgrade.sh"

    case "$OS" in
        linux)
            if download_script "scripts/upgrade-linux.sh" "$script_file"; then
                if [ "$NON-interactive" = true ]; then
                    bash "$script_file" --yes
                else
                    bash "$script_file"
                fi
            fi
            ;;
        macos)
            if download_script "scripts/upgrade-macos.sh" "$script_file"; then
                if [ "$NON-interactive" = true ]; then
                    bash "$script_file" --yes
                else
                    bash "$script_file"
                fi
            fi
            ;;
        windows)
            if download_script "scripts/upgrade-windows.ps1" "$script_file"; then
                if [ "$NON-interactive" = true ]; then
                    powershell -ExecutionPolicy Bypass -File "$script_file" -AutoConfirm
                else
                    powershell -ExecutionPolicy Bypass -File "$script_file"
                fi
            fi
            ;;
    esac

    rm -f "$script_file"
}

# 卸载
do_uninstall() {
    print_info "开始卸载 SentinelX..."

    if ! check_installed; then
        print_error "SentinelX 未安装"
        exit 1
    fi

    if [ "$SKIP_CONFIRM" = false ]; then
        echo ""
        echo -e "${YELLOW}⚠️  确认要卸载 SentinelX 吗？${NC}"
        read -p "输入 'YES' 确认卸载: " confirm
        if [ "$confirm" != "YES" ]; then
            print_info "取消卸载"
            exit 0
        fi
    fi

    local script_file="/tmp/sentinelx-uninstall.sh"

    if download_script "scripts/uninstall.sh" "$script_file"; then
        if [ "$OS" = "windows" ]; then
            powershell -ExecutionPolicy Bypass -File "$script_file"
        else
            if [ "$SKIP_CONFIRM" = true ]; then
                bash "$script_file" --yes
            else
                bash "$script_file"
            fi
        fi
        rm -f "$script_file"
    else
        # 脚本下载失败，使用内置卸载
        builtin_uninstall
    fi
}

# 内置卸载（脚本下载失败时使用）
builtin_uninstall() {
    print_info "执行内置卸载程序..."

    case "$OS" in
        linux)
            systemctl stop sentinelx-server 2>/dev/null || true
            systemctl disable sentinelx-server 2>/dev/null || true
            rm -f /etc/systemd/system/sentinelx-server.service
            systemctl daemon-reload
            rm -rf /opt/sentinelx
            rm -rf /var/log/sentinelx
            ;;
        macos)
            launchctl unload ~/Library/LaunchAgents/com.sentinelx.server.plist 2>/dev/null || true
            rm -f ~/Library/LaunchAgents/com.sentinelx.server.plist
            rm -rf ~/sentinelx
            ;;
        windows)
            powershell -Command "Stop-Service -Name SentinelX -ErrorAction SilentlyContinue; Remove-Service -Name SentinelX -ErrorAction SilentlyContinue"
            rm -rf "$PROGRAMFILES/SentinelX"
            ;;
    esac

    print_success "卸载完成"
}

# 主函数
main() {
    # 解析参数
    case "${1:-}" in
        --docker|-d)
            detect_os
            do_docker_install
            ;;
        --binary|-b)
            detect_os
            do_binary_install
            ;;
        --uninstall|-u)
            detect_os
            do_uninstall
            ;;
        --upgrade|-U)
            detect_os
            do_upgrade
            ;;
        --yes|-y)
            SKIP_CONFIRM=true
            NON-interactive=true
            shift
            main "$@"
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            detect_os

            # 检查是否未安装时提示
            if ! check_installed; then
                print_warn "SentinelX 未安装"
            fi

            # 主循环
            while true; do
                show_main_menu

                if [ "$NON-interactive" = true ]; then
                    print_error "请指定操作模式: --docker, --binary, --uninstall, --upgrade, --help"
                    exit 1
                fi

                read -p "请选择 [0-4]: " choice

                case $choice in
                    1)
                        do_docker_install
                        break
                        ;;
                    2)
                        do_binary_install
                        break
                        ;;
                    3)
                        do_upgrade
                        break
                        ;;
                    4)
                        # 卸载子菜单
                        while true; do
                            show_uninstall_menu
                            read -p "请选择卸载模式 [0-3]: " uninstall_choice

                            case $uninstall_choice in
                                1)
                                    export UNINSTALL_MODE="standard"
                                    do_uninstall
                                    break 2
                                    ;;
                                2)
                                    export UNINSTALL_MODE="complete"
                                    do_uninstall
                                    break 2
                                    ;;
                                3)
                                    export UNINSTALL_MODE="keepdata"
                                    do_uninstall
                                    break 2
                                    ;;
                                0)
                                    break
                                    ;;
                                *)
                                    print_error "无效选择，请重新输入"
                                    sleep 1
                                    ;;
                            esac
                        done
                        ;;
                    0)
                        echo "再见！"
                        exit 0
                        ;;
                    *)
                        print_error "无效选择，请重新输入"
                        sleep 1
                        ;;
                esac
            done
            ;;
    esac
}

main "$@"
