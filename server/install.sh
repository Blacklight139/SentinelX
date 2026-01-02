#!/bin/bash

# SentinelX 服务端安装脚本
# 版本: 1.0.0
# 作者: Blacklight139

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "请使用sudo运行此脚本"
        exit 1
    fi
}

# 检查系统
check_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        print_error "无法检测操作系统"
        exit 1
    fi
    
    case $ID in
        ubuntu|debian)
            print_info "检测到系统: $OS $VER"
            ;;
        centos|rhel|fedora)
            print_info "检测到系统: $OS $VER"
            ;;
        *)
            print_warning "未测试的操作系统: $OS"
            read -p "是否继续？(y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            ;;
    esac
}

# 安装依赖
install_dependencies() {
    print_info "安装系统依赖..."
    
    if command -v apt &> /dev/null; then
        apt update
        apt install -y \
            golang-go \
            git \
            openssl \
            curl \
            wget \
            net-tools \
            iptables \
            rsyslog \
            cron
    elif command -v yum &> /dev/null; then
        yum install -y \
            golang \
            git \
            openssl \
            curl \
            wget \
            net-tools \
            iptables \
            rsyslog \
            cronie
    elif command -v dnf &> /dev/null; then
        dnf install -y \
            golang \
            git \
            openssl \
            curl \
            wget \
            net-tools \
            iptables \
            rsyslog \
            cronie
    else
        print_error "不支持的包管理器"
        exit 1
    fi
    
    print_success "依赖安装完成"
}

# 创建系统用户
create_user() {
    print_info "创建系统用户..."
    
    if ! id "sentinelx" &>/dev/null; then
        useradd -r -s /bin/false -m -d /opt/sentinelx sentinelx
        print_success "创建用户 sentinelx"
    else
        print_info "用户 sentinelx 已存在"
    fi
}

# 创建目录结构
create_directories() {
    print_info "创建目录结构..."
    
    mkdir -p /opt/sentinelx/{bin,config,data,logs,scripts,backup}
    mkdir -p /var/lib/sentinelx/meg
    mkdir -p /var/log/sentinelx
    
    chown -R sentinelx:sentinelx /opt/sentinelx
    chown -R sentinelx:sentinelx /var/lib/sentinelx
    chown -R sentinelx:sentinelx /var/log/sentinelx
    
    chmod 700 /opt/sentinelx
    chmod 700 /var/lib/sentinelx
    chmod 750 /var/log/sentinelx
    
    print_success "目录创建完成"
}

# 下载源码
download_source() {
    print_info "下载源代码..."
    
    cd /opt/sentinelx
    
    if [ -d "SentinelX" ]; then
        print_info "更新现有代码..."
        cd SentinelX
        git pull
        cd ..
    else
        print_info "从GitHub克隆代码..."
        git clone https://github.com/Blacklight139/SentinelX.git
        if [ $? -ne 0 ]; then
            print_error "克隆代码失败"
            exit 1
        fi
    fi
    
    print_success "代码下载完成"
}

# 生成密钥
generate_keys() {
    print_info "生成加密密钥..."
    
    cd /opt/sentinelx/SentinelX/server
    
    if [ -f "generate_keys.sh" ]; then
        chmod +x generate_keys.sh
        ./generate_keys.sh
        
        # 移动密钥到配置目录
        mkdir -p /etc/sentinelx/keys
        cp -r keys/* /etc/sentinelx/keys/
        chown -R sentinelx:sentinelx /etc/sentinelx
        chmod 600 /etc/sentinelx/keys/*.key
        
        print_success "密钥生成完成"
    else
        print_error "找不到密钥生成脚本"
        exit 1
    fi
}

# 编译服务端
compile_server() {
    print_info "编译服务端程序..."
    
    cd /opt/sentinelx/SentinelX/server
    
    # 设置Go代理
    export GOPROXY=https://goproxy.cn,direct
    
    # 下载依赖
    print_info "下载Go依赖..."
    go mod download
    
    # 编译
    print_info "编译二进制文件..."
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o sentinelx-server main.go
    
    if [ $? -ne 0 ]; then
        print_error "编译失败"
        exit 1
    fi
    
    # 安装到系统目录
    mv sentinelx-server /opt/sentinelx/bin/
    chmod 750 /opt/sentinelx/bin/sentinelx-server
    chown sentinelx:sentinelx /opt/sentinelx/bin/sentinelx-server
    
    print_success "编译完成"
}

# 配置系统
configure_system() {
    print_info "配置系统..."
    
    # 复制配置文件
    cd /opt/sentinelx/SentinelX/server
    
    if [ -f "config.yaml.example" ]; then
        if [ ! -f "/etc/sentinelx/config.yaml" ]; then
            cp config.yaml.example /etc/sentinelx/config.yaml
            
            # 更新配置文件中的路径
            sed -i "s|log_dir:.*|log_dir: \"/var/lib/sentinelx/meg\"|g" /etc/sentinelx/config.yaml
            sed -i "s|data_dir:.*|data_dir: \"/var/lib/sentinelx/data\"|g" /etc/sentinelx/config.yaml
            
            chown sentinelx:sentinelx /etc/sentinelx/config.yaml
            chmod 640 /etc/sentinelx/config.yaml
        fi
    fi
    
    # 复制systemd服务文件
    if [ -f "sentinelx-server.service" ]; then
        cp sentinelx-server.service /etc/systemd/system/
        systemctl daemon-reload
    fi
    
    # 配置日志轮转
    cat > /etc/logrotate.d/sentinelx << EOF
/var/log/sentinelx/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 640 sentinelx sentinelx
    sharedscripts
    postrotate
        systemctl reload sentinelx-server > /dev/null 2>&1 || true
    endscript
}
EOF
    
    print_success "系统配置完成"
}

# 配置防火墙
configure_firewall() {
    print_info "配置防火墙..."
    
    # 检查防火墙类型
    if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
        # Ubuntu/Debian UFW
        ufw allow 8443/tcp comment "SentinelX HTTPS"
        ufw allow 9090/tcp comment "SentinelX Metrics"
        print_success "UFW防火墙已配置"
    elif command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
        # CentOS/RHEL Firewalld
        firewall-cmd --permanent --add-port=8443/tcp
        firewall-cmd --permanent --add-port=9090/tcp
        firewall-cmd --reload
        print_success "Firewalld已配置"
    elif command -v iptables &> /dev/null; then
        # iptables
        iptables -A INPUT -p tcp --dport 8443 -j ACCEPT
        iptables -A INPUT -p tcp --dport 9090 -j ACCEPT
        print_success "iptables已配置"
    else
        print_warning "未检测到防火墙，跳过配置"
    fi
}

# 创建备份脚本
create_backup_script() {
    print_info "创建备份脚本..."
    
    cat > /opt/sentinelx/scripts/backup.sh << 'EOF'
#!/bin/bash

# SentinelX 备份脚本
BACKUP_DIR="/opt/sentinelx/backup"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/sentinelx_backup_$DATE.tar.gz"

# 创建备份目录
mkdir -p $BACKUP_DIR

# 停止服务
systemctl stop sentinelx-server

# 创建备份
tar -czf $BACKUP_FILE \
    /etc/sentinelx \
    /var/lib/sentinelx \
    /var/log/sentinelx \
    /opt/sentinelx/config \
    /opt/sentinelx/data 2>/dev/null

# 启动服务
systemctl start sentinelx-server

# 删除旧备份（保留最近7天）
find $BACKUP_DIR -name "sentinelx_backup_*.tar.gz" -mtime +7 -delete

echo "备份完成: $BACKUP_FILE"
EOF
    
    chmod +x /opt/sentinelx/scripts/backup.sh
    chown sentinelx:sentinelx /opt/sentinelx/scripts/backup.sh
    
    # 添加cron任务
    (crontab -l 2>/dev/null; echo "0 2 * * * /opt/sentinelx/scripts/backup.sh") | crontab -
    
    print_success "备份脚本已创建"
}

# 创建监控脚本
create_monitor_script() {
    print_info "创建监控脚本..."
    
    cat > /opt/sentinelx/scripts/monitor.sh << 'EOF'
#!/bin/bash

# SentinelX 监控脚本
LOG_FILE="/var/log/sentinelx/monitor.log"
ALERT_EMAIL="admin@example.com"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

# 检查服务状态
if ! systemctl is-active --quiet sentinelx-server; then
    log_message "ERROR: SentinelX服务未运行"
    systemctl restart sentinelx-server
    log_message "INFO: 尝试重启服务"
fi

# 检查磁盘空间
DISK_USAGE=$(df /var/lib/sentinelx | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 90 ]; then
    log_message "WARNING: 磁盘使用率超过90%"
fi

# 检查内存使用
MEM_FREE=$(free -m | awk 'NR==2 {print $4}')
if [ $MEM_FREE -lt 100 ]; then
    log_message "WARNING: 可用内存不足100MB"
fi

# 检查日志文件大小
find /var/log/sentinelx -name "*.log" -size +100M -exec log_message "WARNING: 大日志文件: {}" \;
EOF
    
    chmod +x /opt/sentinelx/scripts/monitor.sh
    chown sentinelx:sentinelx /opt/sentinelx/scripts/monitor.sh
    
    # 添加cron任务
    (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/sentinelx/scripts/monitor.sh") | crontab -
    
    print_success "监控脚本已创建"
}

# 启动服务
start_service() {
    print_info "启动服务..."
    
    systemctl daemon-reload
    systemctl enable sentinelx-server
    systemctl start sentinelx-server
    
    # 等待服务启动
    sleep 3
    
    if systemctl is-active --quiet sentinelx-server; then
        print_success "服务启动成功"
        
        # 显示服务状态
        echo ""
        systemctl status sentinelx-server --no-pager -l
    else
        print_error "服务启动失败"
        journalctl -u sentinelx-server -n 50 --no-pager
        exit 1
    fi
}

# 显示安装摘要
show_summary() {
    echo ""
    echo "========================================="
    echo "      SentinelX 安装完成！"
    echo "========================================="
    echo ""
    echo "服务信息:"
    echo "  - 服务状态: systemctl status sentinelx-server"
    echo "  - 启动服务: systemctl start sentinelx-server"
    echo "  - 停止服务: systemctl stop sentinelx-server"
    echo "  - 查看日志: journalctl -u sentinelx-server -f"
    echo ""
    echo "文件位置:"
    echo "  - 配置文件: /etc/sentinelx/config.yaml"
    echo "  - 加密密钥: /etc/sentinelx/keys/"
    echo "  - 日志文件: /var/lib/sentinelx/meg/"
    echo "  - 程序文件: /opt/sentinelx/bin/sentinelx-server"
    echo ""
    echo "访问地址:"
    echo "  - WebSocket: wss://你的服务器IP:8443/ws"
    echo "  - Metrics:   http://你的服务器IP:9090/metrics"
    echo ""
    echo "备份脚本:"
    echo "  - 手动备份: /opt/sentinelx/scripts/backup.sh"
    echo "  - 自动备份: 每天凌晨2点"
    echo ""
    echo "下一步:"
    echo "  1. 编辑配置文件: /etc/sentinelx/config.yaml"
    echo "  2. 配置客户端连接信息"
    echo "  3. 设置防火墙规则"
    echo ""
    echo "文档: https://github.com/Blacklight139/SentinelX"
    echo "========================================="
}

# 主安装流程
main() {
    echo "========================================="
    echo "   SentinelX 服务端安装程序"
    echo "========================================="
    echo ""
    
    check_root
    check_system
    
    # 安装步骤
    install_dependencies
    create_user
    create_directories
    download_source
    generate_keys
    compile_server
    configure_system
    configure_firewall
    create_backup_script
    create_monitor_script
    start_service
    show_summary
}

# 运行主函数
main "$@"