#!/bin/bash
# SentinelX 在线安装脚本

# ... 省略其他部分 ...

check_go_version() {
    if command -v go &> /dev/null; then
        local go_version=$(go version | awk '{print $3}' | sed 's/go//')
        local required_version="1.25.0"
        
        # 使用版本比较
        if [ "$(printf '%s\n' "$required_version" "$go_version" | sort -V | head -n1)" = "$required_version" ]; then
            log_success "Go 版本满足要求: $go_version"
            return 0
        else
            log_warning "Go 版本过低: $go_version (需要 >= $required_version)"
            return 1
        fi
    fi
    return 1
}

install_go_1_25() {
    log_info "安装 Go 1.25.5..."
    
    local arch=$(uname -m)
    case $arch in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l) arch="armv6l" ;;
        *) arch="amd64" ;;
    esac
    
    local go_tar="go1.25.5.linux-$arch.tar.gz"
    local go_url="https://go.dev/dl/$go_tar"
    
    # 下载 Go
    cd /tmp
    if ! curl -fsSL "$go_url" -o "$go_tar"; then
        log_error "下载 Go 失败"
        return 1
    fi
    
    # 删除旧版本
    if [ -d "/usr/local/go" ]; then
        rm -rf /usr/local/go
    fi
    
    # 安装新版本
    tar -C /usr/local -xzf "$go_tar"
    
    # 设置环境变量
    if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    fi
    if ! grep -q "/usr/local/go/bin" /etc/profile; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    fi
    
    export PATH=$PATH:/usr/local/go/bin
    source ~/.bashrc
    
    # 验证安装
    if go version | grep -q "go1.25"; then
        log_success "Go 1.25.5 安装成功"
        return 0
    else
        log_error "Go 安装失败"
        return 1
    fi
}

# 在主函数中添加 Go 版本检查
main() {
    # ... 省略其他部分 ...
    
    # 检查 Go 版本
    if ! check_go_version; then
        log_info "安装或更新 Go 到 1.25.5..."
        install_go_1_25
    fi
    
    # ... 省略其他部分 ...
}