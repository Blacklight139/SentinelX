package main

import (
	"crypto/rand"
	"crypto/rsa"
	"testing"
	"time"

	"sentinelx-server/internal/cache"
	"sentinelx-server/internal/crypto"
	"sentinelx-server/internal/safemap"
)

func BenchmarkRSAEncryption(b *testing.B) {
	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		b.Fatal(err)
	}
	testData := make([]byte, 128)
	rand.Read(testData)

	es, _ := crypto.NewEncryptionSystem()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := es.EncryptWithKey(testData, &privateKey.PublicKey)
		if err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkSafeMap(b *testing.B) {
	m := safemap.NewSafeMap[string, int]()
	b.Run("Set", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			m.Set("key", i)
		}
	})
	b.Run("Get", func(b *testing.B) {
		m.Set("key", 100)
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			m.Get("key")
		}
	})
}

func BenchmarkCache(b *testing.B) {
	c := cache.NewCache[string, []byte](1000)
	testValue := make([]byte, 1024)
	rand.Read(testValue)

	b.Run("Set", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			c.Set("test", testValue, time.Hour)
		}
	})
	b.Run("Get", func(b *testing.B) {
		c.Set("test", testValue, time.Hour)
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			c.Get("test")
		}
	})
}
