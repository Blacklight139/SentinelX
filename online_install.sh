#!/bin/bash
# SentinelX 在线安装脚本 - 修复版
# 版本: v2.0.1

set -e

# ==================== 配置 ====================
REPO_SOURCE="https://gitee.com/dark-beam/SentinelX"
GITHUB_SOURCE="https://github.com/Blacklight139/SentinelX"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ==================== 主要安装函数 ====================
clone_and_install() {
    local temp_dir="/tmp/sentinelx_install_$$"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    log_info "克隆源代码仓库..."
    
    # 尝试从 Gitee 克隆
    if git clone --depth 1 "$REPO_SOURCE.git" .; then
        log_success "从 Gitee 克隆成功"
    elif git clone --depth 1 "$GITHUB_SOURCE.git" .; then
        log_success "从 GitHub 克隆成功"
    else
        log_error "克隆仓库失败，请检查网络连接"
        exit 1
    fi
    
    # 检查必要的文件
    if [ ! -d "server" ]; then
        log_error "仓库结构不正确，缺少 server 目录"
        exit 1
    fi
    
    cd server
    
    # 检查必要文件
    REQUIRED_FILES=("main.go" "config.yaml.example" "generate_keys.sh")
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "缺少必要文件: $file"
            exit 1
        fi
    done
    
    # 运行服务端安装脚本
    if [ -f "install.sh" ]; then
        chmod +x install.sh
        ./install.sh
    else
        log_error "缺少服务端安装脚本"
        exit 1
    fi
    
    # 清理
    cd /
    rm -rf "$temp_dir"
}

# ==================== 主函数 ====================
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║          SentinelX 在线安装程序 v2.0.1                  ║"
    echo "║          仓库: https://gitee.com/dark-beam/SentinelX    ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    # 检查 root 权限
    if [ "$EUID" -ne 0 ]; then 
        log_error "请使用 sudo 运行此脚本"
        echo "使用方法: curl -sSL https://gitee.com/dark-beam/SentinelX/raw/main/install.sh | sudo bash"
        exit 1
    fi
    
    # 安装 Git（如果需要）
    if ! command -v git &> /dev/null; then
        log_info "安装 Git..."
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y git
        elif command -v yum &> /dev/null; then
            yum install -y git
        elif command -v dnf &> /dev/null; then
            dnf install -y git
        else
            log_error "无法自动安装 Git，请手动安装"
            exit 1
        fi
    fi
    
    # 克隆并安装
    clone_and_install
    
    # 显示结果
    show_result
}

show_result() {
    local ip=$(hostname -I | awk '{print $1}' | head -n1)
    
    echo ""
    echo "✅ SentinelX 安装完成！"
    echo ""
    echo "📋 安装信息:"
    echo "   服务用户: sentinelx"
    echo "   安装目录: /opt/sentinelx"
    echo "   配置文件: /etc/sentinelx/config.yaml"
    echo "   数据目录: /var/lib/sentinelx/meg"
    echo "   日志目录: /var/log/sentinelx"
    echo ""
    echo "🌐 访问地址:"
    echo "   Web界面: https://${ip:-localhost}:8443"
    echo "   指标监控: http://${ip:-localhost}:9090/metrics"
    echo ""
    echo "🔧 管理命令:"
    echo "   启动服务: systemctl start sentinelx-server"
    echo "   停止服务: systemctl stop sentinelx-server"
    echo "   查看状态: systemctl status sentinelx-server"
    echo "   查看日志: journalctl -u sentinelx-server -f"
    echo ""
    echo "📚 文档: $REPO_SOURCE"
    echo ""
    echo "💡 下一步:"
    echo "   1. 编辑配置文件: /etc/sentinelx/config.yaml"
    echo "   2. 启动服务: systemctl start sentinelx-server"
    echo "   3. 设置开机启动: systemctl enable sentinelx-server"
    echo ""
}

# 执行主函数
main "$@"