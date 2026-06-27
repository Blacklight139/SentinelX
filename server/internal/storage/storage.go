package storage

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/sirupsen/logrus"

	"sentinelx-server/internal/cache"
	"sentinelx-server/internal/crypto"
	"sentinelx-server/internal/models"
	"sentinelx-server/internal/safemap"
	"sentinelx-server/internal/utils"
)

type LogStorage struct {
	logDir       string
	es           *crypto.EncryptionSystem
	logCache     *cache.Cache[string, []byte]
	accessTokens *safemap.SafeMap[string, bool]
	metrics      struct {
		logsStored     prometheus.Counter
		storageSize    prometheus.Gauge
		encryptionTime prometheus.Histogram
	}
}

func NewLogStorage(logDir string, es *crypto.EncryptionSystem) (*LogStorage, error) {
	if err := os.MkdirAll(logDir, 0700); err != nil {
		return nil, fmt.Errorf("创建日志目录失败: %w", err)
	}

	ls := &LogStorage{
		logDir:       logDir,
		es:           es,
		logCache:     cache.NewCache[string, []byte](500),
		accessTokens: safemap.NewSafeMap[string, bool](),
	}

	ls.metrics.logsStored = promauto.NewCounter(prometheus.CounterOpts{
		Name: "sentinelx_logs_stored_total",
		Help: "存储的日志总数",
	})

	ls.metrics.storageSize = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "sentinelx_storage_size_bytes",
		Help: "日志存储大小",
	})

	ls.metrics.encryptionTime = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "sentinelx_encryption_time_seconds",
		Help:    "加密耗时",
		Buckets: prometheus.DefBuckets,
	})

	go ls.startCleanupTask()

	return ls, nil
}

func (ls *LogStorage) startCleanupTask() {
	ticker := time.NewTicker(1 * time.Hour)
	defer ticker.Stop()

	for range ticker.C {
		ls.cleanupExpiredTokens()
		ls.updateStorageMetrics()
	}
}

func (ls *LogStorage) cleanupExpiredTokens() {
}

func (ls *LogStorage) updateStorageMetrics() {
	var totalSize int64
	filepath.Walk(ls.logDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			totalSize += info.Size()
		}
		return nil
	})

	ls.metrics.storageSize.Set(float64(totalSize))
}

func (ls *LogStorage) LogDir() string {
	return ls.logDir
}

func (ls *LogStorage) StoreTrafficLog(log models.TrafficLog) error {
	start := time.Now()
	defer func() {
		ls.metrics.encryptionTime.Observe(time.Since(start).Seconds())
	}()

	if log.EventID == "" {
		log.EventID = utils.GenerateUUID()
	}

	data, err := json.Marshal(log)
	if err != nil {
		return fmt.Errorf("序列化日志失败: %w", err)
	}

	encryptedData, err := ls.es.EncryptWithKey(data, ls.es.CommPublicKey())
	if err != nil {
		return fmt.Errorf("加密日志失败: %w", err)
	}

	filename := fmt.Sprintf("traffic_%s_%s.enc",
		time.Now().Format("20060102_150405"),
		log.PacketSignature[:8],
	)

	filePath := filepath.Join(ls.logDir, filename)
	if err := os.WriteFile(filePath, encryptedData, 0600); err != nil {
		return fmt.Errorf("写入日志文件失败: %w", err)
	}

	ls.metrics.logsStored.Inc()

	ls.logCache.Set(log.EventID, encryptedData, 24*time.Hour)

	logrus.WithFields(logrus.Fields{
		"event_id":   log.EventID,
		"file":       filename,
		"size_bytes": len(encryptedData),
	}).Info("已存储流量日志")

	return nil
}
