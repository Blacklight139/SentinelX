package api

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/sirupsen/logrus"

	"sentinelx-server/internal/monitor"
	"sentinelx-server/internal/safemap"
	"sentinelx-server/internal/storage"
	"sentinelx-server/internal/ws"
)

type Response struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

type APIHandler struct {
	logStorage  *storage.LogStorage
	frpMonitors *safemap.SafeMap[string, *monitor.FRPMonitor]
	wsHandler   *ws.WebSocketHandler
	startTime   time.Time
}

func NewAPIHandler(ls *storage.LogStorage, monitors *safemap.SafeMap[string, *monitor.FRPMonitor], ws *ws.WebSocketHandler) *APIHandler {
	return &APIHandler{
		logStorage:  ls,
		frpMonitors: monitors,
		wsHandler:   ws,
		startTime:   time.Now(),
	}
}

func (h *APIHandler) writeJSON(w http.ResponseWriter, status int, resp Response) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		logrus.WithError(err).Error("写入 JSON 响应失败")
	}
}

func (h *APIHandler) readJSON(r *http.Request, v interface{}) error {
	return json.NewDecoder(r.Body).Decode(v)
}

func (h *APIHandler) getQueryInt(r *http.Request, key string, defaultVal int) int {
	val := r.URL.Query().Get(key)
	if val == "" {
		return defaultVal
	}
	n, err := strconv.Atoi(val)
	if err != nil {
		return defaultVal
	}
	return n
}

func (h *APIHandler) getQueryString(r *http.Request, key string, defaultVal string) string {
	val := r.URL.Query().Get(key)
	if val == "" {
		return defaultVal
	}
	return val
}

func (h *APIHandler) HandleHealthCheck(w http.ResponseWriter, r *http.Request) {
	uptime := time.Since(h.startTime).String()
	data := map[string]interface{}{
		"status":  "ok",
		"version": "2.0.0",
		"uptime":  uptime,
	}
	h.writeJSON(w, http.StatusOK, Response{
		Code:    0,
		Message: "success",
		Data:    data,
	})
}

type logFileInfo struct {
	FileName string    `json:"file_name"`
	Size     int64     `json:"size"`
	ModTime  time.Time `json:"mod_time"`
}

func (h *APIHandler) HandleLogs(w http.ResponseWriter, r *http.Request) {
	page := h.getQueryInt(r, "page", 1)
	pageSize := h.getQueryInt(r, "page_size", 20)
	severity := h.getQueryString(r, "severity", "")
	eventType := h.getQueryString(r, "event_type", "")

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}

	var allLogs []logFileInfo

	if h.logStorage.LogDir() != "" {
		files, err := os.ReadDir(h.logStorage.LogDir())
		if err != nil {
			logrus.WithError(err).Error("读取日志目录失败")
			h.writeJSON(w, http.StatusInternalServerError, Response{
				Code:    500,
				Message: "读取日志目录失败",
			})
			return
		}

		for _, file := range files {
			if file.IsDir() {
				continue
			}
			info, err := file.Info()
			if err != nil {
				continue
			}
			allLogs = append(allLogs, logFileInfo{
				FileName: file.Name(),
				Size:     info.Size(),
				ModTime:  info.ModTime(),
			})
		}

		for i := 0; i < len(allLogs)-1; i++ {
			for j := i + 1; j < len(allLogs); j++ {
				if allLogs[i].ModTime.Before(allLogs[j].ModTime) {
					allLogs[i], allLogs[j] = allLogs[j], allLogs[i]
				}
			}
		}
	}

	if severity != "" || eventType != "" {
		var filtered []logFileInfo
		for _, log := range allLogs {
			if severity != "" && !matchSeverity(log.FileName, severity) {
				continue
			}
			if eventType != "" && !matchEventType(log.FileName, eventType) {
				continue
			}
			filtered = append(filtered, log)
		}
		allLogs = filtered
	}

	total := len(allLogs)
	start := (page - 1) * pageSize
	end := start + pageSize

	if start > total {
		start = total
	}
	if end > total {
		end = total
	}

	pagedLogs := allLogs[start:end]
	if pagedLogs == nil {
		pagedLogs = []logFileInfo{}
	}

	data := map[string]interface{}{
		"logs":      pagedLogs,
		"total":     total,
		"page":      page,
		"page_size": pageSize,
	}

	h.writeJSON(w, http.StatusOK, Response{
		Code:    0,
		Message: "success",
		Data:    data,
	})
}

func matchSeverity(filename, severity string) bool {
	if len(filename) == 0 {
		return false
	}
	return true
}

func matchEventType(filename, eventType string) bool {
	if len(filename) == 0 {
		return false
	}
	return true
}

func (h *APIHandler) HandleStats(w http.ResponseWriter, r *http.Request) {
	var totalConnections int64
	var activeConnections int64
	var totalBytes int64
	var securityEvents int64
	var storageSize int64
	var logCount int64
	var monitorCount int

	if h.frpMonitors != nil {
		h.frpMonitors.Range(func(key string, m *monitor.FRPMonitor) bool {
			monitorCount++
			stats := m.Stats()
			if bytesTotal, ok := stats["bytes_total"].(int64); ok {
				totalBytes += bytesTotal
			}
			if connActive, ok := stats["connections_active"].(int64); ok {
				activeConnections += connActive
			}
			return true
		})
	}

	if h.logStorage.LogDir() != "" {
		filepath.Walk(h.logStorage.LogDir(), func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return nil
			}
			if !info.IsDir() {
				logCount++
				storageSize += info.Size()
			}
			return nil
		})
	}

	data := map[string]interface{}{
		"total_connections":   totalConnections,
		"active_connections":  activeConnections,
		"total_traffic_bytes": totalBytes,
		"security_events":     securityEvents,
		"storage_size_bytes":  storageSize,
		"log_count":           logCount,
		"monitor_count":       monitorCount,
	}

	h.writeJSON(w, http.StatusOK, Response{
		Code:    0,
		Message: "success",
		Data:    data,
	})
}

type startMonitorRequest struct {
	ListenPort    int                     `json:"listen_port"`
	TargetAddress string                  `json:"target_address"`
	Protocol      string                  `json:"protocol"`
	Rules         []monitor.DetectionRule `json:"rules"`
}

func (h *APIHandler) HandleStartMonitor(w http.ResponseWriter, r *http.Request) {
	var req startMonitorRequest
	if err := h.readJSON(r, &req); err != nil {
		h.writeJSON(w, http.StatusBadRequest, Response{
			Code:    400,
			Message: "无效的请求体",
		})
		return
	}

	if req.ListenPort <= 0 || req.ListenPort > 65535 {
		h.writeJSON(w, http.StatusBadRequest, Response{
			Code:    400,
			Message: "无效的监听端口",
		})
		return
	}

	if req.TargetAddress == "" {
		h.writeJSON(w, http.StatusBadRequest, Response{
			Code:    400,
			Message: "目标地址不能为空",
		})
		return
	}

	monitorID := fmt.Sprintf("monitor_%d_%d", req.ListenPort, time.Now().Unix())

	if h.frpMonitors != nil {
		if _, exists := h.frpMonitors.Get(monitorID); exists {
			h.writeJSON(w, http.StatusConflict, Response{
				Code:    409,
				Message: "监控已存在",
			})
			return
		}
	}

	cfg := monitor.MonitorConfig{
		ListenPort:    req.ListenPort,
		TargetAddress: req.TargetAddress,
		Protocol:      req.Protocol,
		Rules:         req.Rules,
	}

	frpMonitor, err := monitor.NewFRPMonitor(cfg, h.logStorage)
	if err != nil {
		logrus.WithError(err).Error("创建监控失败")
		h.writeJSON(w, http.StatusInternalServerError, Response{
			Code:    500,
			Message: "创建监控失败",
		})
		return
	}

	if err := frpMonitor.Start(); err != nil {
		logrus.WithError(err).Error("启动监控失败")
		h.writeJSON(w, http.StatusInternalServerError, Response{
			Code:    500,
			Message: "启动监控失败: " + err.Error(),
		})
		return
	}

	if h.frpMonitors != nil {
		h.frpMonitors.Set(monitorID, frpMonitor)
	}

	data := map[string]interface{}{
		"monitor_id": monitorID,
		"status":     "started",
	}

	h.writeJSON(w, http.StatusOK, Response{
		Code:    0,
		Message: "success",
		Data:    data,
	})
}

type stopMonitorRequest struct {
	MonitorID string `json:"monitor_id"`
}

func (h *APIHandler) HandleStopMonitor(w http.ResponseWriter, r *http.Request) {
	var req stopMonitorRequest
	if err := h.readJSON(r, &req); err != nil {
		h.writeJSON(w, http.StatusBadRequest, Response{
			Code:    400,
			Message: "无效的请求体",
		})
		return
	}

	if req.MonitorID == "" {
		h.writeJSON(w, http.StatusBadRequest, Response{
			Code:    400,
			Message: "监控 ID 不能为空",
		})
		return
	}

	if h.frpMonitors == nil {
		h.writeJSON(w, http.StatusNotFound, Response{
			Code:    404,
			Message: "监控不存在",
		})
		return
	}

	frpMonitor, exists := h.frpMonitors.Get(req.MonitorID)
	if !exists {
		h.writeJSON(w, http.StatusNotFound, Response{
			Code:    404,
			Message: "监控不存在",
		})
		return
	}

	if err := frpMonitor.Stop(); err != nil {
		logrus.WithError(err).Error("停止监控失败")
		h.writeJSON(w, http.StatusInternalServerError, Response{
			Code:    500,
			Message: "停止监控失败: " + err.Error(),
		})
		return
	}

	h.frpMonitors.Delete(req.MonitorID)

	data := map[string]interface{}{
		"monitor_id": req.MonitorID,
		"status":     "stopped",
	}

	h.writeJSON(w, http.StatusOK, Response{
		Code:    0,
		Message: "success",
		Data:    data,
	})
}
