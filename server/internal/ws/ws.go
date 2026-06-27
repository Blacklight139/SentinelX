package ws

import (
	"encoding/json"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/sirupsen/logrus"

	"sentinelx-server/internal/models"
	"sentinelx-server/internal/safemap"
	"sentinelx-server/internal/storage"
	"sentinelx-server/internal/utils"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = 30 * time.Second
	maxMessageSize = 512
)

type WebSocketHandler struct {
	clients    *safemap.SafeMap[string, *Client]
	logStorage *storage.LogStorage
	upgrader   websocket.Upgrader
	broadcast  chan models.TrafficLog
}

type Client struct {
	conn          *websocket.Conn
	id            string
	send          chan []byte
	subscriptions map[string]bool
	once          sync.Once
}

type wsMessage struct {
	Type      string   `json:"type"`
	EventTypes []string `json:"event_types,omitempty"`
}

func NewWebSocketHandler(ls *storage.LogStorage) *WebSocketHandler {
	h := &WebSocketHandler{
		clients:    safemap.NewSafeMap[string, *Client](),
		logStorage: ls,
		upgrader: websocket.Upgrader{
			ReadBufferSize:  1024,
			WriteBufferSize: 1024,
			CheckOrigin: func(r *http.Request) bool {
				return true
			},
		},
		broadcast: make(chan models.TrafficLog, 256),
	}

	go h.runBroadcast()

	return h
}

func (h *WebSocketHandler) HandleConnection(w http.ResponseWriter, r *http.Request) {
	conn, err := h.upgrader.Upgrade(w, r, nil)
	if err != nil {
		logrus.WithError(err).Error("WebSocket 升级失败")
		return
	}

	clientID := utils.GenerateUUID()
	client := &Client{
		conn:          conn,
		id:            clientID,
		send:          make(chan []byte, 256),
		subscriptions: make(map[string]bool),
	}

	h.clients.Set(clientID, client)

	logrus.WithField("client_id", clientID).Info("WebSocket 客户端已连接")

	go h.writePump(client)
	go h.readPump(client)
}

func (h *WebSocketHandler) BroadcastLog(log models.TrafficLog) {
	h.broadcast <- log
}

func (h *WebSocketHandler) runBroadcast() {
	for log := range h.broadcast {
		data, err := json.Marshal(log)
		if err != nil {
			logrus.WithError(err).Error("序列化广播日志失败")
			continue
		}

		h.clients.Range(func(clientID string, client *Client) bool {
			if client.subscriptions[log.EventType] {
				select {
				case client.send <- data:
				default:
					h.removeClient(client)
				}
			}
			return true
		})
	}
}

func (h *WebSocketHandler) readPump(client *Client) {
	defer func() {
		h.removeClient(client)
	}()

	client.conn.SetReadLimit(maxMessageSize)
	client.conn.SetReadDeadline(time.Now().Add(pongWait))
	client.conn.SetPongHandler(func(string) error {
		client.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, message, err := client.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				logrus.WithError(err).WithField("client_id", client.id).Error("WebSocket 读取错误")
			}
			break
		}

		var msg wsMessage
		if err := json.Unmarshal(message, &msg); err != nil {
			logrus.WithError(err).WithField("client_id", client.id).Warn("解析 WebSocket 消息失败")
			continue
		}

		switch msg.Type {
		case "subscribe":
			for _, eventType := range msg.EventTypes {
				client.subscriptions[eventType] = true
			}
			logrus.WithFields(logrus.Fields{
				"client_id":   client.id,
				"event_types": msg.EventTypes,
			}).Info("客户端订阅日志类型")
		case "unsubscribe":
			for _, eventType := range msg.EventTypes {
				delete(client.subscriptions, eventType)
			}
			logrus.WithFields(logrus.Fields{
				"client_id":   client.id,
				"event_types": msg.EventTypes,
			}).Info("客户端取消订阅日志类型")
		case "ping":
		default:
			logrus.WithFields(logrus.Fields{
				"client_id": client.id,
				"msg_type":  msg.Type,
			}).Warn("未知的消息类型")
		}
	}
}

func (h *WebSocketHandler) writePump(client *Client) {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		client.conn.Close()
	}()

	for {
		select {
		case message, ok := <-client.send:
			client.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				client.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := client.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			if err := w.Close(); err != nil {
				return
			}
		case <-ticker.C:
			client.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := client.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (h *WebSocketHandler) removeClient(client *Client) {
	client.once.Do(func() {
		h.clients.Delete(client.id)
		close(client.send)
		logrus.WithField("client_id", client.id).Info("WebSocket 客户端已断开")
	})
}
