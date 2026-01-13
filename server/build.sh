#!/bin/bash

# SentinelX Go 1.25 构建脚本

set -e

echo "🔨 构建 SentinelX (Go 1.25.5)..."

# 检查 Go 版本
GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
REQUIRED_VERSION="1.25.0"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$GO_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "❌ 需要 Go >= $REQUIRED_VERSION，当前版本: $GO_VERSION"
    exit 1
fi

# 清理旧的构建
echo "🧹 清理旧的构建..."
rm -rf build/
mkdir -p build/

# 下载依赖
echo "📦 下载依赖..."
go mod download

# 运行测试
echo "🧪 运行测试..."
go test -v ./...

# 构建主程序
echo "🛠️ 构建主程序..."
CGO_ENABLED=0 go build \
    -ldflags="-s -w \
        -X main.Version=2.0.0 \
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
            -X main.Version=2.0.0 \
            -X main.BuildTime=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
            -X main.GoVersion=$GO_VERSION" \
        -o "build/$output_name" \
        main.go
done

# 生成 checksums
echo "🔍 生成校验和..."
cd build
sha256sum * > checksums.sha256
cd ..

echo ""
echo "✅ 构建完成！"
echo ""
echo "📁 构建输出:"
ls -la build/
echo ""
echo "🐹 Go 版本: $GO_VERSION"
echo "📦 二进制文件数量: $(ls build/ | wc -l)"