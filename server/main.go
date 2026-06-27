package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"runtime"

	"sentinelx-server/internal/crypto"
	"sentinelx-server/internal/server"
)

func main() {
	var (
		configPath = flag.String("config", "config.yaml", "配置文件路径")
		genKeys    = flag.Bool("generate-keys", false, "生成新的密钥对")
		version    = flag.Bool("version", false, "显示版本信息")
		logLevel   = flag.String("log-level", "", "日志级别(debug, info, warn, error)")
	)
	flag.Parse()

	if *version {
		fmt.Printf("SentinelX v2.0.0 (Go %s)\n", runtime.Version())
		fmt.Printf("Build: %s\n", server.BuildInfo())
		return
	}

	if *genKeys {
		es, err := crypto.NewEncryptionSystem()
		if err != nil {
			log.Fatalf("生成密钥失败: %v", err)
		}
		log.Println("密钥已生成到 keys/ 目录")
		_ = es
		return
	}

	config, err := server.LoadConfig(*configPath)
	if err != nil {
		log.Fatalf("加载配置失败: %v", err)
	}

	if *logLevel != "" {
		config.Logging.Level = *logLevel
	}

	if err := os.MkdirAll(config.Server.LogDir, 0700); err != nil {
		log.Fatalf("创建日志目录失败: %v", err)
	}
	if err := os.MkdirAll(config.Server.DataDir, 0700); err != nil {
		log.Fatalf("创建数据目录失败: %v", err)
	}
	if err := os.MkdirAll("keys", 0700); err != nil {
		log.Fatalf("创建密钥目录失败: %v", err)
	}

	srv, err := server.NewServer(config)
	if err != nil {
		log.Fatalf("创建服务器失败: %v", err)
	}

	if err := srv.Start(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("服务器启动失败: %v", err)
	}
}
