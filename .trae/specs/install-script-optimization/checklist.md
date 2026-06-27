# SentinelX 安装脚本优化与功能延伸 - 验证清单

## 脚本结构验证
- [ ] install.sh 函数结构清晰，每个函数职责单一
- [ ] 支持 `--verbose` 调试模式
- [ ] 支持 `--skip-confirmation` 非交互模式

## 安装前检查验证
- [ ] 端口占用检测正常工作（8443, 9090, 6060）
- [ ] 依赖检测正常工作（curl, wget, tar, openssl, docker 等）
- [ ] 已安装状态检测正常工作
- [ ] 磁盘空间检查正常工作
- [ ] 网络连接检测正常工作
- [ ] 检测失败时正确退出

## 进度反馈验证
- [ ] 显示安装步骤计数（共 N 步）
- [ ] 成功/失败状态有明确图标
- [ ] 日志输出格式清晰

## 回滚机制验证
- [ ] 安装失败时正确清理已创建的资源
- [ ] Ctrl+C 中断时正确清理
- [ ] 卸载后无残留服务

## 卸载功能验证
- [ ] 标准卸载正常工作（保留配置）
- [ ] 完全卸载（--remove-config）正常工作
- [ ] 强制卸载（--force）正常工作
- [ ] 保留数据卸载（--keep-data）正常工作

## Docker 安装验证
- [ ] Docker 未安装时自动安装
- [ ] Docker 服务未运行时提示启动
- [ ] docker-compose.yml 正确下载和配置
- [ ] 镜像正确拉取
- [ ] 容器启动后健康检查通过
- [ ] 访问 https://localhost:8443/api/v1/health 返回 200

## 二进制安装验证
- [ ] 从 GitHub releases 下载正确版本
- [ ] SHA256 校验通过
- [ ] 密钥正确生成到 /etc/sentinelx/keys/
- [ ] systemd 服务正确配置
- [ ] 服务启动后健康检查通过
- [ ] 访问 https://localhost:8443/api/v1/health 返回 200

## 在线安装脚本验证
- [ ] online_install.sh 包含所有优化
- [ ] 可通过 curl 远程执行
- [ ] Go 1.25 安装支持正常

## 兼容性验证
- [ ] Ubuntu/Debian 系统安装正常
- [ ] CentOS/RHEL 系统安装正常
- [ ] Fedora 系统安装正常
