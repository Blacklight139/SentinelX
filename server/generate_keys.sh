#!/bin/bash

# SentinelX 密钥生成脚本
# 兼容 Go 1.25 的加密标准

set -e

echo "🔑 生成 SentinelX 加密密钥..."
echo "📅 日期: $(date)"
echo "🐹 Go 版本: $(go version)"

# 创建目录
mkdir -p keys
chmod 700 keys

# 生成通信密钥对
echo "📡 生成通信密钥对 (RSA 2048)..."

# 生成私钥
openssl genrsa -out keys/communication_private.pem 2048

# 生成 PKCS8 格式的私钥（Go 1.25 推荐）
openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt \
    -in keys/communication_private.pem \
    -out keys/communication_private_pkcs8.pem

# 生成公钥
openssl rsa -in keys/communication_private.pem -pubout \
    -out keys/communication_public.pem

# 生成访问日志密钥对
echo "📝 生成访问日志密钥对 (RSA 2048)..."

openssl genrsa -out keys/access_private.pem 2048
openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt \
    -in keys/access_private.pem \
    -out keys/access_private_pkcs8.pem
openssl rsa -in keys/access_private.pem -pubout \
    -out keys/access_public.pem

# 生成 TLS 证书（使用 ECDSA P-256，更安全更快速）
echo "🔒 生成 TLS 证书 (ECDSA P-256)..."

# 生成 ECDSA 私钥
openssl ecparam -name prime256v1 -genkey -noout \
    -out keys/server_ecdsa.key

# 生成证书签名请求
openssl req -new -key keys/server_ecdsa.key \
    -out keys/server_ecdsa.csr \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=SentinelX/CN=sentinelx-server"

# 生成自签名证书
openssl x509 -req -days 3650 \
    -in keys/server_ecdsa.csr \
    -signkey keys/server_ecdsa.key \
    -out keys/server_ecdsa.crt

# 也生成 RSA 证书（向后兼容）
echo "🔐 生成 RSA 证书 (向后兼容)..."

openssl req -x509 -newkey rsa:2048 \
    -keyout keys/server_rsa.key \
    -out keys/server_rsa.crt \
    -days 3650 \
    -nodes \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=SentinelX/CN=sentinelx-server"

# 生成客户端证书
echo "👤 生成客户端证书..."

openssl req -newkey rsa:2048 \
    -nodes \
    -keyout keys/client.key \
    -out keys/client.csr \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=SentinelX/CN=sentinelx-client"

openssl x509 -req \
    -in keys/client.csr \
    -CA keys/server_rsa.crt \
    -CAkey keys/server_rsa.key \
    -CAcreateserial \
    -out keys/client.crt \
    -days 3650

# 生成 Diffie-Hellman 参数
echo "🔄 生成 Diffie-Hellman 参数..."

openssl dhparam -out keys/dhparam.pem 2048

# 创建配置文件
echo "📄 创建密钥配置文件..."

cat > keys/keys_info.json << EOF
{
    "version": "1.0",
    "generated_at": "$(date -Iseconds)",
    "go_version": "$(go version)",
    "keys": {
        "communication": {
            "private_key": "keys/communication_private_pkcs8.pem",
            "public_key": "keys/communication_public.pem",
            "algorithm": "RSA-2048",
            "format": "PKCS8/PEM"
        },
        "access_log": {
            "private_key": "keys/access_private_pkcs8.pem",
            "public_key": "keys/access_public.pem",
            "algorithm": "RSA-2048",
            "format": "PKCS8/PEM"
        },
        "tls": {
            "ecdsa": {
                "certificate": "keys/server_ecdsa.crt",
                "private_key": "keys/server_ecdsa.key",
                "algorithm": "ECDSA-P256"
            },
            "rsa": {
                "certificate": "keys/server_rsa.crt",
                "private_key": "keys/server_rsa.key",
                "algorithm": "RSA-2048"
            }
        },
        "dh_params": "keys/dhparam.pem"
    }
}
EOF

# 设置权限
chmod 600 keys/*.key keys/*.pem
chmod 644 keys/*.crt keys/*.csr keys/keys_info.json

# 生成 SHA256 校验和
echo "🔍 生成校验和..."

cd keys
sha256sum *.pem *.key *.crt > checksums.sha256
cd ..

echo ""
echo "✅ 密钥生成完成！"
echo ""
echo "📁 生成的密钥文件:"
echo ""
ls -la keys/
echo ""
echo "⚠️  重要提示:"
echo "   1. 私钥文件 (*.key, *.pem) 已经设置为 600 权限"
echo "   2. 证书文件 (*.crt) 已经设置为 644 权限"
echo "   3. 请妥善保管所有私钥文件！"
echo "   4. 生产环境建议使用受信任的 CA 颁发的证书"
echo ""
echo "🔧 推荐配置:"
echo "   TLS 证书: keys/server_ecdsa.crt 和 keys/server_ecdsa.key"
echo "   通信密钥: keys/communication_private_pkcs8.pem"
echo "   访问密钥: keys/access_private_pkcs8.pem"
echo ""
echo ""
echo "⚠️  请妥善保管所有私钥文件！(包括服务端私钥和通信私钥, 任何泄露都可能导致安全风险, 请勿向他人透露,尤其是在公共场所或不受信任的环境中)"