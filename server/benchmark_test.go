// benchmark_test.go - Go 1.25 性能测试
package main

import (
    "crypto/rand"
    "crypto/rsa"
    "testing"
    "time"
)

func BenchmarkRSAEncryption(b *testing.B) {
    // 生成测试密钥
    privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
    if err != nil {
        b.Fatal(err)
    }
    
    testData := make([]byte, 256)
    rand.Read(testData)
    
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        es := &EncryptionSystem{
            commPublicKey: &privateKey.PublicKey,
        }
        _, err := es.EncryptWithKey(testData, es.commPublicKey)
        if err != nil {
            b.Fatal(err)
        }
    }
}

func BenchmarkSafeMap(b *testing.B) {
    m := NewSafeMap[string, int]()
    
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
    cache := NewCache[string, []byte](1000)
    
    testValue := make([]byte, 1024)
    rand.Read(testValue)
    
    b.Run("Set", func(b *testing.B) {
        for i := 0; i < b.N; i++ {
            cache.Set("test", testValue, time.Hour)
        }
    })
    
    b.Run("Get", func(b *testing.B) {
        cache.Set("test", testValue, time.Hour)
        b.ResetTimer()
        for i := 0; i < b.N; i++ {
            cache.Get("test")
        }
    })
}

func BenchmarkTrafficLogProcessing(b *testing.B) {
    storage := &LogStorage{}
    
    log := TrafficLog{
        Timestamp:        time.Now(),
        EventID:          "test-event",
        EventType:        "test",
        AttackDomain:     "test.com",
        TargetDomain:     "target.com",
        TrafficBytes:     1024,
        SourceIP:         "127.0.0.1",
        ManipulationType: "test",
        Severity:         "low",
    }
    
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        storage.StoreTrafficLog(log)
    }
}