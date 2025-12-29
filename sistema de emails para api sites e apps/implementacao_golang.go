# Sistema de E-mails - Implementação Go (Golang)

## 📦 Dependências

```bash
go mod init email-api
go get github.com/gin-gonic/gin
go get github.com/joho/godotenv
go get gopkg.in/gomail.v2
go get github.com/go-redis/redis/v8
```

Ou `go.mod`:
```go
module email-api

go 1.21

require (
	github.com/gin-gonic/gin v1.9.1
	github.com/go-redis/redis/v8 v8.11.5
	github.com/joho/godotenv v1.5.1
	gopkg.in/gomail.v2 v2.0.0-20160411212932-81ebce5c23df
)
```

## 📁 Estrutura de Arquivos

```
.
├── main.go
├── .env
├── config/
│   └── env.go
├── services/
│   ├── email.go
│   └── storage.go
└── handlers/
    └── auth.go
```

## 🌍 Arquivo: `.env`

```env
# Server
PORT=8080

# E-mail Configuration
EMAIL_LOG_ONLY=0
SMTP_HOST=127.0.0.1
SMTP_PORT=25
SMTP_USER=
SMTP_PASS=
SMTP_FROM="Seu Site <no-reply@seusite.com>"

# Redis (opcional)
REDIS_HOST=localhost
REDIS_PORT=6379

# Security
CODE_EXPIRATION_MINUTES=15
```

## 🔧 Arquivo: `config/env.go`

```go
package config

import (
	"log"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	Port                   string
	EmailLogOnly           bool
	SMTPHost               string
	SMTPPort               int
	SMTPUser               string
	SMTPPass               string
	SMTPFrom               string
	RedisHost              string
	RedisPort              string
	CodeExpirationMinutes  int
}

var AppConfig *Config

func LoadConfig() {
	err := godotenv.Load()
	if err != nil {
		log.Println("Aviso: .env não encontrado, usando valores padrão")
	}

	smtpPort, _ := strconv.Atoi(getEnv("SMTP_PORT", "25"))
	codeExp, _ := strconv.Atoi(getEnv("CODE_EXPIRATION_MINUTES", "15"))

	AppConfig = &Config{
		Port:                  getEnv("PORT", "8080"),
		EmailLogOnly:          getEnv("EMAIL_LOG_ONLY", "0") == "1",
		SMTPHost:              getEnv("SMTP_HOST", "127.0.0.1"),
		SMTPPort:              smtpPort,
		SMTPUser:              getEnv("SMTP_USER", ""),
		SMTPPass:              getEnv("SMTP_PASS", ""),
		SMTPFrom:              getEnv("SMTP_FROM", "no-reply@seusite.com"),
		RedisHost:             getEnv("REDIS_HOST", "localhost"),
		RedisPort:             getEnv("REDIS_PORT", "6379"),
		CodeExpirationMinutes: codeExp,
	}
}

func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}
```

## 📧 Arquivo: `services/email.go`

```go
package services

import (
	"email-api/config"
	"fmt"
	"log"

	"gopkg.in/gomail.v2"
)

type EmailService struct {
	dialer *gomail.Dialer
}

func NewEmailService() *EmailService {
	cfg := config.AppConfig

	dialer := gomail.NewDialer(
		cfg.SMTPHost,
		cfg.SMTPPort,
		cfg.SMTPUser,
		cfg.SMTPPass,
	)

	// Desabilitar TLS se porta 25
	if cfg.SMTPPort == 25 {
		dialer.SSL = false
	}

	return &EmailService{
		dialer: dialer,
	}
}

func (s *EmailService) VerifyConnection() bool {
	cfg := config.AppConfig

	if cfg.EmailLogOnly {
		log.Println("[email] Modo LOG_ONLY ativo")
		return true
	}

	conn, err := s.dialer.Dial()
	if err != nil {
		log.Printf("[email] ❌ Erro na conexão: %v\n", err)
		return false
	}
	defer conn.Close()

	log.Println("[email] ✅ SMTP conectado")
	return true
}

func (s *EmailService) sendEmail(to, subject, text, html string) error {
	cfg := config.AppConfig

	if cfg.EmailLogOnly {
		log.Printf("[email][LOG_ONLY] to=%s subject=\"%s\"\n", to, subject)
		return nil
	}

	m := gomail.NewMessage()
	m.SetHeader("From", cfg.SMTPFrom)
	m.SetHeader("To", to)
	m.SetHeader("Subject", subject)
	m.SetBody("text/plain", text)
	m.AddAlternative("text/html", html)

	if err := s.dialer.DialAndSend(m); err != nil {
		log.Printf("[email] ❌ Erro ao enviar: %v\n", err)
		return err
	}

	log.Printf("[email] ✅ Enviado para: %s\n", to)
	return nil
}

func (s *EmailService) SendVerificationEmail(to, code string) error {
	cfg := config.AppConfig
	subject := "Seu código de verificação"

	text := fmt.Sprintf(`Olá!

Seu código de verificação é: %s

Este código expira em %d minutos.

Se não foi você, ignore este e-mail.`, code, cfg.CodeExpirationMinutes)

	html := fmt.Sprintf(`<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
</head>
<body style="font-family: Arial, sans-serif; padding: 20px; background: #f5f5f5;">
  <div style="max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px;">
    <h2 style="color: #333; margin-top: 0;">Verificação de Conta</h2>
    <p style="color: #666; font-size: 16px;">Seu código de verificação é:</p>
    <div style="background: #f8f9fa; padding: 20px; text-align: center; border-radius: 8px; margin: 20px 0;">
      <h1 style="color: #e50914; font-size: 36px; margin: 0; letter-spacing: 4px;">%s</h1>
    </div>
    <p style="color: #999; font-size: 14px;">Este código expira em %d minutos.</p>
    <p style="color: #ccc; font-size: 12px;">Se não foi você, ignore este e-mail.</p>
  </div>
</body>
</html>`, code, cfg.CodeExpirationMinutes)

	return s.sendEmail(to, subject, text, html)
}

func (s *EmailService) SendPasswordResetEmail(to, code string) error {
	cfg := config.AppConfig
	subject := "Recuperação de Senha"

	text := fmt.Sprintf(`Olá!

Você solicitou a recuperação de senha da sua conta.

Seu código de recuperação é: %s

Este código expira em %d minutos.

Se você não solicitou, ignore este e-mail.`, code, cfg.CodeExpirationMinutes)

	html := fmt.Sprintf(`<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
</head>
<body style="font-family: Arial, sans-serif; padding: 20px; background: #f5f5f5;">
  <div style="max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px;">
    <h2 style="color: #333; margin-top: 0;">Recuperação de Senha</h2>
    <p style="color: #666; font-size: 16px;">Você solicitou a recuperação de senha.</p>
    <p style="color: #666;">Seu código de recuperação é:</p>
    <div style="background: #f8f9fa; padding: 20px; text-align: center; border-radius: 8px; margin: 20px 0;">
      <h1 style="color: #e50914; font-size: 36px; margin: 0; letter-spacing: 4px;">%s</h1>
    </div>
    <p style="color: #999; font-size: 14px;">Este código expira em %d minutos.</p>
    <p style="color: #ccc; font-size: 12px;">Se não foi você, ignore este e-mail.</p>
  </div>
</body>
</html>`, code, cfg.CodeExpirationMinutes)

	return s.sendEmail(to, subject, text, html)
}
```

## 💾 Arquivo: `services/storage.go`

```go
package services

import (
	"email-api/config"
	"math/rand"
	"sync"
	"time"
)

type CodeData struct {
	Code      string
	ExpiresAt time.Time
}

type CodeStorage struct {
	verificationCodes map[string]CodeData
	resetCodes        map[string]CodeData
	mu                sync.RWMutex
}

var storage *CodeStorage

func NewCodeStorage() *CodeStorage {
	if storage == nil {
		storage = &CodeStorage{
			verificationCodes: make(map[string]CodeData),
			resetCodes:        make(map[string]CodeData),
		}

		// Limpar códigos expirados a cada 1 minuto
		go storage.cleanExpiredCodes()
	}
	return storage
}

func (s *CodeStorage) GenerateCode() string {
	rand.Seed(time.Now().UnixNano())
	code := rand.Intn(900000) + 100000
	return fmt.Sprintf("%06d", code)
}

func (s *CodeStorage) SaveVerificationCode(email, code string) {
	cfg := config.AppConfig
	expiresAt := time.Now().Add(time.Duration(cfg.CodeExpirationMinutes) * time.Minute)

	s.mu.Lock()
	defer s.mu.Unlock()
	s.verificationCodes[email] = CodeData{
		Code:      code,
		ExpiresAt: expiresAt,
	}
}

func (s *CodeStorage) GetVerificationCode(email string) *CodeData {
	s.mu.RLock()
	defer s.mu.RUnlock()

	data, exists := s.verificationCodes[email]
	if !exists {
		return nil
	}

	if time.Now().After(data.ExpiresAt) {
		return nil
	}

	return &data
}

func (s *CodeStorage) DeleteVerificationCode(email string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.verificationCodes, email)
}

func (s *CodeStorage) SaveResetCode(email, code string) {
	cfg := config.AppConfig
	expiresAt := time.Now().Add(time.Duration(cfg.CodeExpirationMinutes) * time.Minute)

	s.mu.Lock()
	defer s.mu.Unlock()
	s.resetCodes[email] = CodeData{
		Code:      code,
		ExpiresAt: expiresAt,
	}
}

func (s *CodeStorage) GetResetCode(email string) *CodeData {
	s.mu.RLock()
	defer s.mu.RUnlock()

	data, exists := s.resetCodes[email]
	if !exists {
		return nil
	}

	if time.Now().After(data.ExpiresAt) {
		return nil
	}

	return &data
}

func (s *CodeStorage) DeleteResetCode(email string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.resetCodes, email)
}

func (s *CodeStorage) cleanExpiredCodes() {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		now := time.Now()

		s.mu.Lock()

		// Limpar verification codes
		for email, data := range s.verificationCodes {
			if now.After(data.ExpiresAt) {
				delete(s.verificationCodes, email)
			}
		}

		// Limpar reset codes
		for email, data := range s.resetCodes {
			if now.After(data.ExpiresAt) {
				delete(s.resetCodes, email)
			}
		}

		s.mu.Unlock()
	}
}
```

## 🛣️ Arquivo: `handlers/auth.go`

```go
package handlers

import (
	"email-api/services"
	"net/http"

	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	emailService *services.EmailService
	storage      *services.CodeStorage
}

func NewAuthHandler() *AuthHandler {
	return &AuthHandler{
		emailService: services.NewEmailService(),
		storage:      services.NewCodeStorage(),
	}
}

type RegisterRequest struct {
	Email string `json:"email" binding:"required,email"`
}

type VerifyCodeRequest struct {
	Email string `json:"email" binding:"required,email"`
	Code  string `json:"code" binding:"required"`
}

type ResetPasswordRequest struct {
	Email       string `json:"email" binding:"required,email"`
	Code        string `json:"code" binding:"required"`
	NewPassword string `json:"newPassword" binding:"required,min=6"`
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req RegisterRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Email é obrigatório"})
		return
	}

	// Gerar código
	code := h.storage.GenerateCode()
	h.storage.SaveVerificationCode(req.Email, code)

	// Enviar e-mail
	if err := h.emailService.SendVerificationEmail(req.Email, code); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Erro ao enviar e-mail",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Código enviado para seu e-mail",
	})
}

func (h *AuthHandler) VerifyCode(c *gin.Context) {
	var req VerifyCodeRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Email e código são obrigatórios"})
		return
	}

	// Buscar código
	stored := h.storage.GetVerificationCode(req.Email)

	if stored == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Código inválido ou expirado"})
		return
	}

	// Verificar código
	if stored.Code != req.Code {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Código incorreto"})
		return
	}

	// Remover código usado
	h.storage.DeleteVerificationCode(req.Email)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Código verificado com sucesso",
	})
}

func (h *AuthHandler) ForgotPassword(c *gin.Context) {
	var req RegisterRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Email é obrigatório"})
		return
	}

	// Gerar código
	code := h.storage.GenerateCode()
	h.storage.SaveResetCode(req.Email, code)

	// Enviar e-mail
	if err := h.emailService.SendPasswordResetEmail(req.Email, code); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Erro ao enviar e-mail",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Código de recuperação enviado",
	})
}

func (h *AuthHandler) ResetPassword(c *gin.Context) {
	var req ResetPasswordRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Todos os campos são obrigatórios"})
		return
	}

	// Buscar código
	stored := h.storage.GetResetCode(req.Email)

	if stored == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Código inválido ou expirado"})
		return
	}

	// Verificar código
	if stored.Code != req.Code {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Código incorreto"})
		return
	}

	// Remover código
	h.storage.DeleteResetCode(req.Email)

	// Aqui você atualizaria a senha no banco
	// userService.UpdatePassword(req.Email, req.NewPassword)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Senha atualizada com sucesso",
	})
}

func (h *AuthHandler) Health(c *gin.Context) {
	smtpConnected := h.emailService.VerifyConnection()

	c.JSON(http.StatusOK, gin.H{
		"status": "ok",
		"smtp":   smtpConnected,
	})
}
```

## 🚀 Arquivo: `main.go`

```go
package main

import (
	"email-api/config"
	"email-api/handlers"
	"log"

	"github.com/gin-gonic/gin"
)

func main() {
	// Carregar configurações
	config.LoadConfig()
	cfg := config.AppConfig

	// Configurar Gin
	router := gin.Default()

	// CORS
	router.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// Handlers
	authHandler := handlers.NewAuthHandler()

	// Rotas
	api := router.Group("/api/auth")
	{
		api.POST("/register", authHandler.Register)
		api.POST("/verify-code", authHandler.VerifyCode)
		api.POST("/forgot-password", authHandler.ForgotPassword)
		api.POST("/reset-password", authHandler.ResetPassword)
		api.GET("/health", authHandler.Health)
	}

	router.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":  "ok",
			"message": "Email API Go",
			"version": "1.0.0",
		})
	})

	// Iniciar servidor
	log.Printf("🚀 Servidor iniciando na porta %s\n", cfg.Port)
	log.Printf("📧 SMTP: %s:%d\n", cfg.SMTPHost, cfg.SMTPPort)

	if err := router.Run(":" + cfg.Port); err != nil {
		log.Fatalf("❌ Erro ao iniciar servidor: %v\n", err)
	}
}
```

## ▶️ Como Executar

### 1. Instalar dependências:
```bash
go mod download
```

### 2. Configurar `.env`

### 3. Rodar:
```bash
go run main.go

# Ou compilar:
go build -o email-api
./email-api
```

### 4. Testar:

```bash
# Registrar
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "usuario@email.com"}'

# Verificar código
curl -X POST http://localhost:8080/api/auth/verify-code \
  -H "Content-Type: application/json" \
  -d '{"email": "usuario@email.com", "code": "123456"}'

# Recuperar senha
curl -X POST http://localhost:8080/api/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{"email": "usuario@email.com"}'

# Resetar senha
curl -X POST http://localhost:8080/api/auth/reset-password \
  -H "Content-Type: application/json" \
  -d '{"email":"usuario@email.com","code":"123456","newPassword":"nova123"}'

# Health check
curl http://localhost:8080/api/auth/health
```

## 🔧 Com Redis (Recomendado)

```go
// services/redis_storage.go
package services

import (
	"context"
	"email-api/config"
	"fmt"
	"time"

	"github.com/go-redis/redis/v8"
)

type RedisStorage struct {
	client *redis.Client
}

func NewRedisStorage() *RedisStorage {
	cfg := config.AppConfig

	client := redis.NewClient(&redis.Options{
		Addr: fmt.Sprintf("%s:%s", cfg.RedisHost, cfg.RedisPort),
	})

	return &RedisStorage{client: client}
}

func (r *RedisStorage) SaveCode(codeType, email, code string) error {
	ctx := context.Background()
	key := fmt.Sprintf("%s:%s", codeType, email)
	expiration := time.Duration(config.AppConfig.CodeExpirationMinutes) * time.Minute

	return r.client.Set(ctx, key, code, expiration).Err()
}

func (r *RedisStorage) GetCode(codeType, email string) (string, error) {
	ctx := context.Background()
	key := fmt.Sprintf("%s:%s", codeType, email)

	return r.client.Get(ctx, key).Result()
}

func (r *RedisStorage) DeleteCode(codeType, email string) error {
	ctx := context.Background()
	key := fmt.Sprintf("%s:%s", codeType, email)

	return r.client.Del(ctx, key).Err()
}
```

## ✅ Checklist

- [ ] Configurar go.mod
- [ ] Criar .env
- [ ] Implementar EmailService
- [ ] Criar handlers
- [ ] Testar endpoints
- [ ] Adicionar validações (binding)
- [ ] Implementar Redis
- [ ] Adicionar rate limiting
- [ ] Configurar Gin middleware
- [ ] Documentar API

---

**Status:** ✅ Implementação funcional
**Go:** 1.21+
**Framework:** Gin
