#!/bin/bash
#
# SentinelX 多平台安装入口脚本
# 支持: Linux | Windows | macOS
#

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 1: 基础配置与全局变量
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -e

# 脚本元数据
SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="$(basename "$0")"

# 仓库配置
REPO_GITHUB="https://raw.githubusercontent.com/Blacklight139/SentinelX/main"
REPO_GITEE="https://gitee.com/dark-beam/SentinelX/raw/main"
SCRIPT_BASE="${REPO_GITHUB}/scripts"

# 目录配置
INSTALL_DIR="/opt/sentinelx"
CONFIG_DIR="/etc/sentinelx"
DATA_DIR="/var/lib/sentinelx"
LOG_DIR="/var/log/sentinelx"
SERVICE_NAME="sentinelx-server"

# 必需的端口
REQUIRED_PORTS=(8443 9090 6060)

# 必需的依赖
REQUIRED_DEPS=(curl wget tar openssl)

# 最小磁盘空间要求 (MB)
MIN_DISK_SPACE=500

# 操作系统检测
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
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 2: 颜色与输出函数 (通用工具)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# 图标定义
ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_WARN="⚠️"
ICON_INFO="ℹ️"
ICON_ROCKET="🚀"
ICON_PACKAGE="📦"
ICON_UPDATE="🔄"
ICON_TRASH="🗑️"
ICON_EXIT="❌"

# 全局标志
VERBOSE=false
SKIP_CONFIRM=false
REMOVE_CONFIG=false
FORCE_MODE=false
KEEP_DATA=false
NON_INTERACTIVE=false
STEP_COUNT=0
STEP_TOTAL=6

# 调试输出
debug_log() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${MAGENTA}[DEBUG]${NC} $1"
    fi
}

# Banner 输出
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

# 步骤输出 (带计数器)
print_step() {
    STEP_COUNT=$((STEP_COUNT + 1))
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}[$STEP_COUNT/$STEP_TOTAL]${NC} $1"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 信息输出
print_info() {
    echo -e "${BLUE}${ICON_INFO} [INFO]${NC} $1"
}

# 成功输出
print_success() {
    echo -e "${GREEN}${ICON_SUCCESS} [SUCCESS]${NC} $1"
}

# 警告输出
print_warn() {
    echo -e "${YELLOW}${ICON_WARN} [WARNING]${NC} $1"
}

# 错误输出
print_error() {
    echo -e "${RED}${ICON_ERROR} [ERROR]${NC} $1"
}

# 进度条
show_progress() {
    local current=$1
    local total=$2
    local title=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    printf "\r${YELLOW}${title}:${NC} ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %d%%" "$percent"
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 3: Trap 与回滚机制
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 回滚函数
ROLLBACK_STACK=""

rollback_push() {
    ROLLBACK_STACK="$1|$ROLLBACK_STACK"
    debug_log "注册回滚: $1"
}

rollback_execute() {
    print_warn "执行回滚机制..."
    IFS='|' read -ra STACK <<< "$ROLLBACK_STACK"
    for cmd in "${STACK[@]}"; do
        if [ -n "$cmd" ]; then
            debug_log "执行回滚: $cmd"
            eval "$cmd" 2>/dev/null || true
        fi
    done
    ROLLBACK_STACK=""
}

cleanup_on_failure() {
    print_error "安装失败，正在清理..."
    rollback_execute
    print_warn "回滚完成，已恢复系统状态"
}

# 设置故障陷阱
setup_traps() {
    trap 'print_error "安装被中断"; rollback_execute; exit 130' INT TERM
    trap 'cleanup_on_failure' ERR
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 4: 预安装检查
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 网络连接检查
check_network() {
    print_info "检查网络连接..."
    if curl -sf --connect-timeout 5 "$REPO_GITHUB/README.md" > /dev/null 2>&1; then
        print_success "网络连接正常 (GitHub)"
        NETWORK_SOURCE="github"
        return 0
    elif curl -sf --connect-timeout 5 "$REPO_GITEE/README.md" > /dev/null 2>&1; then
        print_success "网络连接正常 (Gitee)"
        NETWORK_SOURCE="gitee"
        return 0
    else
        print_warn "无法连接到仓库服务器"
        return 1
    fi
}

# 端口检查
check_ports() {
    print_info "检查端口占用情况..."
    local ports_in_use=()
    local all_free=true

    for port in "${REQUIRED_PORTS[@]}"; do
        if command -v ss &> /dev/null; then
            if ss -tuln 2>/dev/null | grep -q ":$port "; then
                ports_in_use+=("$port")
                all_free=false
            fi
        elif command -v netstat &> /dev/null; then
            if netstat -tuln 2>/dev/null | grep -q ":$port "; then
                ports_in_use+=("$port")
                all_free=false
            fi
        else
            if curl -sf "http://localhost:$port" > /dev/null 2>&1; then
                ports_in_use+=("$port")
                all_free=false
            fi
        fi
    done

    if [ "$all_free" = true ]; then
        print_success "所有必需端口可用: ${REQUIRED_PORTS[*]}"
        return 0
    else
        print_warn "以下端口已被占用: ${ports_in_use[*]}"
        if [ "$FORCE_MODE" = false ]; then
            print_info "使用 --force 跳过此检查"
            return 1
        fi
        return 0
    fi
}

# 依赖检查
check_dependencies() {
    print_info "检查系统依赖..."
    local missing_deps=()

    for dep in "${REQUIRED_DEPS[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -eq 0 ]; then
        print_success "所有必需依赖已安装"
        return 0
    else
        print_warn "缺少以下依赖: ${missing_deps[*]}"
        print_info "请安装后再试，或使用 --force 跳过"
        if [ "$FORCE_MODE" = false ]; then
            return 1
        fi
    fi
    return 0
}

# Docker 检查
check_docker() {
    print_info "检查 Docker 环境..."
    if command -v docker &> /dev/null; then
        if docker ps &> /dev/null; then
            print_success "Docker 已安装并运行"
            return 0
        else
            print_warn "Docker 已安装但未运行"
            if [ "$FORCE_MODE" = false ]; then
                print_info "请启动 Docker 后再试"
                return 1
            fi
        fi
    else
        print_warn "Docker 未安装"
        if [ "$FORCE_MODE" = false ]; then
            print_info "如需 Docker 安装，请先安装 Docker"
            return 1
        fi
    fi
    return 0
}

# 磁盘空间检查
check_disk_space() {
    print_info "检查磁盘空间..."
    local available_space

    case "$OS" in
        linux)
            available_space=$(df -m "$INSTALL_DIR" 2>/dev/null | awk 'NR==2 {print $4}')
            ;;
        macos)
            available_space=$(df -m "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')
            ;;
        windows)
            available_space=$(wmic logicaldisk get size,freespace 2>/dev/null | awk 'NR>1 {print $2/1024/1024}' | head -1)
            ;;
    esac

    available_space=${available_space:-0}

    if [ "$available_space" -ge "$MIN_DISK_SPACE" ]; then
        print_success "磁盘空间充足: ${available_space}MB 可用"
        return 0
    else
        print_error "磁盘空间不足: 需要至少 ${MIN_DISK_SPACE}MB，当前 ${available_space}MB 可用"
        return 1
    fi
}

# 已安装检查
check_installed() {
    print_info "检查安装状态..."
    local installed=false

    case "$OS" in
        linux|macos)
            if [ -f "/opt/sentinelx/bin/sentinelx-server" ] || [ -f "$HOME/sentinelx/bin/sentinelx-server" ]; then
                installed=true
            elif systemctl is-active --quiet sentinelx-server 2>/dev/null; then
                installed=true
            elif [ -d "$INSTALL_DIR" ]; then
                installed=true
            fi
            ;;
        windows)
            if [ -f "$PROGRAMFILES/SentinelX/sentinelx-server.exe" ]; then
                installed=true
            fi
            ;;
    esac

    if [ "$installed" = true ]; then
        if [ "$FORCE_MODE" = false ]; then
            print_warn "SentinelX 已安装"
            print_info "使用 --force 强制重新安装"
            return 0
        else
            print_warn "检测到已安装，将执行覆盖安装"
            return 0
        fi
    else
        print_success "未检测到已安装的 SentinelX"
        return 1
    fi
}

# 运行所有预检查
run_preinstall_checks() {
    print_step "执行预安装检查"

    local checks_passed=true

    # 网络检查
    check_network || checks_passed=false

    # 端口检查
    if ! check_ports; then
        [ "$FORCE_MODE" = false ] && checks_passed=false
    fi

    # 依赖检查
    if ! check_dependencies; then
        [ "$FORCE_MODE" = false ] && checks_passed=false
    fi

    # 磁盘空间检查
    if ! check_disk_space; then
        checks_passed=false
    fi

    # 已安装检查 (警告性检查)
    check_installed

    if [ "$checks_passed" = false ]; then
        print_error "部分预检查未通过"
        print_info "使用 --force 强制继续"
        return 1
    fi

    print_success "所有预检查通过"
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 5: 下载与脚本管理
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 下载脚本 (支持 GitHub 和 Gitee 回退)
download_script() {
    local script_name=$1
    local dest=$2
    local source=""

    print_info "下载安装脚本: ${CYAN}$script_name${NC}"

    # 选择源
    if [ "$NETWORK_SOURCE" = "gitee" ]; then
        source="${REPO_GITEE}/$script_name"
        if ! curl -fsSL "$source" -o "$dest" 2>/dev/null; then
            source="${REPO_GITHUB}/$script_name"
        fi
    else
        source="${REPO_GITHUB}/$script_name"
        if ! curl -fsSL "$source" -o "$dest" 2>/dev/null; then
            source="${REPO_GITEE}/$script_name"
        fi
    fi

    if curl -fsSL "$source" -o "$dest" 2>/dev/null; then
        print_success "脚本下载成功"
        chmod +x "$dest"
        return 0
    fi

    print_error "无法下载脚本: $script_name"
    return 1
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 6: Docker 安装
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

do_docker_install() {
    print_step "${ICON_ROCKET} Docker 安装模式"
    print_info "开始 Docker 方式安装..."

    # 检查 Docker
    if ! check_docker; then
        if [ "$FORCE_MODE" = false ]; then
            print_error "Docker 安装检查未通过"
            exit 1
        fi
    fi

    local script_file="/tmp/sentinelx-install-docker.sh"

    if download_script "scripts/install-linux.sh" "$script_file"; then
        local install_cmd="bash \"$script_file\" --docker"
        [ "$SKIP_CONFIRM" = true ] && install_cmd="$install_cmd --yes"
        [ "$VERBOSE" = true ] && install_cmd="$install_cmd --verbose"

        if eval "$install_cmd"; then
            print_success "Docker 安装完成"
        else
            print_error "Docker 安装失败"
            rm -f "$script_file"
            exit 1
        fi
        rm -f "$script_file"
    else
        print_error "Docker 安装脚本下载失败"
        exit 1
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 7: 二进制安装
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

do_binary_install() {
    print_step "${ICON_PACKAGE} 二进制安装模式"
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
        *)
            print_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac

    if [ -z "$script_name" ]; then
        print_error "无法确定安装脚本"
        exit 1
    fi

    if download_script "$script_name" "$script_file"; then
        local install_cmd=""
        case "$OS" in
            windows)
                install_cmd="powershell -ExecutionPolicy Bypass -File \"$script_file\""
                [ "$SKIP_CONFIRM" = true ] && install_cmd="$install_cmd -AutoConfirm"
                ;;
            *)
                install_cmd="bash \"$script_file\""
                [ "$SKIP_CONFIRM" = true ] && install_cmd="$install_cmd --yes"
                ;;
        esac
        [ "$VERBOSE" = true ] && install_cmd="$install_cmd --verbose"

        if eval "$install_cmd"; then
            print_success "二进制安装完成"
        else
            print_error "二进制安装失败"
            rm -f "$script_file"
            exit 1
        fi
        rm -f "$script_file"
    else
        print_error "二进制安装脚本下载失败"
        exit 1
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 8: 升级功能
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

do_upgrade() {
    print_step "${ICON_UPDATE} 升级 SentinelX"

    if ! check_installed; then
        print_error "SentinelX 未安装，请先安装"
        echo -e "${YELLOW}提示: 运行 $0 --docker 或 $0 --binary 安装${NC}"
        exit 1
    fi

    print_info "开始升级 SentinelX..."

    local script_file="/tmp/sentinelx-upgrade.sh"
    local script_name=""

    case "$OS" in
        linux)
            script_name="scripts/upgrade-linux.sh"
            ;;
        macos)
            script_name="scripts/upgrade-macos.sh"
            ;;
        windows)
            script_name="scripts/upgrade-windows.ps1"
            ;;
    esac

    if [ -z "$script_name" ]; then
        print_error "无法确定升级脚本"
        exit 1
    fi

    if download_script "$script_name" "$script_file"; then
        local upgrade_cmd=""
        case "$OS" in
            windows)
                upgrade_cmd="powershell -ExecutionPolicy Bypass -File \"$script_file\""
                [ "$SKIP_CONFIRM" = true ] && upgrade_cmd="$upgrade_cmd -AutoConfirm"
                ;;
            *)
                upgrade_cmd="bash \"$script_file\""
                [ "$SKIP_CONFIRM" = true ] && upgrade_cmd="$upgrade_cmd --yes"
                ;;
        esac
        [ "$VERBOSE" = true ] && upgrade_cmd="$upgrade_cmd --verbose"

        if eval "$upgrade_cmd"; then
            print_success "升级完成"
        else
            print_error "升级失败"
            rm -f "$script_file"
            exit 1
        fi
        rm -f "$script_file"
    else
        print_error "升级脚本下载失败"
        exit 1
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 9: 卸载功能
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 内置卸载 (脚本下载失败时使用)
builtin_uninstall() {
    print_info "执行内置卸载程序..."

    local uninstall_mode="${UNINSTALL_MODE:-standard}"

    case "$OS" in
        linux)
            # 停止服务
            systemctl stop sentinelx-server 2>/dev/null || true
            systemctl disable sentinelx-server 2>/dev/null || true
            rm -f /etc/systemd/system/sentinelx-server.service
            systemctl daemon-reload

            # 卸载模式处理
            case "$uninstall_mode" in
                complete|remove-config)
                    rm -rf /opt/sentinelx
                    rm -rf /etc/sentinelx
                    rm -rf /var/log/sentinelx
                    rm -rf /var/lib/sentinelx
                    ;;
                keepdata)
                    rm -rf /opt/sentinelx
                    rm -f /etc/systemd/system/sentinelx-server.service
                    ;;
                standard|*)
                    rm -rf /opt/sentinelx
                    rm -f /etc/systemd/system/sentinelx-server.service
                    rm -rf /var/log/sentinelx
                    ;;
            esac
            ;;
        macos)
            launchctl unload ~/Library/LaunchAgents/com.sentinelx.server.plist 2>/dev/null || true
            rm -f ~/Library/LaunchAgents/com.sentinelx.server.plist

            case "$uninstall_mode" in
                complete|remove-config)
                    rm -rf ~/sentinelx
                    ;;
                keepdata)
                    rm -rf ~/sentinelx
                    ;;
                standard|*)
                    rm -rf ~/sentinelx
                    ;;
            esac
            ;;
        windows)
            powershell -Command "Stop-Service -Name SentinelX -ErrorAction SilentlyContinue; Remove-Service -Name SentinelX -ErrorAction SilentlyContinue"

            case "$uninstall_mode" in
                complete|remove-config)
                    rm -rf "$PROGRAMFILES/SentinelX"
                    ;;
                keepdata)
                    rm -rf "$PROGRAMFILES/SentinelX"
                    ;;
                standard|*)
                    rm -rf "$PROGRAMFILES/SentinelX"
                    ;;
            esac
            ;;
    esac

    print_success "卸载完成"
}

# 执行卸载
do_uninstall() {
    print_step "${ICON_TRASH} 卸载 SentinelX"

    if ! check_installed; then
        print_error "SentinelX 未安装"
        exit 1
    fi

    # 确定卸载模式
    local uninstall_mode="standard"
    if [ "$REMOVE_CONFIG" = true ]; then
        uninstall_mode="complete"
    elif [ "$KEEP_DATA" = true ]; then
        uninstall_mode="keepdata"
    fi

    # 确认卸载
    if [ "$SKIP_CONFIRM" = false ] && [ "$FORCE_MODE" = false ]; then
        echo ""
        echo -e "${RED}${ICON_WARN} 确认要卸载 SentinelX 吗？${NC}"
        echo ""
        echo -e "  ${CYAN}1)${NC} 标准卸载 (删除程序和配置，保留数据)"
        echo -e "  ${RED}2)${NC} 完全卸载 (删除所有内容，包括数据)"
        echo -e "  ${YELLOW}3)${NC} 保留数据卸载 (仅删除程序，保留配置和数据)"
        echo ""

        read -p "请选择卸载模式 [1-3]: " uninstall_choice
        case "$uninstall_choice" in
            1) uninstall_mode="standard" ;;
            2) uninstall_mode="complete" ;;
            3) uninstall_mode="keepdata" ;;
            *) uninstall_mode="standard" ;;
        esac
    fi

    # 显示卸载模式
    case "$uninstall_mode" in
        complete)   print_info "卸载模式: 完全卸载 (删除所有内容)" ;;
        keepdata)   print_info "卸载模式: 保留数据卸载" ;;
        standard|*) print_info "卸载模式: 标准卸载" ;;
    esac

    # 确认
    if [ "$SKIP_CONFIRM" = false ] && [ "$FORCE_MODE" = false ]; then
        echo ""
        read -p "输入 'YES' 确认卸载: " confirm
        if [ "$confirm" != "YES" ]; then
            print_info "取消卸载"
            exit 0
        fi
    fi

    export UNINSTALL_MODE="$uninstall_mode"

    local script_file="/tmp/sentinelx-uninstall.sh"

    if download_script "scripts/uninstall.sh" "$script_file"; then
        local uninstall_cmd=""
        case "$OS" in
            windows)
                uninstall_cmd="powershell -ExecutionPolicy Bypass -File \"$script_file\""
                ;;
            *)
                uninstall_cmd="bash \"$script_file\""
                [ "$SKIP_CONFIRM" = true ] && uninstall_cmd="$uninstall_cmd --yes"
                [ "$FORCE_MODE" = true ] && uninstall_cmd="$uninstall_cmd --force"
                ;;
        esac

        if eval "$uninstall_cmd"; then
            print_success "卸载完成"
        else
            print_error "卸载脚本执行失败，尝试内置卸载..."
            builtin_uninstall
        fi
        rm -f "$script_file"
    else
        print_warn "下载卸载脚本失败，使用内置卸载"
        builtin_uninstall
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 10: 菜单系统
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 主菜单
show_main_menu() {
    clear
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  1)${NC} ${ICON_ROCKET} Docker 安装 (推荐 - 隔离环境，快速部署)"
    echo -e "${GREEN}  2)${NC} ${ICON_PACKAGE} 二进制安装 (本地安装，适合生产环境)"
    echo -e "${YELLOW}  3)${NC} ${ICON_UPDATE} 升级 SentinelX"
    echo -e "${RED}  4)${NC} ${ICON_TRASH} 卸载 SentinelX"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  0)${NC} ${ICON_EXIT} 退出"
    echo ""
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 11: 帮助信息
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_help() {
    print_banner
    echo -e "${GREEN}用法:${NC} $SCRIPT_NAME [选项]"
    echo ""
    echo -e "${GREEN}安装选项:${NC}"
    echo -e "  ${CYAN}--docker${NC}           使用 Docker 方式安装"
    echo -e "  ${CYAN}--binary${NC}           使用二进制方式安装"
    echo ""
    echo -e "${GREEN}操作选项:${NC}"
    echo -e "  ${CYAN}--uninstall${NC}        卸载 SentinelX"
    echo -e "  ${CYAN}--upgrade${NC}           升级 SentinelX"
    echo ""
    echo -e "${GREEN}卸载模式:${NC}"
    echo -e "  ${CYAN}--remove-config${NC}    完全卸载 (删除配置和数据)"
    echo -e "  ${CYAN}--keep-data${NC}        保留数据卸载 (仅删除程序)"
    echo -e "  ${CYAN}--force${NC}            强制模式 (忽略错误和警告)"
    echo ""
    echo -e "${GREEN}交互选项:${NC}"
    echo -e "  ${CYAN}--skip-confirmation${NC} 非交互模式，自动确认"
    echo -e "  ${CYAN}--verbose${NC}           详细输出模式"
    echo -e "  ${CYAN}--yes${NC}              等同于 --skip-confirmation"
    echo ""
    echo -e "${GREEN}其他:${NC}"
    echo -e "  ${CYAN}--help, -h${NC}         显示此帮助信息"
    echo -e "  ${CYAN}--version${NC}          显示版本信息"
    echo ""
    echo -e "${GREEN}示例:${NC}"
    echo -e "  $SCRIPT_NAME                  # 交互式安装"
    echo -e "  $SCRIPT_NAME --docker         # Docker 安装 (非交互)"
    echo -e "  $SCRIPT_NAME --binary --yes   # 二进制安装 (自动确认)"
    echo -e "  $SCRIPT_NAME --uninstall      # 卸载 (交互)"
    echo -e "  $SCRIPT_NAME --uninstall --remove-config --force  # 完全卸载"
    echo ""
}

show_version() {
    print_banner
    echo -e "${GREEN}版本:${NC} $SCRIPT_VERSION"
    echo ""
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 12: 参数解析
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --docker|-d)
                MODE="docker"
                ;;
            --binary|-b)
                MODE="binary"
                ;;
            --uninstall|-u)
                MODE="uninstall"
                ;;
            --upgrade|-U)
                MODE="upgrade"
                ;;
            --remove-config)
                REMOVE_CONFIG=true
                ;;
            --keep-data)
                KEEP_DATA=true
                ;;
            --force|-f)
                FORCE_MODE=true
                ;;
            --skip-confirmation|--yes|-y)
                SKIP_CONFIRM=true
                NON_INTERACTIVE=true
                ;;
            --verbose|-v)
                VERBOSE=true
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-V)
                show_version
                exit 0
                ;;
            *)
                print_error "未知选项: $1"
                echo "使用 --help 查看可用选项"
                exit 1
                ;;
        esac
        shift
    done
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 13: 主函数
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    # 检测操作系统
    detect_os

    # 解析参数
    parse_arguments "$@"

    # 设置陷阱
    setup_traps

    # 记录起始状态
    local start_time=$(date +%s)

    # 执行选定模式
    case "${MODE:-interactive}" in
        docker)
            run_preinstall_checks || { [ "$FORCE_MODE" = false ] && exit 1; }
            do_docker_install
            ;;
        binary)
            run_preinstall_checks || { [ "$FORCE_MODE" = false ] && exit 1; }
            do_binary_install
            ;;
        uninstall)
            do_uninstall
            ;;
        upgrade)
            do_upgrade
            ;;
        interactive)
            # 检查是否已安装时提示
            if ! check_installed; then
                print_warn "SentinelX 未安装"
            fi

            # 主循环
            while true; do
                show_main_menu

                read -p "请选择 [0-4]: " choice

                case $choice in
                    1)
                        run_preinstall_checks || { [ "$FORCE_MODE" = false ] && continue; }
                        do_docker_install
                        break
                        ;;
                    2)
                        run_preinstall_checks || { [ "$FORCE_MODE" = false ] && continue; }
                        do_binary_install
                        break
                        ;;
                    3)
                        do_upgrade
                        break
                        ;;
                    4)
                        do_uninstall
                        break
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

    # 显示完成信息
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_success "操作完成! 耗时: ${duration}秒"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 运行主函数
main "$@"
