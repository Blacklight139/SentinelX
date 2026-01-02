#!/bin/bash

set -e

echo "========================================="
echo "   SentinelX 密钥生成工具"
echo "========================================="

# 创建目录
mkdir -p keys
chmod 700 keys

# 生成通信密钥对
echo "生成通信密钥对..."
openssl genrsa -out keys/communication_private.key 2048
openssl rsa -in keys/communication_private.key -pubout -out keys/communication_public.pem

# 生成访问日志密钥对
echo "生成访问日志密钥对..."
openssl genrsa -out keys/access_private.key 2048
openssl rsa -in keys/access_private.key -pubout -out keys/access_public.pem

# 生成服务端TLS证书
echo "生成TLS证书..."
openssl req -x509 -newkey rsa:2048 \
    -keyout keys/server.key \
    -out keys/server.crt \
    -days 3650 \
    -nodes \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=SentinelX/CN=sentinelx-server"

# 生成客户端证书（可选）
echo "生成客户端证书..."
openssl req -newkey rsa:2048 \
    -nodes \
    -keyout keys/client.key \
    -out keys/client.csr \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=SentinelX/CN=sentinelx-client"

openssl x509 -req \
    -in keys/client.csr \
    -CA keys/server.crt \
    -CAkey keys/server.key \
    -CAcreateserial \
    -out keys/client.crt \
    -days 3650

# 设置权限
chmod 600 keys/*.key
chmod 644 keys/*.crt keys/*.pem

# 生成客户端配置文件
cat > keys/client_config.json << EOF
{
    "server_address": "YOUR_SERVER_IP:8443",
    "public_key": "$(base64 -w 0 keys/communication_public.pem)",
    "access_public_key": "$(base64 -w 0 keys/access_public.pem)",
    "client_cert": "$(base64 -w 0 keys/client.crt)",
    "client_key": "$(base64 -w 0 keys/client.key)"
}
EOF

echo ""
echo "✅ 密钥生成完成！"
echo ""
echo "重要文件:"
echo "  - 服务端私钥: keys/server.key"
echo "  - 服务端证书: keys/server.crt"
echo "  - 通信私钥: keys/communication_private.key"
echo "  - 通信公钥: keys/communication_public.pem"
echo "  - 访问日志私钥: keys/access_private.key"
echo "  - 访问日志公钥: keys/access_public.pem"
echo "  - 客户端配置: keys/client_config.json"
echo ""
echo "⚠️  请妥善保管所有私钥文件！(包括服务端私钥和通信私钥, 任何泄露都可能导致安全风险, 请勿向他人透露,尤其是在公共场所或不受信任的环境中)"