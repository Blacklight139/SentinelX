package middleware

import (
	"encoding/json"
	"net/http"
	"strings"
)

type AuthConfig struct {
	Tokens        []string
	ExcludedPaths []string
}

type AuthMiddleware struct {
	config   AuthConfig
	tokenSet map[string]bool
}

func NewAuthMiddleware(cfg AuthConfig) *AuthMiddleware {
	tokenSet := make(map[string]bool, len(cfg.Tokens))
	for _, token := range cfg.Tokens {
		tokenSet[token] = true
	}
	return &AuthMiddleware{
		config:   cfg,
		tokenSet: tokenSet,
	}
}

func (m *AuthMiddleware) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if m.isExcludedPath(r.URL.Path) {
			next.ServeHTTP(w, r)
			return
		}

		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			m.unauthorized(w)
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			m.unauthorized(w)
			return
		}

		token := parts[1]
		if !m.tokenSet[token] {
			m.unauthorized(w)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func (m *AuthMiddleware) isExcludedPath(path string) bool {
	for _, p := range m.config.ExcludedPaths {
		if p == path {
			return true
		}
	}
	return false
}

func (m *AuthMiddleware) unauthorized(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusUnauthorized)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"code":    401,
		"message": "Unauthorized",
	})
}
