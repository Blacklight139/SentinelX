#!/bin/bash

# SentinelX 服务端安装脚本（本地安装）

set -e

echo "🔧 正在安装 SentinelX 服务端..."

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 请使用sudo运行此脚本"
    exit 1
fi

# 默认安装路径
INSTALL_DIR="/opt/sentinelx"
CONFIG_DIR="/etc/sentinelx"
DATA_DIR="/var/lib/sentinelx"
LOG_DIR="/var/log/sentinelx"
SERVICE_USER="sentinelx"

# 安装依赖
echo "📦 安装系统依赖..."
apt-get update
apt-get install -y curl wget tar gzip openssl ca-certificates

# 创建系统用户
echo "👤 创建系统用户..."
if ! id "$SERVICE_USER" &>/dev/null; then
    useradd -r -s /bin/false -M -d "$INSTALL_DIR" "$SERVICE_USER"
fi

# 创建目录结构
echo "📁 创建目录..."
mkdir -p "$INSTALL_DIR/bin"
mkdir -p "$CONFIG_DIR/keys"
mkdir -p "$DATA_DIR/meg"
mkdir -p "$LOG_DIR"

# 复制文件
echo "📄 复制配置文件..."
if [ -f "config.yaml.example" ]; then
    cp config.yaml.example "$CONFIG_DIR/config.yaml"
    chmod 640 "$CONFIG_DIR/config.yaml"
fi

# 生成密钥
echo "🔑 生成加密密钥..."
if [ -f "generate_keys.sh" ]; then
    chmod +x generate_keys.sh
    ./generate_keys.sh
    
    # 移动密钥到配置目录
    if [ -d "keys" ]; then
        mv keys/* "$CONFIG_DIR/keys/"
        chmod 600 "$CONFIG_DIR/keys/"*.key
        rm -rf keys
    fi
fi

# 复制服务文件
echo "⚙️ 配置系统服务..."
if [ -f "sentinelx-server.service" ]; then
    cp sentinelx-server.service /etc/systemd/system/
    sed -i "s|/opt/sentinelx|$INSTALL_DIR|g" /etc/systemd/system/sentinelx-server.service
    systemctl daemon-reload
fi

# 设置权限
echo "🔒 设置文件权限..."
chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR" "$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR"
chmod 750 "$INSTALL_DIR" "$DATA_DIR" "$LOG_DIR"
chmod 700 "$DATA_DIR/meg"

# 编译服务端（如果有Go环境）
echo "🛠️ 编译服务端程序..."
if command -v go &> /dev/null; then
    go build -o "$INSTALL_DIR/bin/sentinelx-server" main.go
    chmod +x "$INSTALL_DIR/bin/sentinelx-server"
    chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/bin/sentinelx-server"
else
    echo "⚠️  Go未安装，请手动编译或下载预编译版本"
    echo "   安装Go: apt-get install -y golang-go"
fi

echo ""
echo "✅ 安装完成！"
echo ""
echo "下一步操作："
echo "  1. 编辑配置文件: $CONFIG_DIR/config.yaml"
echo "  2. 启动服务: systemctl start sentinelx-server"
echo "  3. 设置开机启动: systemctl enable sentinelx-server"
echo ""echo "📄 更多信息请访问: https://gitee.com/dark-beam/SentinelX 