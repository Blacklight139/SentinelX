package cache

import (
	"sync"
	"time"
)

type Cache[K comparable, V any] struct {
	mu       sync.RWMutex
	data     map[K]cacheEntry[V]
	capacity int
}

type cacheEntry[V any] struct {
	value     V
	expiresAt time.Time
}

func NewCache[K comparable, V any](capacity int) *Cache[K, V] {
	return &Cache[K, V]{
		data:     make(map[K]cacheEntry[V]),
		capacity: capacity,
	}
}

func (c *Cache[K, V]) Set(key K, value V, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.cleanup()

	if len(c.data) >= c.capacity {
		c.evict()
	}

	c.data[key] = cacheEntry[V]{
		value:     value,
		expiresAt: time.Now().Add(ttl),
	}
}

func (c *Cache[K, V]) Get(key K) (V, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	entry, ok := c.data[key]
	if !ok {
		var zero V
		return zero, false
	}

	if time.Now().After(entry.expiresAt) {
		var zero V
		return zero, false
	}

	return entry.value, true
}

func (c *Cache[K, V]) cleanup() {
	now := time.Now()
	for key, entry := range c.data {
		if now.After(entry.expiresAt) {
			delete(c.data, key)
		}
	}
}

func (c *Cache[K, V]) evict() {
	for key := range c.data {
		delete(c.data, key)
		break
	}
}
