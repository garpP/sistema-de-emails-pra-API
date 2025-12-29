# Sistema de E-mails - Implementação Ruby

## 📦 Dependências

```ruby
# Gemfile
source 'https://rubygems.org'

gem 'sinatra'
gem 'mail'
gem 'dotenv'
gem 'json'
```

```bash
bundle install
```

## 📁 Estrutura de Arquivos

```
api/
├── .env
├── Gemfile
├── app.rb
├── config/
│   └── environment.rb
├── services/
│   └── email_service.rb
└── routes/
    └── auth.rb
```

## 🔧 Arquivo: `config/environment.rb`

```ruby
require 'dotenv/load'

module Config
  SMTP_HOST = ENV['SMTP_HOST'] || '127.0.0.1'
  SMTP_PORT = (ENV['SMTP_PORT'] || '25').to_i
  SMTP_FROM = ENV['SMTP_FROM'] || 'no-reply@seusite.com'
  EMAIL_LOG_ONLY = ENV['EMAIL_LOG_ONLY'] == '1'
  
  JWT_SECRET = ENV['JWT_SECRET'] || 'seu-secret'
  DATABASE_URL = ENV['DATABASE_URL'] || 'sqlite://app.db'
end
```

## 📧 Arquivo: `services/email_service.rb`

```ruby
require 'mail'
require 'logger'
require_relative '../config/environment'

class EmailService
  def initialize
    @logger = Logger.new(STDOUT)
    @smtp_host = Config::SMTP_HOST
    @smtp_port = Config::SMTP_PORT
    @smtp_from = Config::SMTP_FROM
    @log_only = Config::EMAIL_LOG_ONLY
    
    configure_mail unless @log_only
  end
  
  def configure_mail
    Mail.defaults do
      delivery_method :smtp, {
        address: @smtp_host,
        port: @smtp_port,
        enable_starttls_auto: false,
        openssl_verify_mode: 'none'
      }
    end
  end
  
  def send_email(to:, subject:, text:, html: nil)
    if @log_only
      @logger.warn("[email][LOG_ONLY] to=#{to} subject=#{subject}")
      return true
    end
    
    begin
      mail = Mail.new do
        from     @smtp_from
        to       to
        subject  subject
        
        text_part do
          body text
        end
        
        if html
          html_part do
            content_type 'text/html; charset=UTF-8'
            body html
          end
        end
      end
      
      mail.deliver!
      @logger.info("[email] Enviado para: #{to}")
      true
    rescue => e
      @logger.error("[email] Erro ao enviar: #{e.message}")
      raise e
    end
  end
  
  def send_verification_email(to, code)
    subject = 'Seu código de verificação'
    
    text = <<~TEXT
      Olá!
      
      Seu código de verificação é: #{code}
      
      Este código expira em 15 minutos.
      
      Se não foi você, ignore este e-mail.
    TEXT
    
    html = <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
          <meta charset="utf-8">
      </head>
      <body style="font-family: Arial, sans-serif; padding: 20px; background: #f5f5f5;">
          <div style="max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px;">
              <h2 style="color: #333; margin-top: 0;">Verificação de Conta</h2>
              <p style="color: #666; font-size: 16px;">Seu código de verificação é:</p>
              <div style="background: #f8f9fa; padding: 20px; text-align: center; border-radius: 8px; margin: 20px 0;">
                  <h1 style="color: #e50914; font-size: 36px; margin: 0; letter-spacing: 4px;">#{code}</h1>
              </div>
              <p style="color: #999; font-size: 14px;">Este código expira em 15 minutos.</p>
              <p style="color: #ccc; font-size: 12px;">Se não foi você, ignore este e-mail.</p>
          </div>
      </body>
      </html>
    HTML
    
    send_email(to: to, subject: subject, text: text, html: html)
  end
  
  def send_password_reset_email(to, code)
    subject = 'Recuperação de Senha'
    
    text = <<~TEXT
      Olá!
      
      Você solicitou a recuperação de senha da sua conta.
      
      Seu código de recuperação é: #{code}
      
      Este código expira em 15 minutos.
      
      Se você não solicitou, ignore este e-mail.
    TEXT
    
    html = <<~HTML
      <!DOCTYPE html>
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
                  <h1 style="color: #e50914; font-size: 36px; margin: 0; letter-spacing: 4px;">#{code}</h1>
              </div>
              <p style="color: #999; font-size: 14px;">Este código expira em 15 minutos.</p>
              <p style="color: #ccc; font-size: 12px;">Se não foi você, ignore este e-mail.</p>
          </div>
      </body>
      </html>
    HTML
    
    send_email(to: to, subject: subject, text: text, html: html)
  end
  
  def verify_connection
    if @log_only
      @logger.info("[email] Modo LOG_ONLY ativo")
      return true
    end
    
    begin
      smtp = Net::SMTP.new(@smtp_host, @smtp_port)
      smtp.start do
        @logger.info("[email] Conectado ao SMTP #{@smtp_host}:#{@smtp_port}")
      end
      true
    rescue => e
      @logger.error("[email] Falha na conexão: #{e.message}")
      false
    end
  end
end
```

## 🔐 Arquivo: `routes/auth.rb`

```ruby
require 'sinatra/base'
require 'json'
require_relative '../services/email_service'

class AuthRoutes < Sinatra::Base
  # Armazenamento temporário (use Redis em produção)
  @@verification_codes = {}
  @@reset_codes = {}
  
  def initialize
    super
    @email_service = EmailService.new
  end
  
  def generate_code
    rand(100000..999999).to_s
  end
  
  # POST /api/auth/register
  post '/api/auth/register' do
    content_type :json
    
    begin
      data = JSON.parse(request.body.read)
      email = data['email']
      
      halt 400, { error: 'Email é obrigatório' }.to_json unless email
      
      # Gerar código
      code = generate_code
      
      # Salvar com expiração
      @@verification_codes[email] = {
        code: code,
        expires_at: Time.now + 900  # 15 minutos
      }
      
      # Enviar e-mail
      @email_service.send_verification_email(email, code)
      
      {
        success: true,
        message: 'Código enviado para seu e-mail'
      }.to_json
      
    rescue => e
      halt 500, { error: "Erro ao enviar e-mail: #{e.message}" }.to_json
    end
  end
  
  # POST /api/auth/verify-code
  post '/api/auth/verify-code' do
    content_type :json
    
    data = JSON.parse(request.body.read)
    email = data['email']
    code = data['code']
    
    halt 400, { error: 'Email e código são obrigatórios' }.to_json unless email && code
    
    # Verificar se existe
    stored = @@verification_codes[email]
    halt 400, { error: 'Código inválido ou expirado' }.to_json unless stored
    
    # Verificar expiração
    if Time.now > stored[:expires_at]
      @@verification_codes.delete(email)
      halt 400, { error: 'Código expirado' }.to_json
    end
    
    # Verificar código
    if stored[:code] != code
      halt 400, { error: 'Código incorreto' }.to_json
    end
    
    # Remover código usado
    @@verification_codes.delete(email)
    
    {
      success: true,
      message: 'Código verificado com sucesso'
    }.to_json
  end
  
  # POST /api/auth/forgot-password
  post '/api/auth/forgot-password' do
    content_type :json
    
    begin
      data = JSON.parse(request.body.read)
      email = data['email']
      
      halt 400, { error: 'Email é obrigatório' }.to_json unless email
      
      # Gerar código
      code = generate_code
      
      # Salvar
      @@reset_codes[email] = {
        code: code,
        expires_at: Time.now + 900
      }
      
      # Enviar e-mail
      @email_service.send_password_reset_email(email, code)
      
      {
        success: true,
        message: 'Código de recuperação enviado'
      }.to_json
      
    rescue => e
      halt 500, { error: "Erro ao enviar e-mail: #{e.message}" }.to_json
    end
  end
  
  # POST /api/auth/reset-password
  post '/api/auth/reset-password' do
    content_type :json
    
    data = JSON.parse(request.body.read)
    email = data['email']
    code = data['code']
    new_password = data['new_password']
    
    unless email && code && new_password
      halt 400, { error: 'Todos os campos são obrigatórios' }.to_json
    end
    
    # Verificar código
    stored = @@reset_codes[email]
    halt 400, { error: 'Código inválido ou expirado' }.to_json unless stored
    
    if Time.now > stored[:expires_at]
      @@reset_codes.delete(email)
      halt 400, { error: 'Código expirado' }.to_json
    end
    
    if stored[:code] != code
      halt 400, { error: 'Código incorreto' }.to_json
    end
    
    # Remover código
    @@reset_codes.delete(email)
    
    # Aqui você atualizaria a senha no banco
    # User.update_password(email, new_password)
    
    {
      success: true,
      message: 'Senha atualizada com sucesso'
    }.to_json
  end
end
```

## 🚀 Arquivo: `app.rb`

```ruby
require 'sinatra'
require_relative 'config/environment'
require_relative 'routes/auth'
require_relative 'services/email_service'

class App < Sinatra::Base
  use AuthRoutes
  
  # Health check
  get '/health' do
    content_type :json
    email_service = EmailService.new
    
    {
      status: 'ok',
      email_smtp: email_service.verify_connection
    }.to_json
  end
  
  # Inicialização
  configure do
    set :server, 'puma'
    set :bind, '0.0.0.0'
    set :port, 4567
    
    # Verificar SMTP
    email_service = EmailService.new
    if email_service.verify_connection
      puts "✅ SMTP conectado"
    else
      puts "⚠️  SMTP não conectado (verifique Postfix)"
    end
  end
end

# Rodar servidor
App.run! if __FILE__ == $0
```

## 📄 Arquivo: `.env`

```env
# E-mail Configuration
EMAIL_LOG_ONLY=0
SMTP_HOST=127.0.0.1
SMTP_PORT=25
SMTP_FROM="SeuApp <no-reply@seusite.com>"

# App Configuration
JWT_SECRET=seu_secret_aqui
DATABASE_URL=postgresql://user:pass@localhost/dbname
```

## ▶️ Como Executar

### 1. Instalar dependências:
```bash
bundle install
```

### 2. Configurar .env:
```bash
cp .env.example .env
# Editar .env
```

### 3. Rodar servidor:
```bash
ruby app.rb
# ou
bundle exec ruby app.rb
```

### 4. Testar endpoints:

```bash
# Registrar
curl -X POST http://localhost:4567/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "usuario@email.com"}'

# Verificar código
curl -X POST http://localhost:4567/api/auth/verify-code \
  -H "Content-Type: application/json" \
  -d '{"email": "usuario@email.com", "code": "123456"}'

# Recuperar senha
curl -X POST http://localhost:4567/api/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{"email": "usuario@email.com"}'

# Resetar senha
curl -X POST http://localhost:4567/api/auth/reset-password \
  -H "Content-Type: application/json" \
  -d '{"email":"usuario@email.com","code":"123456","new_password":"nova123"}'
```

## 📦 Implementação com Rails

```ruby
# app/services/email_service.rb
class EmailService
  def self.send_verification_email(email, code)
    UserMailer.verification_email(email, code).deliver_now
  end
  
  def self.send_password_reset_email(email, code)
    UserMailer.password_reset_email(email, code).deliver_now
  end
end

# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  default from: 'no-reply@seusite.com'
  
  def verification_email(email, code)
    @code = code
    mail(to: email, subject: 'Seu código de verificação')
  end
  
  def password_reset_email(email, code)
    @code = code
    mail(to: email, subject: 'Recuperação de Senha')
  end
end

# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: '127.0.0.1',
  port: 25,
  enable_starttls_auto: false
}
```

## 🔧 Melhorias Recomendadas

### 1. Usar Redis:
```ruby
# Gemfile
gem 'redis'

# services/code_storage.rb
require 'redis'

class CodeStorage
  def initialize
    @redis = Redis.new(host: 'localhost', port: 6379)
  end
  
  def save_code(email, code, ttl = 900)
    @redis.setex("verification:#{email}", ttl, code)
  end
  
  def get_code(email)
    @redis.get("verification:#{email}")
  end
  
  def delete_code(email)
    @redis.del("verification:#{email}")
  end
end
```

### 2. Rate Limiting:
```ruby
# Gemfile
gem 'rack-attack'

# config.ru
use Rack::Attack

Rack::Attack.throttle('auth/register', limit: 3, period: 60) do |req|
  req.ip if req.path == '/api/auth/register' && req.post?
end
```

### 3. Background Jobs:
```ruby
# Gemfile
gem 'sidekiq'

# workers/email_worker.rb
class EmailWorker
  include Sidekiq::Worker
  
  def perform(email, code, type)
    service = EmailService.new
    case type
    when 'verification'
      service.send_verification_email(email, code)
    when 'reset'
      service.send_password_reset_email(email, code)
    end
  end
end

# Usar
EmailWorker.perform_async(email, code, 'verification')
```

## ✅ Checklist

- [ ] Instalar gems (bundle install)
- [ ] Configurar .env
- [ ] Implementar EmailService
- [ ] Criar rotas de autenticação
- [ ] Testar envio de e-mails
- [ ] Adicionar validações
- [ ] Implementar Redis
- [ ] Adicionar rate limiting
- [ ] Configurar background jobs
- [ ] Documentar API

---

**Status:** ✅ Implementação funcional
**Ruby:** 2.7+
**Framework:** Sinatra
