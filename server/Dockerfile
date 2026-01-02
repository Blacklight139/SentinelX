# SentinelX 服务端 Dockerfile
FROM golang:1.19-alpine AS builder

# 设置工作目录
WORKDIR /app

# 安装构建依赖
RUN apk add --no-cache \
    git \
    openssl \
    ca-certificates

# 复制源代码
COPY . .

# 设置Go代理
ENV GOPROXY=https://goproxy.cn,direct

# 下载依赖
RUN go mod download

# 构建应用
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o sentinelx-server main.go

# 生成证书
RUN mkdir -p /app/keys && \
    cd /app/keys && \
    openssl req -x509 -newkey rsa:2048 \
        -keyout server.key \
        -out server.crt \
        -days 3650 \
        -nodes \
        -subj "/C=CN/ST=Beijing/L=Beijing/O=SentinelX/CN=sentinelx-server"

# 最终镜像
FROM alpine:latest

# 安装运行时依赖
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    openssl

# 创建非root用户
RUN addgroup -S sentinelx && \
    adduser -S sentinelx -G sentinelx

# 创建目录
RUN mkdir -p /app /var/lib/sentinelx/meg /var/lib/sentinelx/data && \
    chown -R sentinelx:sentinelx /app /var/lib/sentinelx

# 设置工作目录
WORKDIR /app

# 从构建阶段复制文件
COPY --from=builder /app/sentinelx-server .
COPY --from=builder /app/keys ./keys
COPY --from=builder /app/config.yaml.example ./config.yaml

# 复制脚本
COPY generate_keys.sh .

# 设置权限
RUN chmod +x sentinelx-server generate_keys.sh && \
    chmod 600 keys/*.key && \
    chown sentinelx:sentinelx keys/*.key

# 切换到非root用户
USER sentinelx

# 暴露端口
EXPOSE 8443 9090

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider https://localhost:8443/health || exit 1

# 启动命令
CMD ["./sentinelx-server", "--config", "config.yaml"]