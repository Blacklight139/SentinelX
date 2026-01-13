package main

import (
    "fmt"
    "runtime/debug"
    "sync/atomic"
    "time"
)

// Go 1.25 新特性演示

// 1. 改进的泛型函数
func GenericFilter[T any](slice []T, predicate func(T) bool) []T {
    result := make([]T, 0, len(slice))
    for _, v := range slice {
        if predicate(v) {
            result = append(result, v)
        }
    }
    return result
}

// 2. 使用泛型的缓存实现
type GenericCache[K comparable, V any] struct {
    store map[K]V
}

func NewGenericCache[K comparable, V any]() *GenericCache[K, V] {
    return &GenericCache[K, V]{
        store: make(map[K]V),
    }
}

// 3. 使用 atomic.Pointer 改进并发安全
type SafeCounter struct {
    value atomic.Int64
}

func (c *SafeCounter) Increment() int64 {
    return c.value.Add(1)
}

func (c *SafeCounter) Value() int64 {
    return c.value.Load()
}

// 4. 使用 time/tzdata 包处理时区
func LoadTimezone(name string) (*time.Location, error) {
    return time.LoadLocation(name)
}

// 5. 使用 debug/buildinfo 获取构建信息
func PrintBuildInfo() {
    if info, ok := debug.ReadBuildInfo(); ok {
        fmt.Printf("Go Version: %s\n", info.GoVersion)
        fmt.Printf("Main Module: %s\n", info.Main.Path)
        for _, dep := range info.Deps {
            fmt.Printf("  Dependency: %s %s\n", dep.Path, dep.Version)
        }
    }
}

// 6. 使用 slices 包（Go 1.25 内置）
func ProcessSlice[T comparable](slice []T) []T {
    // 去重
    seen := make(map[T]bool)
    result := make([]T, 0, len(slice))
    
    for _, item := range slice {
        if !seen[item] {
            seen[item] = true
            result = append(result, item)
        }
    }
    return result
}

// 7. 改进的错误处理模式
type OperationResult[T any] struct {
    Value T
    Error error
}

func SafeOperation[T any](op func() (T, error)) OperationResult[T] {
    value, err := op()
    return OperationResult[T]{
        Value: value,
        Error: err,
    }
}

// 演示函数
func DemoGo125Features() {
    fmt.Println("=== Go 1.25 新特性演示 ===")
    
    // 1. 泛型过滤
    numbers := []int{1, 2, 3, 4, 5, 6}
    evenNumbers := GenericFilter(numbers, func(n int) bool {
        return n%2 == 0
    })
    fmt.Printf("偶数: %v\n", evenNumbers)
    
    // 2. 泛型缓存
    cache := NewGenericCache[string, int]()
    cache.store["key1"] = 100
    fmt.Printf("缓存值: %v\n", cache.store["key1"])
    
    // 3. atomic 改进
    counter := &SafeCounter{}
    counter.Increment()
    fmt.Printf("计数器: %d\n", counter.Value())
    
    // 4. 构建信息
    PrintBuildInfo()
    
    // 5. 时区处理
    if loc, err := LoadTimezone("Asia/Shanghai"); err == nil {
        fmt.Printf("当前时间: %v\n", time.Now().In(loc).Format(time.RFC3339))
    }
    
    fmt.Println("=== 演示结束 ===")
}