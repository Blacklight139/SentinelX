package alert

import (
	"fmt"
	"regexp"
	"sync"
	"time"

	"github.com/sirupsen/logrus"

	"sentinelx-server/internal/models"
	"sentinelx-server/internal/storage"
	"sentinelx-server/internal/utils"
)

type AlertRule struct {
	ID          string
	Name        string
	Pattern     string
	Severity    string
	Description string
	Enabled     bool
	compiled    *regexp.Regexp
}

type AlertEvent struct {
	EventID      string
	RuleID       string
	RuleName     string
	Severity     string
	Timestamp    time.Time
	SourceIP     string
	TargetDomain string
	AttackDomain string
	Description  string
	Metadata     map[string]interface{}
}

type AlertEngine struct {
	rules       []*AlertRule
	mu          sync.RWMutex
	alertCount  map[string]int64
	logStorage  *storage.LogStorage
}

func NewAlertEngine(ls *storage.LogStorage) *AlertEngine {
	return &AlertEngine{
		rules:      make([]*AlertRule, 0),
		alertCount: make(map[string]int64),
		logStorage: ls,
	}
}

func (e *AlertEngine) AddRule(rule AlertRule) error {
	e.mu.Lock()
	defer e.mu.Unlock()

	compiled, err := regexp.Compile(rule.Pattern)
	if err != nil {
		return fmt.Errorf("编译正则表达式失败: %w", err)
	}

	rule.compiled = compiled

	for i, r := range e.rules {
		if r.ID == rule.ID {
			e.rules[i] = &rule
			logrus.WithFields(logrus.Fields{
				"rule_id": rule.ID,
				"name":    rule.Name,
			}).Info("已更新告警规则")
			return nil
		}
	}

	e.rules = append(e.rules, &rule)
	logrus.WithFields(logrus.Fields{
		"rule_id": rule.ID,
		"name":    rule.Name,
	}).Info("已添加告警规则")

	return nil
}

func (e *AlertEngine) RemoveRule(ruleID string) {
	e.mu.Lock()
	defer e.mu.Unlock()

	for i, r := range e.rules {
		if r.ID == ruleID {
			e.rules = append(e.rules[:i], e.rules[i+1:]...)
			logrus.WithFields(logrus.Fields{
				"rule_id": ruleID,
			}).Info("已删除告警规则")
			return
		}
	}
}

func (e *AlertEngine) GetRules() []AlertRule {
	e.mu.RLock()
	defer e.mu.RUnlock()

	rules := make([]AlertRule, len(e.rules))
	for i, r := range e.rules {
		rules[i] = *r
	}
	return rules
}

func (e *AlertEngine) CheckAndAlert(data []byte, sourceIP, targetDomain string) ([]AlertEvent, error) {
	e.mu.RLock()
	defer e.mu.RUnlock()

	var events []AlertEvent

	for _, rule := range e.rules {
		if !rule.Enabled || rule.compiled == nil {
			continue
		}

		if rule.compiled.Match(data) {
			event := e.createAlertEvent(rule, data, sourceIP, targetDomain)
			events = append(events, event)

			e.alertCount[rule.Severity]++

			if rule.Severity == "high" || rule.Severity == "critical" {
				trafficLog := models.TrafficLog{
					Timestamp:        event.Timestamp,
					EventID:          event.EventID,
					EventType:        "alert",
					AttackDomain:     event.AttackDomain,
					TargetDomain:     event.TargetDomain,
					TrafficBytes:     int64(len(data)),
					SourceIP:         event.SourceIP,
					Severity:         event.Severity,
					Confidence:       1.0,
					PacketSignature:  utils.GenerateUUID(),
					Metadata:         event.Metadata,
				}

				if err := e.logStorage.StoreTrafficLog(trafficLog); err != nil {
					logrus.WithError(err).WithField("event_id", event.EventID).Error("存储告警日志失败")
				}
			}

			logrus.WithFields(logrus.Fields{
				"event_id":   event.EventID,
				"rule_id":    rule.ID,
				"rule_name":  rule.Name,
				"severity":   rule.Severity,
				"source_ip":  sourceIP,
				"target_domain": targetDomain,
			}).Warn("检测到告警事件")
		}
	}

	return events, nil
}

func (e *AlertEngine) GetAlertStats() map[string]int64 {
	e.mu.RLock()
	defer e.mu.RUnlock()

	stats := make(map[string]int64)
	for k, v := range e.alertCount {
		stats[k] = v
	}
	return stats
}

func (e *AlertEngine) compileRules() {
	e.mu.Lock()
	defer e.mu.Unlock()

	for _, rule := range e.rules {
		if rule.Pattern != "" && rule.compiled == nil {
			compiled, err := regexp.Compile(rule.Pattern)
			if err != nil {
				logrus.WithError(err).WithField("rule_id", rule.ID).Error("编译正则表达式失败")
				continue
			}
			rule.compiled = compiled
		}
	}
}

func (e *AlertEngine) createAlertEvent(rule *AlertRule, data []byte, sourceIP, targetDomain string) AlertEvent {
	attackDomain := ""
	matches := rule.compiled.FindAllString(string(data), -1)
	if len(matches) > 0 {
		attackDomain = matches[0]
	}

	return AlertEvent{
		EventID:      utils.GenerateUUID(),
		RuleID:       rule.ID,
		RuleName:     rule.Name,
		Severity:     rule.Severity,
		Timestamp:    time.Now(),
		SourceIP:     sourceIP,
		TargetDomain: targetDomain,
		AttackDomain: attackDomain,
		Description:  rule.Description,
		Metadata: map[string]interface{}{
			"matched_count": len(matches),
			"data_length":   len(data),
		},
	}
}
