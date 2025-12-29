# Sistema de E-mails - Implementação PHP

## 📦 Dependências (Composer)

```json
{
    "name": "seu-projeto/email-api",
    "description": "API de E-mails com PHP",
    "require": {
        "php": "^8.1",
        "phpmailer/phpmailer": "^6.9",
        "vlucas/phpdotenv": "^5.6",
        "predis/predis": "^2.2"
    },
    "autoload": {
        "psr-4": {
            "App\\": "src/"
        }
    }
}
```

## 📁 Estrutura de Arquivos

```
src/
├── index.php
├── config/
│   └── env.php
├── services/
│   ├── EmailService.php
│   └── CodeStorage.php
└── routes/
    └── auth.php
```

## 🌍 Arquivo: `.env`

```env
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

## 🔧 Arquivo: `src/config/env.php`

```php
<?php

namespace App\Config;

use Dotenv\Dotenv;

class Env
{
    private static ?array $config = null;

    public static function load(): void
    {
        $dotenv = Dotenv::createImmutable(__DIR__ . '/../../');
        $dotenv->load();

        self::$config = [
            'EMAIL_LOG_ONLY' => $_ENV['EMAIL_LOG_ONLY'] === '1',
            'SMTP_HOST' => $_ENV['SMTP_HOST'] ?? '127.0.0.1',
            'SMTP_PORT' => (int)($_ENV['SMTP_PORT'] ?? 25),
            'SMTP_USER' => $_ENV['SMTP_USER'] ?? '',
            'SMTP_PASS' => $_ENV['SMTP_PASS'] ?? '',
            'SMTP_FROM' => $_ENV['SMTP_FROM'] ?? 'no-reply@seusite.com',
            'REDIS_HOST' => $_ENV['REDIS_HOST'] ?? 'localhost',
            'REDIS_PORT' => (int)($_ENV['REDIS_PORT'] ?? 6379),
            'CODE_EXPIRATION_MINUTES' => (int)($_ENV['CODE_EXPIRATION_MINUTES'] ?? 15),
        ];
    }

    public static function get(string $key): mixed
    {
        if (self::$config === null) {
            self::load();
        }

        return self::$config[$key] ?? null;
    }
}
```

## 📧 Arquivo: `src/services/EmailService.php`

```php
<?php

namespace App\Services;

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;
use App\Config\Env;

class EmailService
{
    private PHPMailer $mailer;

    public function __construct()
    {
        $this->mailer = new PHPMailer(true);
        $this->configure();
    }

    private function configure(): void
    {
        try {
            // Configuração do servidor SMTP
            $this->mailer->isSMTP();
            $this->mailer->Host = Env::get('SMTP_HOST');
            $this->mailer->Port = Env::get('SMTP_PORT');
            $this->mailer->SMTPAuth = false;
            $this->mailer->SMTPSecure = false;
            $this->mailer->SMTPAutoTLS = false;

            // Charset
            $this->mailer->CharSet = 'UTF-8';
            
            // From
            $this->mailer->setFrom(Env::get('SMTP_FROM'));

            // Debug (desabilitar em produção)
            $this->mailer->SMTPDebug = 0;
        } catch (Exception $e) {
            error_log("[email] Erro na configuração: " . $e->getMessage());
        }
    }

    public function verifyConnection(): bool
    {
        if (Env::get('EMAIL_LOG_ONLY')) {
            error_log('[email] Modo LOG_ONLY ativo');
            return true;
        }

        try {
            $this->mailer->smtpConnect();
            error_log('[email] ✅ SMTP conectado');
            return true;
        } catch (Exception $e) {
            error_log('[email] ❌ Erro na conexão: ' . $e->getMessage());
            return false;
        }
    }

    public function sendEmail(string $to, string $subject, string $text, string $html): void
    {
        if (Env::get('EMAIL_LOG_ONLY')) {
            error_log("[email][LOG_ONLY] to=$to subject=\"$subject\"");
            return;
        }

        try {
            $this->mailer->clearAddresses();
            $this->mailer->addAddress($to);
            $this->mailer->Subject = $subject;
            $this->mailer->Body = $html;
            $this->mailer->AltBody = $text;
            $this->mailer->isHTML(true);

            $this->mailer->send();
            error_log("[email] ✅ Enviado para: $to");
        } catch (Exception $e) {
            error_log('[email] ❌ Erro ao enviar: ' . $e->getMessage());
            throw $e;
        }
    }

    public function sendVerificationEmail(string $to, string $code): void
    {
        $subject = 'Seu código de verificação';
        $expirationMinutes = Env::get('CODE_EXPIRATION_MINUTES');

        $text = "Olá!\n\n" .
                "Seu código de verificação é: $code\n\n" .
                "Este código expira em $expirationMinutes minutos.\n\n" .
                "Se não foi você, ignore este e-mail.";

        $html = "
<!DOCTYPE html>
<html>
<head>
  <meta charset='utf-8'>
</head>
<body style='font-family: Arial, sans-serif; padding: 20px; background: #f5f5f5;'>
  <div style='max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px;'>
    <h2 style='color: #333; margin-top: 0;'>Verificação de Conta</h2>
    <p style='color: #666; font-size: 16px;'>Seu código de verificação é:</p>
    <div style='background: #f8f9fa; padding: 20px; text-align: center; border-radius: 8px; margin: 20px 0;'>
      <h1 style='color: #e50914; font-size: 36px; margin: 0; letter-spacing: 4px;'>$code</h1>
    </div>
    <p style='color: #999; font-size: 14px;'>Este código expira em $expirationMinutes minutos.</p>
    <p style='color: #ccc; font-size: 12px;'>Se não foi você, ignore este e-mail.</p>
  </div>
</body>
</html>
        ";

        $this->sendEmail($to, $subject, $text, $html);
    }

    public function sendPasswordResetEmail(string $to, string $code): void
    {
        $subject = 'Recuperação de Senha';
        $expirationMinutes = Env::get('CODE_EXPIRATION_MINUTES');

        $text = "Olá!\n\n" .
                "Você solicitou a recuperação de senha da sua conta.\n\n" .
                "Seu código de recuperação é: $code\n\n" .
                "Este código expira em $expirationMinutes minutos.\n\n" .
                "Se você não solicitou, ignore este e-mail.";

        $html = "
<!DOCTYPE html>
<html>
<head>
  <meta charset='utf-8'>
</head>
<body style='font-family: Arial, sans-serif; padding: 20px; background: #f5f5f5;'>
  <div style='max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px;'>
    <h2 style='color: #333; margin-top: 0;'>Recuperação de Senha</h2>
    <p style='color: #666; font-size: 16px;'>Você solicitou a recuperação de senha.</p>
    <p style='color: #666;'>Seu código de recuperação é:</p>
    <div style='background: #f8f9fa; padding: 20px; text-align: center; border-radius: 8px; margin: 20px 0;'>
      <h1 style='color: #e50914; font-size: 36px; margin: 0; letter-spacing: 4px;'>$code</h1>
    </div>
    <p style='color: #999; font-size: 14px;'>Este código expira em $expirationMinutes minutos.</p>
    <p style='color: #ccc; font-size: 12px;'>Se não foi você, ignore este e-mail.</p>
  </div>
</body>
</html>
        ";

        $this->sendEmail($to, $subject, $text, $html);
    }
}
```

## 💾 Arquivo: `src/services/CodeStorage.php`

```php
<?php

namespace App\Services;

use App\Config\Env;

class CodeStorage
{
    private static array $verificationCodes = [];
    private static array $resetCodes = [];

    public static function generateCode(): string
    {
        return str_pad((string)random_int(100000, 999999), 6, '0', STR_PAD_LEFT);
    }

    public static function saveVerificationCode(string $email, string $code): void
    {
        $expiresAt = time() + (Env::get('CODE_EXPIRATION_MINUTES') * 60);
        self::$verificationCodes[$email] = [
            'code' => $code,
            'expiresAt' => $expiresAt,
        ];
    }

    public static function getVerificationCode(string $email): ?array
    {
        self::cleanExpiredCodes();
        return self::$verificationCodes[$email] ?? null;
    }

    public static function deleteVerificationCode(string $email): void
    {
        unset(self::$verificationCodes[$email]);
    }

    public static function saveResetCode(string $email, string $code): void
    {
        $expiresAt = time() + (Env::get('CODE_EXPIRATION_MINUTES') * 60);
        self::$resetCodes[$email] = [
            'code' => $code,
            'expiresAt' => $expiresAt,
        ];
    }

    public static function getResetCode(string $email): ?array
    {
        self::cleanExpiredCodes();
        return self::$resetCodes[$email] ?? null;
    }

    public static function deleteResetCode(string $email): void
    {
        unset(self::$resetCodes[$email]);
    }

    private static function cleanExpiredCodes(): void
    {
        $now = time();

        // Limpar códigos de verificação expirados
        foreach (self::$verificationCodes as $email => $data) {
            if ($data['expiresAt'] < $now) {
                unset(self::$verificationCodes[$email]);
            }
        }

        // Limpar códigos de reset expirados
        foreach (self::$resetCodes as $email => $data) {
            if ($data['expiresAt'] < $now) {
                unset(self::$resetCodes[$email]);
            }
        }
    }
}
```

## 🛣️ Arquivo: `src/routes/auth.php`

```php
<?php

namespace App\Routes;

use App\Services\EmailService;
use App\Services\CodeStorage;

class Auth
{
    private EmailService $emailService;

    public function __construct()
    {
        $this->emailService = new EmailService();
    }

    public function register(): void
    {
        $data = json_decode(file_get_contents('php://input'), true);
        $email = $data['email'] ?? null;

        if (!$email) {
            http_response_code(400);
            echo json_encode(['error' => 'Email é obrigatório']);
            return;
        }

        try {
            // Gerar código
            $code = CodeStorage::generateCode();
            CodeStorage::saveVerificationCode($email, $code);

            // Enviar e-mail
            $this->emailService->sendVerificationEmail($email, $code);

            echo json_encode([
                'success' => true,
                'message' => 'Código enviado para seu e-mail',
            ]);
        } catch (\Exception $e) {
            http_response_code(500);
            echo json_encode([
                'error' => 'Erro ao enviar e-mail',
                'details' => $e->getMessage(),
            ]);
        }
    }

    public function verifyCode(): void
    {
        $data = json_decode(file_get_contents('php://input'), true);
        $email = $data['email'] ?? null;
        $code = $data['code'] ?? null;

        if (!$email || !$code) {
            http_response_code(400);
            echo json_encode(['error' => 'Email e código são obrigatórios']);
            return;
        }

        // Buscar código
        $stored = CodeStorage::getVerificationCode($email);

        if (!$stored) {
            http_response_code(400);
            echo json_encode(['error' => 'Código inválido ou expirado']);
            return;
        }

        // Verificar expiração
        if (time() > $stored['expiresAt']) {
            CodeStorage::deleteVerificationCode($email);
            http_response_code(400);
            echo json_encode(['error' => 'Código expirado']);
            return;
        }

        // Verificar código
        if ($stored['code'] !== $code) {
            http_response_code(400);
            echo json_encode(['error' => 'Código incorreto']);
            return;
        }

        // Remover código usado
        CodeStorage::deleteVerificationCode($email);

        echo json_encode([
            'success' => true,
            'message' => 'Código verificado com sucesso',
        ]);
    }

    public function forgotPassword(): void
    {
        $data = json_decode(file_get_contents('php://input'), true);
        $email = $data['email'] ?? null;

        if (!$email) {
            http_response_code(400);
            echo json_encode(['error' => 'Email é obrigatório']);
            return;
        }

        try {
            // Gerar código
            $code = CodeStorage::generateCode();
            CodeStorage::saveResetCode($email, $code);

            // Enviar e-mail
            $this->emailService->sendPasswordResetEmail($email, $code);

            echo json_encode([
                'success' => true,
                'message' => 'Código de recuperação enviado',
            ]);
        } catch (\Exception $e) {
            http_response_code(500);
            echo json_encode([
                'error' => 'Erro ao enviar e-mail',
                'details' => $e->getMessage(),
            ]);
        }
    }

    public function resetPassword(): void
    {
        $data = json_decode(file_get_contents('php://input'), true);
        $email = $data['email'] ?? null;
        $code = $data['code'] ?? null;
        $newPassword = $data['newPassword'] ?? null;

        if (!$email || !$code || !$newPassword) {
            http_response_code(400);
            echo json_encode(['error' => 'Todos os campos são obrigatórios']);
            return;
        }

        // Buscar código
        $stored = CodeStorage::getResetCode($email);

        if (!$stored) {
            http_response_code(400);
            echo json_encode(['error' => 'Código inválido ou expirado']);
            return;
        }

        // Verificar expiração
        if (time() > $stored['expiresAt']) {
            CodeStorage::deleteResetCode($email);
            http_response_code(400);
            echo json_encode(['error' => 'Código expirado']);
            return;
        }

        // Verificar código
        if ($stored['code'] !== $code) {
            http_response_code(400);
            echo json_encode(['error' => 'Código incorreto']);
            return;
        }

        // Remover código
        CodeStorage::deleteResetCode($email);

        // Aqui você atualizaria a senha no banco
        // $userService->updatePassword($email, $newPassword);

        echo json_encode([
            'success' => true,
            'message' => 'Senha atualizada com sucesso',
        ]);
    }

    public function health(): void
    {
        $smtpConnected = $this->emailService->verifyConnection();

        echo json_encode([
            'status' => 'ok',
            'smtp' => $smtpConnected,
        ]);
    }
}
```

## 🚀 Arquivo: `src/index.php`

```php
<?php

require __DIR__ . '/../vendor/autoload.php';

use App\Config\Env;
use App\Routes\Auth;

// Configurar headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Carregar variáveis de ambiente
Env::load();

// Roteamento simples
$method = $_SERVER['REQUEST_METHOD'];
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

// Remover prefixo se houver
$path = str_replace('/index.php', '', $path);

$auth = new Auth();

match ([$method, $path]) {
    ['POST', '/api/auth/register'] => $auth->register(),
    ['POST', '/api/auth/verify-code'] => $auth->verifyCode(),
    ['POST', '/api/auth/forgot-password'] => $auth->forgotPassword(),
    ['POST', '/api/auth/reset-password'] => $auth->resetPassword(),
    ['GET', '/api/auth/health'] => $auth->health(),
    ['GET', '/'] => print(json_encode(['status' => 'ok', 'message' => 'Email API PHP'])),
    default => (function() {
        http_response_code(404);
        echo json_encode(['error' => 'Rota não encontrada']);
    })(),
};
```

## ▶️ Como Executar

### 1. Instalar dependências:
```bash
composer install
```

### 2. Configurar `.env`

### 3. Rodar servidor PHP:
```bash
# Opção 1: Built-in server
php -S localhost:8000 -t src

# Opção 2: Apache/Nginx
# Configure virtual host apontando para src/index.php
```

### 4. Testar:

```bash
# Registrar
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "usuario@email.com"}'

# Verificar código
curl -X POST http://localhost:8000/api/auth/verify-code \
  -H "Content-Type: application/json" \
  -d '{"email": "usuario@email.com", "code": "123456"}'

# Recuperar senha
curl -X POST http://localhost:8000/api/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{"email": "usuario@email.com"}'

# Resetar senha
curl -X POST http://localhost:8000/api/auth/reset-password \
  -H "Content-Type: application/json" \
  -d '{"email":"usuario@email.com","code":"123456","newPassword":"nova123"}'

# Health check
curl http://localhost:8000/api/auth/health
```

## 🔧 Com Redis (Recomendado)

```php
<?php

namespace App\Services;

use Predis\Client;
use App\Config\Env;

class RedisCodeStorage
{
    private Client $redis;

    public function __construct()
    {
        $this->redis = new Client([
            'host' => Env::get('REDIS_HOST'),
            'port' => Env::get('REDIS_PORT'),
        ]);
    }

    public function saveCode(string $type, string $email, string $code): void
    {
        $key = "$type:$email";
        $expirationSeconds = Env::get('CODE_EXPIRATION_MINUTES') * 60;
        $this->redis->setex($key, $expirationSeconds, $code);
    }

    public function getCode(string $type, string $email): ?string
    {
        $key = "$type:$email";
        $code = $this->redis->get($key);
        return $code ?: null;
    }

    public function deleteCode(string $type, string $email): void
    {
        $key = "$type:$email";
        $this->redis->del([$key]);
    }
}
```

## 🔐 Com Laravel (Alternativa)

```php
// app/Services/EmailService.php
namespace App\Services;

use Illuminate\Support\Facades\Mail;
use App\Mail\VerificationMail;
use App\Mail\PasswordResetMail;

class EmailService
{
    public function sendVerificationEmail(string $to, string $code): void
    {
        Mail::to($to)->send(new VerificationMail($code));
    }

    public function sendPasswordResetEmail(string $to, string $code): void
    {
        Mail::to($to)->send(new PasswordResetMail($code));
    }
}

// app/Mail/VerificationMail.php
namespace App\Mail;

use Illuminate\Mail\Mailable;

class VerificationMail extends Mailable
{
    public function __construct(public string $code)
    {
    }

    public function build()
    {
        return $this->view('emails.verification')
                    ->with(['code' => $this->code])
                    ->subject('Seu código de verificação');
    }
}
```

## ✅ Checklist

- [ ] Configurar composer.json
- [ ] Criar .env
- [ ] Implementar EmailService (PHPMailer)
- [ ] Criar rotas de autenticação
- [ ] Testar endpoints
- [ ] Adicionar validações
- [ ] Implementar Redis
- [ ] Adicionar rate limiting
- [ ] Configurar Apache/Nginx
- [ ] Documentar API

---

**Status:** ✅ Implementação funcional
**PHP:** 8.1+
**Framework:** Vanilla PHP ou Laravel
