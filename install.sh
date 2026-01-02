#!/bin/bash
# SentinelX 一键安装脚本
# Gitee: https://gitee.com/dark-beam/SentinelX
# GitHub: https://github.com/Blacklight139/SentinelX

set -e

echo "🚀 正在安装 SentinelX ..."

# 检测系统是否有 curl
if ! command -v curl >/dev/null 2>&1; then
    echo "📦 安装 curl ..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y curl
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl
    else
        echo "❌ 无法安装 curl，请手动安装后重试"
        exit 1
    fi
fi

# 下载完整的安装脚本
TEMP_SCRIPT="/tmp/sentinelx_installer_$$.sh"

echo "📥 下载安装程序..."
if curl -fsSL "https://gitee.com/dark-beam/SentinelX/raw/main/online_install.sh" -o "$TEMP_SCRIPT"; then
    echo "✅ 下载成功（使用 Gitee 镜像）"
elif curl -fsSL "https://raw.githubusercontent.com/Blacklight139/SentinelX/main/online_install.sh" -o "$TEMP_SCRIPT"; then
    echo "✅ 下载成功（使用 GitHub 镜像）"
else
    echo "❌ 下载失败，请检查网络连接"
    exit 1
fi

# 执行安装
chmod +x "$TEMP_SCRIPT"
bash "$TEMP_SCRIPT" "$@"

# 清理
rm -f "$TEMP_SCRIPT"
