#!/bin/bash

# SentinelX 构建脚本 - 支持 Go 1.25.5 和多平台

set -e

echo "🔨 构建 SentinelX (Go 1.25.5+)..."

# 检查 Go 版本
GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
REQUIRED_VERSION="1.25.0"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$GO_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "❌ 需要 Go >= $REQUIRED_VERSION，当前版本: $GO_VERSION"
    exit 1
fi

echo "🐹 Go 版本: $GO_VERSION"

# 清理旧的构建
echo "🧹 清理旧的构建..."
rm -rf build/ release/
mkdir -p build/ release/

# 下载依赖
echo "📦 下载依赖..."
go mod download

# 运行测试
echo "🧪 运行测试..."
go test -v -cover -race ./...

# 构建主程序 (当前平台)
echo "🛠️ 构建主程序..."
CGO_ENABLED=0 go build \
    -ldflags="-s -w \
        -X main.Version=${VERSION:-dev} \
        -X main.BuildTime=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
        -X main.GoVersion=$GO_VERSION" \
    -o build/sentinelx-server \
    main.go

# 构建各平台版本
echo "🌍 构建多平台版本..."
platforms=("linux/amd64" "linux/arm64" "linux/arm" "windows/amd64" "darwin/amd64" "darwin/arm64")

for platform in "${platforms[@]}"; do
    GOOS=${platform%/*}
    GOARCH=${platform#*/}
    
    output_name="sentinelx-server-$GOOS-$GOARCH"
    if [ "$GOOS" = "windows" ]; then
        output_name="$output_name.exe"
    fi
    
    echo "  构建 $GOOS/$GOARCH..."
    GOOS=$GOOS GOARCH=$GOARCH CGO_ENABLED=0 \
        go build \
        -ldflags="-s -w \
            -X main.Version=${VERSION:-dev} \
            -X main.BuildTime=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
            -X main.GoVersion=$GO_VERSION" \
        -o "build/$output_name" \
        main.go
    
    # 创建发布包
    if [ "$GOOS" != "windows" ]; then
        create_release_package "$GOOS" "$GOARCH"
    fi
done

# 创建发布包函数
create_release_package() {
    local GOOS=$1
    local GOARCH=$2
    
    echo "📦 创建 $GOOS/$GOARCH 发布包..."
    
    local pkg_dir="release/sentinelx-server-$GOOS-$GOARCH"
    mkdir -p "$pkg_dir"
    
    # 复制二进制文件
    local bin_name="sentinelx-server"
    if [ "$GOOS" = "windows" ]; then
        bin_name="sentinelx-server.exe"
    fi
    
    cp "build/sentinelx-server-$GOOS-$GOARCH" "$pkg_dir/$bin_name"
    chmod +x "$pkg_dir/$bin_name"
    
    # 复制配置文件
    cp config.yaml.example "$pkg_dir/config.yaml.example"
    cp generate_keys.sh "$pkg_dir/"
    cp sentinelx-server.service "$pkg_dir/"
    cp ../LICENSE "$pkg_dir/"
    cp ../README.md "$pkg_dir/"
    
    # 创建安装脚本
    cat > "$pkg_dir/install.sh" << 'EOF'
#!/bin/bash
# SentinelX Installer

set -e

echo "🚀 Installing SentinelX..."

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)

# 安装依赖
echo "📦 Installing dependencies..."
case $OS in
    ubuntu|debian)
        apt-get update
        apt-get install -y openssl curl
        ;;
    centos|rhel|fedora|rocky)
        yum install -y openssl curl
        ;;
    *)
        echo "⚠️  Unknown OS, you may need to install dependencies manually"
        ;;
esac

# 创建目录
echo "📁 Creating directories..."
mkdir -p /opt/sentinelx/bin
mkdir -p /etc/sentinelx
mkdir -p /var/lib/sentinelx/meg
mkdir -p /var/log/sentinelx

# 复制文件
echo "📄 Copying files..."
cp sentinelx-server /opt/sentinelx/bin/
chmod +x /opt/sentinelx/bin/sentinelx-server

# 创建用户
echo "👤 Creating user..."
if ! id sentinelx &>/dev/null; then
    useradd -r -s /bin/false -M -d /opt/sentinelx sentinelx
fi

# 设置权限
echo "🔒 Setting permissions..."
chown -R sentinelx:sentinelx /opt/sentinelx /var/lib/sentinelx /var/log/sentinelx

# 生成密钥
echo "🔑 Generating encryption keys..."
if [ -f generate_keys.sh ]; then
    chmod +x generate_keys.sh
    ./generate_keys.sh
    mkdir -p /etc/sentinelx/keys
    cp -r keys/* /etc/sentinelx/keys/ 2>/dev/null || true
    chmod 600 /etc/sentinelx/keys/*.key 2>/dev/null || true
    chown -R sentinelx:sentinelx /etc/sentinelx
fi

# 配置服务
echo "⚙️ Configuring service..."
if [ -f sentinelx-server.service ]; then
    cp sentinelx-server.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable sentinelx-server
    echo "✅ Service configured"
fi

echo ""
echo "🎉 SentinelX installed successfully!"
echo ""
echo "📋 Next steps:"
echo "   1. Edit configuration: /etc/sentinelx/config.yaml"
echo "   2. Start service: systemctl start sentinelx-server"
echo "   3. Check status: systemctl status sentinelx-server"
echo "   4. View logs: journalctl -u sentinelx-server -f"
echo ""
echo "📚 Documentation: https://gitee.com/dark-beam/SentinelX"
EOF
    
    chmod +x "$pkg_dir/install.sh"
    
    # 打包
    cd release
    if [ "$GOOS" = "windows" ]; then
        zip -r "sentinelx-server-$GOOS-$GOARCH.zip" "sentinelx-server-$GOOS-$GOARCH"
    else
        tar -czf "sentinelx-server-$GOOS-$GOARCH.tar.gz" "sentinelx-server-$GOOS-$GOARCH"
    fi
    cd ..
    
    echo "✅ $GOOS/$GOARCH 发布包创建完成"
}

# 生成 checksums
echo "🔍 生成校验和..."
cd build
sha256sum * > checksums.sha256
mv checksums.sha256 ../release/
cd ..

echo ""
echo "✅ 构建完成！"
echo ""
echo "📁 构建输出:"
ls -la build/
echo ""
echo "📦 发布包:"
ls -la release/
echo ""
echo "🐹 Go 版本: $GO_VERSION"
echo "📦 二进制文件数量: $(ls build/ | wc -l)"