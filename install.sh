#!/bin/bash
#
# SentinelX 一键安装脚本
# 支持: Docker安装 | 一键安装 | 卸载
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置
REPO_GITEE="https://gitee.com/dark-beam/SentinelX"
REPO_GITHUB="https://github.com/Blacklight139/SentinelX"
INSTALL_DIR="/opt/sentinelx"
CONFIG_DIR="/etc/sentinelx"
DATA_DIR="/var/lib/sentinelx"
LOG_DIR="/var/log/sentinelx"
SERVICE_NAME="sentinelx-server"

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

# 检查 root 权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用 sudo 运行此脚本"
        exit 1
    fi
}

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    elif command -v lsb_release &> /dev/null; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        VER=$(lsb_release -sr)
    else
        OS="unknown"
        VER="unknown"
    fi

    case $OS in
        ubuntu|debian)
            PKG_MANAGER="apt-get"
            ;;
        centos|rhel|rocky|alma)
            PKG_MANAGER="yum"
            ;;
        fedora)
            PKG_MANAGER="dnf"
            ;;
        *)
            print_warn "未支持的操作系统: $OS $VER，尝试继续安装..."
            PKG_MANAGER="apt-get"
            ;;
    esac

    print_info "检测到系统: $OS $VER (包管理器: $PKG_MANAGER)"
}

# 检查 Docker
check_docker() {
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
        print_info "Docker 已安装: v$DOCKER_VERSION"
        return 0
    else
        print_warn "Docker 未安装"
        return 1
    fi
}

check_docker_running() {
    if docker info &> /dev/null; then
        return 0
    else
        print_error "Docker 服务未运行，请先启动 Docker"
        return 1
    fi
}

# 检查 Docker Compose
check_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        return 0
    elif docker compose version &> /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
        return 0
    else
        print_warn "Docker Compose 未安装"
        return 1
    fi
}

# 安装 Docker
install_docker() {
    print_info "正在安装 Docker..."

    case $PKG_MANAGER in
        apt-get)
            apt-get update
            apt-get install -y ca-certificates curl gnupg lsb-release

            # 添加 Docker GPG 密钥
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg

            # 添加 Docker 源
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        yum)
            yum install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        dnf)
            dnf install -y dnf-plugins-core
            dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
    esac

    # 启动 Docker
    systemctl enable docker --now
    print_success "Docker 安装完成"
}

# Docker 安装
install_docker_mode() {
    check_root
    detect_os

    if ! check_docker; then
        install_docker
    fi

    check_docker_running

    print_info "开始 Docker 方式安装 SentinelX..."

    # 创建数据目录
    mkdir -p "$DATA_DIR/meg" "$DATA_DIR/data" "$CONFIG_DIR" "$LOG_DIR"

    # 下载 docker-compose.yml
    COMPOSE_FILE="/tmp/sentinelx-docker-compose.yml"

    print_info "下载 docker-compose.yml..."
    if curl -fsSL "$REPO_GITHUB/raw/main/server/docker-compose.yml" -o "$COMPOSE_FILE" 2>/dev/null; then
        print_success "下载成功"
    else
        curl -fsSL "$REPO_GITEE/raw/main/server/docker-compose.yml" -o "$COMPOSE_FILE"
    fi

    # 复制并启动
    cp "$COMPOSE_FILE" "$CONFIG_DIR/docker-compose.yml"
    rm -f "$COMPOSE_FILE"

    # 复制配置示例
    if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
        print_info "下载配置文件..."
        curl -fsSL "$REPO_GITHUB/raw/main/server/config.yaml.example" -o "$CONFIG_DIR/config.yaml" 2>/dev/null || \
        curl -fsSL "$REPO_GITEE/raw/main/server/config.yaml.example" -o "$CONFIG_DIR/config.yaml"
        chmod 640 "$CONFIG_DIR/config.yaml"
    fi

    # 启动容器
    print_info "启动 SentinelX 容器..."
    cd "$CONFIG_DIR"
    docker compose up -d --pull always

    print_success ""
    print_success "SentinelX 安装完成！"
    echo ""
    echo -e "${GREEN}  访问地址:${NC}"
    echo -e "    HTTPS: ${CYAN}https://your-server:8443${NC}"
    echo -e "    Metrics: ${CYAN}http://your-server:9090${NC}"
    echo -e "    API文档: ${CYAN}https://your-server:8443/api/v1/health${NC}"
    echo ""
    echo -e "${YELLOW}  管理命令:${NC}"
    echo -e "    查看状态: ${CYAN}docker compose -f $CONFIG_DIR/docker-compose.yml ps${NC}"
    echo -e "    查看日志: ${CYAN}docker compose -f $CONFIG_DIR/docker-compose.yml logs -f${NC}"
    echo -e "    停止服务: ${CYAN}docker compose -f $CONFIG_DIR/docker-compose.yml down${NC}"
    echo ""
}

# 一键安装（本地二进制）
install_binary_mode() {
    check_root
    detect_os

    print_info "开始一键安装 SentinelX..."

    # 安装系统依赖
    print_info "安装系统依赖..."
    case $PKG_MANAGER in
        apt-get)
            apt-get update
            apt-get install -y curl wget tar gzip openssl ca-certificates git
            ;;
        yum)
            yum install -y curl wget tar gzip openssl git
            ;;
        dnf)
            dnf install -y curl wget tar gzip openssl git
            ;;
    esac

    # 创建目录
    print_info "创建目录结构..."
    mkdir -p "$INSTALL_DIR/bin" "$CONFIG_DIR/keys" "$DATA_DIR/meg" "$DATA_DIR/data" "$LOG_DIR"

    # 下载最新二进制
    print_info "下载最新版本..."
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH_NAME="linux-amd64"
            ;;
        aarch64|arm64)
            ARCH_NAME="linux-arm64"
            ;;
        armv7l)
            ARCH_NAME="linux-armv7"
            ;;
        *)
            print_error "不支持的架构: $ARCH"
            exit 1
            ;;
    esac

    # 从 GitHub 下载 release
    API_URL="https://api.github.com/repos/Blacklight139/SentinelX/releases/latest"
    DOWNLOAD_URL=$(curl -sf "$API_URL" | grep "browser_download_url.*sentinelx.*$ARCH_NAME" | cut -d '"' -f 4)

    if [ -z "$DOWNLOAD_URL" ]; then
        print_warn "无法获取预编译版本，将从源码编译..."

        # 检查 Go
        if ! command -v go &> /dev/null; then
            print_info "安装 Go..."
            case $PKG_MANAGER in
                apt-get)
                    apt-get install -y golang-go
                    ;;
                yum)
                    yum install -y golang
                    ;;
                dnf)
                    dnf install -y golang
                    ;;
            esac
        fi

        # 克隆并编译
        TEMP_DIR="/tmp/sentinelx-build"
        rm -rf "$TEMP_DIR"
        mkdir -p "$TEMP_DIR"

        print_info "克隆源码..."
        git clone --depth 1 "$REPO_GITHUB" "$TEMP_DIR" 2>/dev/null || \
        git clone --depth 1 "$REPO_GITEE" "$TEMP_DIR"

        print_info "编译..."
        cd "$TEMP_DIR/server"
        go build -o "$INSTALL_DIR/bin/sentinelx-server" main.go
        chmod +x "$INSTALL_DIR/bin/sentinelx-server"
    else
        # 下载预编译版本
        print_info "下载预编译版本: $DOWNLOAD_URL"
        curl -fSL "$DOWNLOAD_URL" -o "$INSTALL_DIR/bin/sentinelx-server"
        chmod +x "$INSTALL_DIR/bin/sentinelx-server"
    fi

    # 下载配置文件
    if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
        print_info "下载配置文件..."
        curl -fsSL "$REPO_GITHUB/raw/main/server/config.yaml.example" -o "$CONFIG_DIR/config.yaml" 2>/dev/null || \
        curl -fsSL "$REPO_GITEE/raw/main/server/config.yaml.example" -o "$CONFIG_DIR/config.yaml"
        chmod 640 "$CONFIG_DIR/config.yaml"
    fi

    # 生成密钥
    print_info "生成加密密钥..."
    "$INSTALL_DIR/bin/sentinelx-server" --generate-keys
    mv keys/* "$CONFIG_DIR/keys/" 2>/dev/null || true
    rm -rf keys
    chmod 600 "$CONFIG_DIR/keys/"*.key 2>/dev/null || true

    # 配置 systemd 服务
    print_info "配置系统服务..."
    cat > /etc/systemd/system/sentinelx-server.service << 'EOF'
[Unit]
Description=SentinelX Security Monitor
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/sentinelx
ExecStart=/opt/sentinelx/bin/sentinelx-server --config /etc/sentinelx/config.yaml
Restart=always
RestartSec=5

# 安全设置
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/sentinelx /var/log/sentinelx /etc/sentinelx

[Install]
WantedBy=multi-user.target
EOF

    # 设置权限
    print_info "设置文件权限..."
    chmod 750 "$INSTALL_DIR" "$DATA_DIR" "$LOG_DIR"
    chmod 700 "$DATA_DIR/meg"
    chmod +x "$INSTALL_DIR/bin/sentinelx-server"

    # 重新加载 systemd
    systemctl daemon-reload
    systemctl enable sentinelx-server

    # 启动服务
    print_info "启动服务..."
    systemctl start sentinelx-server

    # 检查状态
    sleep 2
    if systemctl is-active sentinelx-server &> /dev/null; then
        print_success "SentinelX 服务已启动"
    else
        print_warn "服务启动中，请检查: journalctl -u sentinelx-server -n 50"
    fi

    print_success ""
    print_success "SentinelX 安装完成！"
    echo ""
    echo -e "${GREEN}  安装路径:${NC}"
    echo -e "    程序: ${CYAN}$INSTALL_DIR/bin/sentinelx-server${NC}"
    echo -e "    配置: ${CYAN}$CONFIG_DIR/config.yaml${NC}"
    echo -e "    数据: ${CYAN}$DATA_DIR${NC}"
    echo ""
    echo -e "${GREEN}  访问地址:${NC}"
    echo -e "    HTTPS: ${CYAN}https://your-server:8443${NC}"
    echo -e "    Metrics: ${CYAN}http://your-server:9090${NC}"
    echo -e "    API文档: ${CYAN}https://your-server:8443/api/v1/health${NC}"
    echo ""
    echo -e "${YELLOW}  管理命令:${NC}"
    echo -e "    启动服务: ${CYAN}systemctl start sentinelx-server${NC}"
    echo -e "    停止服务: ${CYAN}systemctl stop sentinelx-server${NC}"
    echo -e "    查看状态: ${CYAN}systemctl status sentinelx-server${NC}"
    echo -e "    查看日志: ${CYAN}journalctl -u sentinelx-server -f${NC}"
    echo ""
}

# 卸载
uninstall() {
    check_root

    echo ""
    echo -e "${YELLOW}⚠️  确认要卸载 SentinelX 吗？${NC}"
    echo -e "    这将删除: ${RED}$INSTALL_DIR${NC} ${RED}$CONFIG_DIR${NC} ${RED}$DATA_DIR${NC} ${RED}$LOG_DIR${NC}"
    echo -e "    这将停止并禁用: ${RED}$SERVICE_NAME${NC}"
    echo ""

    read -p "输入 'YES' 确认卸载: " confirm
    if [ "$confirm" != "YES" ]; then
        print_info "取消卸载"
        exit 0
    fi

    print_info "开始卸载 SentinelX..."

    # 停止服务
    print_info "停止服务..."
    systemctl stop sentinelx-server 2>/dev/null || true
    systemctl disable sentinelx-server 2>/dev/null || true

    # 删除 systemd 服务
    print_info "删除系统服务..."
    rm -f /etc/systemd/system/sentinelx-server.service
    systemctl daemon-reload

    # 删除 Docker 容器（如果存在）
    if check_docker &> /dev/null; then
        if [ -f "$CONFIG_DIR/docker-compose.yml" ]; then
            print_info "删除 Docker 容器..."
            cd "$CONFIG_DIR"
            docker compose down -v 2>/dev/null || true
        fi
    fi

    # 删除文件
    print_info "删除安装文件..."
    rm -rf "$INSTALL_DIR"
    rm -rf "$DATA_DIR"
    rm -rf "$LOG_DIR"

    # 保留配置目录（用户可能需要）
    if [ -d "$CONFIG_DIR" ]; then
        echo -e "${YELLOW}保留配置文件目录: $CONFIG_DIR${NC}"
        echo -e "如需删除，请手动: ${CYAN}rm -rf $CONFIG_DIR${NC}"
    fi

    print_success ""
    print_success "SentinelX 卸载完成！"
    echo ""
}

# 显示菜单
show_menu() {
    clear
    print_banner

    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  1)${NC} 🚀 Docker 安装 (推荐 - 隔离环境，快速部署)"
    echo -e "${GREEN}  2)${NC} 📦 一键安装 (本地二进制，适合生产环境)"
    echo -e "${RED}  3)${NC} 🗑️  卸载 SentinelX"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  0)${NC} ❌ 退出"
    echo ""
}

# 主函数
main() {
    # 检查参数
    case "${1:-}" in
        docker|--docker|-d)
            install_docker_mode
            ;;
        binary|--binary|-b)
            install_binary_mode
            ;;
        uninstall|--uninstall|-u)
            uninstall
            ;;
        *)
            # 显示菜单
            while true; do
                show_menu
                read -p "请选择 [0-3]: " choice
                case $choice in
                    1)
                        install_docker_mode
                        break
                        ;;
                    2)
                        install_binary_mode
                        break
                        ;;
                    3)
                        uninstall
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
}

main "$@"
