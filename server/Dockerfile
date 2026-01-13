# SentinelX 服务端 Dockerfile
# 使用 Go 1.25.5

# 构建阶段
FROM golang:1.25.5-alpine AS builder

# 安装构建依赖
RUN apk add --no-cache \
    git \
    make \
    gcc \
    musl-dev \
    openssl

# 设置工作目录
WORKDIR /app

# 复制 go.mod 和 go.sum
COPY server/go.mod server/go.sum ./

# 下载依赖（使用国内镜像加速）
RUN go env -w GOPROXY=https://goproxy.cn,direct
RUN go mod download

# 复制源代码
COPY server/ ./

# 构建应用
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w -X main.Version=2.0.0 -X main.BuildTime=$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    -o sentinelx-server main.go

# 生成最小证书
RUN mkdir -p keys && \
    cd keys && \
    openssl req -x509 -newkey rsa:2048 \
        -keyout server.key \
        -out server.crt \
        -days 365 \
        -nodes \
        -subj "/C=CN/ST=Beijing/L=Beijing/O=SentinelX/CN=sentinelx-server"

# 最终镜像
FROM alpine:3.19

# 安装运行时依赖
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    openssl \
    curl

# 创建非root用户
RUN addgroup -S sentinelx && \
    adduser -S sentinelx -G sentinelx

# 创建目录结构
RUN mkdir -p /app /etc/sentinelx/keys /var/lib/sentinelx/meg /var/log/sentinelx && \
    chown -R sentinelx:sentinelx /app /etc/sentinelx /var/lib/sentinelx /var/log/sentinelx

# 设置工作目录
WORKDIR /app

# 从构建阶段复制文件
COPY --from=builder /app/sentinelx-server .
COPY --from=builder /app/keys/ ./keys/
COPY --from=builder /app/config.yaml.example ./config.yaml.example

# 复制启动脚本
COPY --from=builder /app/generate_keys.sh .
RUN chmod +x generate_keys.sh

# 设置权限
RUN chmod +x sentinelx-server && \
    chmod 600 keys/*.key && \
    chown sentinelx:sentinelx keys/*.key

# 切换到非root用户
USER sentinelx

# 暴露端口
EXPOSE 8443  # HTTPS
EXPOSE 9090  # Metrics
EXPOSE 6060  # Pprof

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -k -f https://localhost:8443/api/v1/health || exit 1

# 启动命令
CMD ["./sentinelx-server", "--config", "config.yaml"]