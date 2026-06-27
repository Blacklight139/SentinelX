package crypto

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"os"
	"sync"
	"time"

	"github.com/sirupsen/logrus"

	"sentinelx-server/internal/cache"
)

type EncryptionSystem struct {
	commPrivateKey   *rsa.PrivateKey
	commPublicKey    *rsa.PublicKey
	accessPrivateKey *rsa.PrivateKey
	accessPublicKey  *rsa.PublicKey
	keyCache         *cache.Cache[string, []byte]
	keyVersion       string
	keyMutex         sync.RWMutex
}

func NewEncryptionSystem() (*EncryptionSystem, error) {
	es := &EncryptionSystem{
		keyCache:   cache.NewCache[string, []byte](100),
		keyVersion: fmt.Sprintf("v1_%d", time.Now().Unix()),
	}

	if err := es.loadOrGenerateKeys(); err != nil {
		return nil, fmt.Errorf("初始化加密系统失败: %w", err)
	}

	return es, nil
}

func (es *EncryptionSystem) loadOrGenerateKeys() error {
	if err := es.loadKeysFromFiles(); err != nil {
		logrus.Warnf("从文件加载密钥失败: %v，将生成新密钥", err)
		return es.generateKeys()
	}
	return nil
}

func (es *EncryptionSystem) loadKeysFromFiles() error {
	return nil
}

func (es *EncryptionSystem) generateKeys() error {
	logrus.Info("生成新的RSA密钥对...")

	commKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return fmt.Errorf("生成通信密钥失败: %w", err)
	}
	es.commPrivateKey = commKey
	es.commPublicKey = &commKey.PublicKey

	accessKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return fmt.Errorf("生成访问日志密钥失败: %w", err)
	}
	es.accessPrivateKey = accessKey
	es.accessPublicKey = &accessKey.PublicKey

	if err := es.saveKeysToFiles(); err != nil {
		logrus.Warnf("保存密钥到文件失败: %v", err)
	}

	return nil
}

func (es *EncryptionSystem) saveKeysToFiles() error {
	if err := os.MkdirAll("keys", 0700); err != nil {
		return err
	}

	commPrivatePEM := &pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: x509.MarshalPKCS1PrivateKey(es.commPrivateKey),
	}
	if err := os.WriteFile("keys/communication_private.pem",
		pem.EncodeToMemory(commPrivatePEM), 0600); err != nil {
		return err
	}

	commPublicPEM := &pem.Block{
		Type:  "RSA PUBLIC KEY",
		Bytes: x509.MarshalPKCS1PublicKey(es.commPublicKey),
	}
	if err := os.WriteFile("keys/communication_public.pem",
		pem.EncodeToMemory(commPublicPEM), 0644); err != nil {
		return err
	}

	accessPrivatePEM := &pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: x509.MarshalPKCS1PrivateKey(es.accessPrivateKey),
	}
	if err := os.WriteFile("keys/access_private.pem",
		pem.EncodeToMemory(accessPrivatePEM), 0600); err != nil {
		return err
	}

	accessPublicPEM := &pem.Block{
		Type:  "RSA PUBLIC KEY",
		Bytes: x509.MarshalPKCS1PublicKey(es.accessPublicKey),
	}
	if err := os.WriteFile("keys/access_public.pem",
		pem.EncodeToMemory(accessPublicPEM), 0644); err != nil {
		return err
	}

	logrus.Info("密钥已保存到 keys/ 目录")
	return nil
}

func (es *EncryptionSystem) EncryptWithKey(data []byte, publicKey *rsa.PublicKey) ([]byte, error) {
	hash := sha256.New()
	label := []byte(es.keyVersion)

	encrypted, err := rsa.EncryptOAEP(hash, rand.Reader, publicKey, data, label)
	if err != nil {
		return nil, fmt.Errorf("RSA加密失败: %w", err)
	}

	return encrypted, nil
}

func (es *EncryptionSystem) DecryptWithKey(encrypted []byte, privateKey *rsa.PrivateKey) ([]byte, error) {
	hash := sha256.New()
	label := []byte(es.keyVersion)

	decrypted, err := rsa.DecryptOAEP(hash, rand.Reader, privateKey, encrypted, label)
	if err != nil {
		return nil, fmt.Errorf("RSA解密失败: %w", err)
	}

	return decrypted, nil
}

func (es *EncryptionSystem) CommPublicKey() *rsa.PublicKey {
	es.keyMutex.RLock()
	defer es.keyMutex.RUnlock()
	return es.commPublicKey
}

func (es *EncryptionSystem) CommPrivateKey() *rsa.PrivateKey {
	es.keyMutex.RLock()
	defer es.keyMutex.RUnlock()
	return es.commPrivateKey
}

func (es *EncryptionSystem) AccessPublicKey() *rsa.PublicKey {
	es.keyMutex.RLock()
	defer es.keyMutex.RUnlock()
	return es.accessPublicKey
}

func (es *EncryptionSystem) AccessPrivateKey() *rsa.PrivateKey {
	es.keyMutex.RLock()
	defer es.keyMutex.RUnlock()
	return es.accessPrivateKey
}
