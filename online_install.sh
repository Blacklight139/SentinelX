#!/bin/bash

# SentinelX 在线安装脚本
# 版本: 2.0.0
# 仓库: https://gitee.com/dark-beam/SentinelX
# 仓库: https://github.com/Blacklight139/SentinelX
# 作者: Blacklight

set -e

# ==================== 配置变量 ====================
REPO_URL="https://gitee.com/dark-beam/SentinelX"
INSTALL_DIR="/opt/sentinelx"
BIN_DIR="$INSTALL_DIR/bin"
CONFIG_DIR="/etc/sentinelx"
DATA_DIR="/var/lib/sentinelx"
LOG_DIR="/var/log/sentinelx"
SERVICE_USER="sentinelx"
SERVICE_NAME="sentinelx-server"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# ==================== 输出函数 ====================
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { echo -e "${CYAN}[DEBUG]${NC} $1"; }

# ==================== 系统检测函数 ====================
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        ID=$ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
        ID=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    elif [ -f /etc/redhat-release ]; then
        OS=$(cat /etc/redhat-release | awk '{print $1}')
        VER=$(cat /etc/redhat-release | awk '{print $3}')
        ID="centos"
    else
        log_error "无法检测操作系统"
        exit 1
    fi
    
    log_info "操作系统: $OS $VER"
    
    # 检查支持的发行版
    case $ID in
        ubuntu|debian|centos|rhel|fedora|rocky|almalinux)
            return 0
            ;;
        *)
            log_warning "未经测试的操作系统: $ID"
            read -p "是否继续安装？(y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            ;;
    esac
}

detect_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)    ARCH="amd64" ;;
        aarch64)   ARCH="arm64" ;;
        armv7l)    ARCH="armv7" ;;
        *)         ARCH="unknown" ;;
    esac
    
    if [ "$ARCH" = "unknown" ]; then
        log_error "不支持的架构: $(uname -m)"
        exit 1
    fi
    
    log_info "系统架构: $ARCH"
}

# ==================== 依赖检查 ====================
check_dependencies() {
    log_info "检查系统依赖..."
    
    local missing_deps=()
    
    # 检查基本命令
    for cmd in curl wget tar gzip; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=($cmd)
        fi
    done
    
    # 检查是否安装Go（如果需要编译）
    if [ "$INSTALL_TYPE" = "source" ] && ! command -v go &> /dev/null; then
        missing_deps+=("golang")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_warning "缺少依赖: ${missing_deps[*]}"
        return 1
    fi
    
    log_success "依赖检查通过"
    return 0
}

install_dependencies() {
    log_info "安装系统依赖..."
    
    case $ID in
        ubuntu|debian)
            apt-get update
            apt-get install -y curl wget tar gzip net-tools iptables openssl ca-certificates
            if [ "$INSTALL_TYPE" = "source" ]; then
                apt-get install -y golang git
            fi
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y curl wget tar gzip net-tools iptables openssl ca-certificates
            if [ "$INSTALL_TYPE" = "source" ]; then
                yum install -y golang git
            fi
            ;;
        fedora)
            dnf install -y curl wget tar gzip net-tools iptables openssl ca-certificates
            if [ "$INSTALL_TYPE" = "source" ]; then
                dnf install -y golang git
            fi
            ;;
    esac
    
    log_success "依赖安装完成"
}

# ==================== 用户和目录设置 ====================
setup_user() {
    log_info "设置系统用户..."
    
    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd -r -s /bin/false -m -d "$INSTALL_DIR" "$SERVICE_USER"
        log_success "创建用户: $SERVICE_USER"
    else
        log_info "用户已存在: $SERVICE_USER"
    fi
}

setup_directories() {
    log_info "创建目录结构..."
    
    # 创建目录
    mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$CONFIG_DIR" "$DATA_DIR/meg" "$LOG_DIR"
    mkdir -p "$INSTALL_DIR/scripts" "$INSTALL_DIR/backup"
    
    # 设置权限
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR" "$DATA_DIR" "$LOG_DIR"
    chmod 750 "$INSTALL_DIR" "$DATA_DIR" "$LOG_DIR"
    chmod 700 "$DATA_DIR/meg"
    
    log_success "目录创建完成"
}

# ==================== 下载函数 ====================
download_file() {
    local url=$1
    local output=$2
    local retry=${3:-3}
    
    for i in $(seq 1 $retry); do
        if curl -fsSL --progress-bar "$url" -o "$output"; then
            return 0
        fi
        
        log_warning "下载失败 ($i/$retry): $url"
        if [ $i -lt $retry ]; then
            sleep 2
        fi
    done
    
    log_error "下载失败: $url"
    return 1
}

download_binary() {
    log_info "下载 SentinelX 二进制文件..."
    
    local version="v2.0.0"
    local filename="sentinelx-server-$OS_LOWER-$ARCH.tar.gz"
    local url="$REPO_URL/releases/download/$version/$filename"
    local temp_file="/tmp/$filename"
    
    # 尝试从多个源下载
    local mirrors=(
        "$REPO_URL/releases/download/$version/$filename"
        "https://ghproxy.com/$REPO_URL/releases/download/$version/$filename"
        "https://github.com/Blacklight139/SentinelX/releases/download/$version/$filename"
    )
    
    for mirror in "${mirrors[@]}"; do
        log_debug "尝试从镜像下载: $mirror"
        if download_file "$mirror" "$temp_file" 2; then
            break
        fi
    done
    
    if [ ! -f "$temp_file" ]; then
        log_warning "无法下载预编译包，尝试从源码编译..."
        build_from_source
        return
    fi
    
    # 解压文件
    tar -xzf "$temp_file" -C "$BIN_DIR"
    chmod +x "$BIN_DIR/sentinelx-server"
    chown "$SERVICE_USER:$SERVICE_USER" "$BIN_DIR/sentinelx-server"
    
    rm -f "$temp_file"
    log_success "二进制文件下载完成"
}

download_configs() {
    log_info "下载配置文件..."
    
    local configs=(
        "server/config.yaml.example"
        "server/generate_keys.sh"
        "server/sentinelx-server.service"
        "server/install.sh"
        "LICENSE"
        "README.md"
    )
    
    for config in "${configs[@]}"; do
        local url="$REPO_URL/raw/main/$config"
        local output="$INSTALL_DIR/$(basename $config)"
        
        if ! download_file "$url" "$output"; then
            log_warning "无法下载: $config"
            continue
        fi
        
        # 设置权限
        if [[ "$config" == *.sh ]]; then
            chmod +x "$output"
        fi
        
        log_debug "下载完成: $config"
    done
    
    # 复制配置文件到系统目录
    if [ -f "$INSTALL_DIR/config.yaml.example" ]; then
        cp "$INSTALL_DIR/config.yaml.example" "$CONFIG_DIR/config.yaml"
        sed -i "s|log_dir:.*|log_dir: \"$DATA_DIR/meg\"|g" "$CONFIG_DIR/config.yaml"
        sed -i "s|data_dir:.*|data_dir: \"$DATA_DIR/data\"|g" "$CONFIG_DIR/config.yaml"
        chown "$SERVICE_USER:$SERVICE_USER" "$CONFIG_DIR/config.yaml"
        chmod 640 "$CONFIG_DIR/config.yaml"
    fi
    
    log_success "配置文件下载完成"
}

build_from_source() {
    log_info "从源码编译 SentinelX..."
    
    local source_dir="/tmp/sentinelx-source"
    
    # 清理旧目录
    rm -rf "$source_dir"
    
    # 克隆仓库
    log_info "克隆源代码仓库..."
    if ! git clone --depth 1 "$REPO_URL.git" "$source_dir"; then
        log_error "克隆仓库失败"
        return 1
    fi
    
    # 编译服务端
    cd "$source_dir/server"
    
    # 设置Go代理（针对国内用户）
    export GOPROXY=https://goproxy.cn,direct
    
    # 下载依赖
    log_info "下载Go依赖..."
    if ! go mod download; then
        log_error "下载依赖失败"
        return 1
    fi
    
    # 编译
    log_info "编译二进制文件..."
    if ! CGO_ENABLED=0 GOOS=linux GOARCH=$ARCH go build -ldflags="-s -w" -o sentinelx-server; then
        log_error "编译失败"
        return 1
    fi
    
    # 复制到安装目录
    cp sentinelx-server "$BIN_DIR/"
    chmod +x "$BIN_DIR/sentinelx-server"
    chown "$SERVICE_USER:$SERVICE_USER" "$BIN_DIR/sentinelx-server"
    
    # 清理
    rm -rf "$source_dir"
    
    log_success "源码编译完成"
}

# ==================== 密钥生成 ====================
generate_keys() {
    log_info "生成加密密钥..."
    
    if [ -f "$INSTALL_DIR/generate_keys.sh" ]; then
        cd "$INSTALL_DIR"
        chmod +x generate_keys.sh
        
        # 创建密钥目录
        mkdir -p "$CONFIG_DIR/keys"
        
        # 生成密钥
        if ./generate_keys.sh 2>&1 | tee "$LOG_DIR/keygen.log"; then
            # 移动密钥到配置目录
            if [ -d "keys" ]; then
                cp -r keys/* "$CONFIG_DIR/keys/"
                chown -R "$SERVICE_USER:$SERVICE_USER" "$CONFIG_DIR/keys"
                chmod 600 "$CONFIG_DIR/keys/"*.key
                rm -rf keys
            fi
            log_success "密钥生成完成"
        else
            log_error "密钥生成失败"
            return 1
        fi
    else
        log_warning "找不到密钥生成脚本，跳过密钥生成"
    fi
}

# ==================== 服务配置 ====================
setup_service() {
    log_info "配置系统服务..."
    
    if [ -f "$INSTALL_DIR/sentinelx-server.service" ]; then
        # 修改服务文件中的路径
        sed -i "s|/opt/sentinelx|$INSTALL_DIR|g" "$INSTALL_DIR/sentinelx-server.service"
        sed -i "s|User=sentinelx|User=$SERVICE_USER|g" "$INSTALL_DIR/sentinelx-server.service"
        sed -i "s|Group=sentinelx|Group=$SERVICE_USER|g" "$INSTALL_DIR/sentinelx-server.service"
        
        # 复制服务文件
        cp "$INSTALL_DIR/sentinelx-server.service" "/etc/systemd/system/$SERVICE_NAME.service"
        
        # 重新加载systemd
        systemctl daemon-reload
        
        # 启用服务
        systemctl enable "$SERVICE_NAME"
        
        log_success "服务配置完成"
    else
        log_warning "找不到服务文件，跳过服务配置"
    fi
}

configure_firewall() {
    log_info "配置防火墙..."
    
    # 检测防火墙类型
    if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
        ufw allow 8443/tcp comment "SentinelX HTTPS"
        ufw allow 9090/tcp comment "SentinelX Metrics"
        log_success "UFW防火墙已配置"
    elif command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-port=8443/tcp
        firewall-cmd --permanent --add-port=9090/tcp
        firewall-cmd --reload
        log_success "Firewalld已配置"
    elif command -v iptables &> /dev/null; then
        iptables -A INPUT -p tcp --dport 8443 -j ACCEPT
        iptables -A INPUT -p tcp --dport 9090 -j ACCEPT
        # 保存规则（如果支持）
        if command -v iptables-save &> /dev/null; then
            iptables-save > /etc/iptables/rules.v4
        fi
        log_success "iptables已配置"
    else
        log_warning "未检测到防火墙，跳过配置"
    fi
}

# ==================== 工具脚本 ====================
create_tools() {
    log_info "创建管理工具..."
    
    # 创建备份脚本
    cat > "$INSTALL_DIR/scripts/backup.sh" << 'EOF'
#!/bin/bash
# SentinelX 备份脚本
BACKUP_DIR="/opt/sentinelx/backup"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/sentinelx_backup_$DATE.tar.gz"

mkdir -p $BACKUP_DIR
systemctl stop sentinelx-server

tar -czf $BACKUP_FILE \
    /etc/sentinelx \
    /var/lib/sentinelx \
    /var/log/sentinelx \
    /opt/sentinelx/config \
    /opt/sentinelx/data 2>/dev/null

systemctl start sentinelx-server
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
echo "备份完成: $BACKUP_FILE"
EOF
    
    # 创建更新脚本
    cat > "$INSTALL_DIR/scripts/update.sh" << 'EOF'
#!/bin/bash
# SentinelX 更新脚本
REPO_URL="https://gitee.com/dark-beam/SentinelX"
TEMP_DIR="/tmp/sentinelx_update"

echo "开始更新 SentinelX..."
systemctl stop sentinelx-server

mkdir -p $TEMP_DIR
cd $TEMP_DIR

# 下载最新版本
wget -q $REPO_URL/releases/download/latest/sentinelx-server-linux-amd64.tar.gz
tar -xzf sentinelx-server-linux-amd64.tar.gz

# 替换二进制文件
cp sentinelx-server /opt/sentinelx/bin/
chmod +x /opt/sentinelx/bin/sentinelx-server
chown sentinelx:sentinelx /opt/sentinelx/bin/sentinelx-server

systemctl start sentinelx-server
rm -rf $TEMP_DIR
echo "更新完成！"
EOF
    
    # 创建状态检查脚本
    cat > "$INSTALL_DIR/scripts/status.sh" << 'EOF'
#!/bin/bash
# SentinelX 状态检查脚本
echo "=== SentinelX 状态检查 ==="
echo "服务状态:"
systemctl status sentinelx-server --no-pager -l

echo -e "\n监听端口:"
netstat -tlnp | grep sentinelx

echo -e "\n日志文件:"
ls -la /var/lib/sentinelx/meg/ | head -10

echo -e "\n存储使用:"
du -sh /var/lib/sentinelx/meg/

echo -e "\n连接数:"
curl -ks https://localhost:8443/api/stats 2>/dev/null || echo "API不可用"
EOF
    
    # 设置脚本权限
    chmod +x "$INSTALL_DIR/scripts/"*.sh
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/scripts"
    
    log_success "管理工具创建完成"
}

# ==================== 启动服务 ====================
start_service() {
    log_info "启动 SentinelX 服务..."
    
    if systemctl start "$SERVICE_NAME"; then
        sleep 2
        
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            log_success "服务启动成功"
            
            # 显示服务状态
            echo ""
            systemctl status "$SERVICE_NAME" --no-pager -l | head -20
        else
            log_error "服务启动失败"
            journalctl -u "$SERVICE_NAME" -n 50 --no-pager
            return 1
        fi
    else
        log_error "服务启动命令失败"
        return 1
    fi
}

# ==================== 安装摘要 ====================
show_summary() {
    local ip_address=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                 SentinelX 安装完成！                    ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "📋 安装信息:"
    echo "  版本:      v2.0.0"
    echo "  系统:      $OS $VER ($ARCH)"
    echo "  安装目录:  $INSTALL_DIR"
    echo "  配置文件:  $CONFIG_DIR/"
    echo "  数据目录:  $DATA_DIR/"
    echo "  日志目录:  $LOG_DIR/"
    echo ""
    echo "🚀 服务管理:"
    echo "  启动服务:    systemctl start $SERVICE_NAME"
    echo "  停止服务:    systemctl stop $SERVICE_NAME"
    echo "  重启服务:    systemctl restart $SERVICE_NAME"
    echo "  查看状态:    systemctl status $SERVICE_NAME"
    echo "  查看日志:    journalctl -u $SERVICE_NAME -f"
    echo ""
    echo "🔧 管理工具:"
    echo "  备份脚本:    $INSTALL_DIR/scripts/backup.sh"
    echo "  更新脚本:    $INSTALL_DIR/scripts/update.sh"
    echo "  状态检查:    $INSTALL_DIR/scripts/status.sh"
    echo ""
    echo "🌐 访问地址:"
    echo "  WebSocket:  wss://$ip_address:8443/ws"
    echo "  API:        https://$ip_address:8443/api"
    echo "  Metrics:    http://$ip_address:9090/metrics"
    echo ""
    echo "🔐 安全提示:"
    echo "  1. 默认使用自签名证书，生产环境请替换"
    echo "  2. 密钥文件位于: $CONFIG_DIR/keys/"
    echo "  3. 首次使用请修改默认配置"
    echo ""
    echo "📚 文档链接:"
    echo "  项目地址:   $REPO_URL"
    echo "  在线文档:   $REPO_URL/wiki"
    echo ""
    echo "💡 下一步:"
    echo "  1. 编辑配置文件: $CONFIG_DIR/config.yaml"
    echo "  2. 配置客户端连接信息"
    echo "  3. 设置防火墙规则"
    echo "  4. 访问 https://$ip_address:8443 查看状态"
    echo ""
    echo "⚠️  注意事项:"
    echo "  - 所有私钥文件已加密存储，请妥善保管"
    echo "  - 定期运行备份脚本防止数据丢失"
    echo "  - 监控系统资源使用情况"
    echo ""
    echo "════════════════════════════════════════════════════════════"
}

# ==================== 清理函数 ====================
cleanup() {
    log_info "清理临时文件..."
    rm -rf /tmp/sentinelx-* /tmp/SentinelX-*
    log_success "清理完成"
}

# ==================== 主安装流程 ====================
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║          SentinelX 在线安装程序 v2.0.0                  ║"
    echo "║          仓库: $REPO_URL          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    # 检查root权限
    if [ "$EUID" -ne 0 ]; then 
        log_error "请使用 sudo 运行此脚本"
        echo "使用方法: curl -sSL $REPO_URL/raw/main/online_install.sh | sudo bash"
        exit 1
    fi
    
    # 解析参数
    INSTALL_TYPE="binary"
    OS_LOWER="linux"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --source)
                INSTALL_TYPE="source"
                shift
                ;;
            --help|-h)
                echo "使用方法: $0 [选项]"
                echo "选项:"
                echo "  --source    从源码编译安装"
                echo "  --help, -h  显示帮助信息"
                exit 0
                ;;
            *)
                log_warning "未知参数: $1"
                shift
                ;;
        esac
    done
    
    # 显示安装类型
    if [ "$INSTALL_TYPE" = "source" ]; then
        log_info "安装模式: 从源码编译"
    else
        log_info "安装模式: 使用预编译二进制文件"
    fi
    
    # 执行安装步骤
    detect_os
    detect_arch
    check_dependencies || install_dependencies
    setup_user
    setup_directories
    download_configs
    
    if [ "$INSTALL_TYPE" = "source" ]; then
        build_from_source
    else
        download_binary
    fi
    
    generate_keys
    setup_service
    configure_firewall
    create_tools
    start_service
    cleanup
    show_summary
}

# ==================== 异常处理 ====================
handle_error() {
    local exit_code=$?
    log_error "安装过程中出现错误 (退出码: $exit_code)"
    log_error "错误位置: ${BASH_SOURCE[1]}:${BASH_LINENO[0]}"
    
    # 显示相关日志
    if [ -f "$LOG_DIR/install.log" ]; then
        log_error "查看安装日志: tail -50 $LOG_DIR/install.log"
    fi
    
    # 清理部分安装
    log_warning "尝试回滚安装..."
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    rm -f "/etc/systemd/system/$SERVICE_NAME.service"
    
    exit $exit_code
}

# ==================== 执行主函数 ====================
trap handle_error ERR

# 创建安装日志
mkdir -p "$LOG_DIR"
exec 2>&1 | tee "$LOG_DIR/install.log"

main "$@"
