# Sistema de E-mails - Implementação TypeScript

## 📦 Dependências

```json
{
  "name": "email-api-typescript",
  "version": "1.0.0",
  "scripts": {
    "dev": "tsx watch src/server.ts",
    "build": "tsc",
    "start": "node dist/server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "nodemailer": "^6.9.7",
    "dotenv": "^16.3.1",
    "ioredis": "^5.3.2"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/nodemailer": "^6.4.14",
    "@types/node": "^20.10.0",
    "typescript": "^5.3.2",
    "tsx": "^4.6.2"
  }
}
```

## 📁 Estrutura de Arquivos

```
src/
├── server.ts
├── config/
│   └── env.ts
├── services/
│   └── EmailService.ts
├── routes/
│   └── auth.ts
└── types/
    └── index.ts
```

## 🔧 Arquivo: `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "lib": ["ES2022"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

## 🌍 Arquivo: `.env`

```env
# Server
PORT=3000
NODE_ENV=development

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

## 🔧 Arquivo: `src/config/env.ts`

```typescript
import dotenv from 'dotenv';

dotenv.config();

export const env = {
  PORT: parseInt(process.env.PORT || '3000', 10),
  NODE_ENV: process.env.NODE_ENV || 'development',
  
  EMAIL_LOG_ONLY: process.env.EMAIL_LOG_ONLY === '1',
  SMTP_HOST: process.env.SMTP_HOST || '127.0.0.1',
  SMTP_PORT: parseInt(process.env.SMTP_PORT || '25', 10),
  SMTP_USER: process.env.SMTP_USER || '',
  SMTP_PASS: process.env.SMTP_PASS || '',
  SMTP_FROM: process.env.SMTP_FROM || 'no-reply@seusite.com',
  
  REDIS_HOST: process.env.REDIS_HOST || 'localhost',
  REDIS_PORT: parseInt(process.env.REDIS_PORT || '6379', 10),
  
  CODE_EXPIRATION_MINUTES: parseInt(process.env.CODE_EXPIRATION_MINUTES || '15', 10),
};
```

## 📧 Arquivo: `src/services/EmailService.ts`

```typescript
import nodemailer, { Transporter } from 'nodemailer';
import { env } from '../config/env';

export class EmailService {
  private transporter: Transporter;

  constructor() {
    this.transporter = nodemailer.createTransport({
      host: env.SMTP_HOST,
      port: env.SMTP_PORT,
      secure: false, // true para 465, false para outras portas
      auth: env.SMTP_USER ? {
        user: env.SMTP_USER,
        pass: env.SMTP_PASS,
      } : undefined,
      tls: {
        rejectUnauthorized: false,
      },
    });
  }

  async verifyConnection(): Promise<boolean> {
    if (env.EMAIL_LOG_ONLY) {
      console.log('[email] Modo LOG_ONLY ativo');
      return true;
    }

    try {
      await this.transporter.verify();
      console.log('[email] ✅ SMTP conectado');
      return true;
    } catch (error) {
      console.error('[email] ❌ Erro na conexão:', error);
      return false;
    }
  }

  async sendEmail(
    to: string,
    subject: string,
    text: string,
    html: string
  ): Promise<void> {
    if (env.EMAIL_LOG_ONLY) {
      console.warn(`[email][LOG_ONLY] to=${to} subject="${subject}"`);
      return;
    }

    try {
      const info = await this.transporter.sendMail({
        from: env.SMTP_FROM,
        to,
        subject,
        text,
        html,
      });

      console.log(`[email] ✅ Enviado para: ${to} (ID: ${info.messageId})`);
    } catch (error) {
      console.error('[email] ❌ Erro ao enviar:', error);
      throw error;
    }
  }

  async sendVerificationEmail(to: string, code: string): Promise<void> {
    const subject = 'Seu código de verificação';

    const text = `
Olá!

Seu código de verificação é: ${code}

Este código expira em ${env.CODE_EXPIRATION_MINUTES} minutos.

Se não foi você, ignore este e-mail.
    `.trim();

    const html = `
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
      <h1 style="color: #e50914; font-size: 36px; margin: 0; letter-spacing: 4px;">${code}</h1>
    </div>
    <p style="color: #999; font-size: 14px;">Este código expira em ${env.CODE_EXPIRATION_MINUTES} minutos.</p>
    <p style="color: #ccc; font-size: 12px;">Se não foi você, ignore este e-mail.</p>
  </div>
</body>
</html>
    `.trim();

    await this.sendEmail(to, subject, text, html);
  }

  async sendPasswordResetEmail(to: string, code: string): Promise<void> {
    const subject = 'Recuperação de Senha';

    const text = `
Olá!

Você solicitou a recuperação de senha da sua conta.

Seu código de recuperação é: ${code}

Este código expira em ${env.CODE_EXPIRATION_MINUTES} minutos.

Se você não solicitou, ignore este e-mail.
    `.trim();

    const html = `
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
      <h1 style="color: #e50914; font-size: 36px; margin: 0; letter-spacing: 4px;">${code}</h1>
    </div>
    <p style="color: #999; font-size: 14px;">Este código expira em ${env.CODE_EXPIRATION_MINUTES} minutos.</p>
    <p style="color: #ccc; font-size: 12px;">Se não foi você, ignore este e-mail.</p>
  </div>
</body>
</html>
    `.trim();

    await this.sendEmail(to, subject, text, html);
  }
}
```

## 📝 Arquivo: `src/types/index.ts`

```typescript
export interface RegisterRequest {
  email: string;
}

export interface VerifyCodeRequest {
  email: string;
  code: string;
}

export interface ForgotPasswordRequest {
  email: string;
}

export interface ResetPasswordRequest {
  email: string;
  code: string;
  newPassword: string;
}

export interface CodeData {
  code: string;
  expiresAt: number; // timestamp
}
```

## 🛣️ Arquivo: `src/routes/auth.ts`

```typescript
import { Router, Request, Response } from 'express';
import { EmailService } from '../services/EmailService';
import { env } from '../config/env';
import {
  RegisterRequest,
  VerifyCodeRequest,
  ResetPasswordRequest,
  CodeData,
} from '../types';

const router = Router();
const emailService = new EmailService();

// Armazenamento em memória (use Redis em produção)
const verificationCodes = new Map<string, CodeData>();
const resetCodes = new Map<string, CodeData>();

// Gerar código de 6 dígitos
function generateCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Limpar códigos expirados
function cleanExpiredCodes() {
  const now = Date.now();
  
  for (const [email, data] of verificationCodes) {
    if (data.expiresAt < now) {
      verificationCodes.delete(email);
    }
  }
  
  for (const [email, data] of resetCodes) {
    if (data.expiresAt < now) {
      resetCodes.delete(email);
    }
  }
}

// Limpar a cada 1 minuto
setInterval(cleanExpiredCodes, 60000);

// POST /api/auth/register
router.post('/register', async (req: Request, res: Response) => {
  try {
    const { email }: RegisterRequest = req.body;

    if (!email) {
      return res.status(400).json({ error: 'Email é obrigatório' });
    }

    // Gerar código
    const code = generateCode();
    const expiresAt = Date.now() + (env.CODE_EXPIRATION_MINUTES * 60 * 1000);

    // Salvar código
    verificationCodes.set(email, { code, expiresAt });

    // Enviar e-mail
    await emailService.sendVerificationEmail(email, code);

    res.json({
      success: true,
      message: 'Código enviado para seu e-mail',
    });
  } catch (error) {
    console.error('Erro ao registrar:', error);
    res.status(500).json({
      error: 'Erro ao enviar e-mail',
      details: error instanceof Error ? error.message : 'Erro desconhecido',
    });
  }
});

// POST /api/auth/verify-code
router.post('/verify-code', (req: Request, res: Response) => {
  const { email, code }: VerifyCodeRequest = req.body;

  if (!email || !code) {
    return res.status(400).json({ error: 'Email e código são obrigatórios' });
  }

  // Buscar código
  const stored = verificationCodes.get(email);

  if (!stored) {
    return res.status(400).json({ error: 'Código inválido ou expirado' });
  }

  // Verificar expiração
  if (Date.now() > stored.expiresAt) {
    verificationCodes.delete(email);
    return res.status(400).json({ error: 'Código expirado' });
  }

  // Verificar código
  if (stored.code !== code) {
    return res.status(400).json({ error: 'Código incorreto' });
  }

  // Remover código usado
  verificationCodes.delete(email);

  res.json({
    success: true,
    message: 'Código verificado com sucesso',
  });
});

// POST /api/auth/forgot-password
router.post('/forgot-password', async (req: Request, res: Response) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ error: 'Email é obrigatório' });
    }

    // Gerar código
    const code = generateCode();
    const expiresAt = Date.now() + (env.CODE_EXPIRATION_MINUTES * 60 * 1000);

    // Salvar código
    resetCodes.set(email, { code, expiresAt });

    // Enviar e-mail
    await emailService.sendPasswordResetEmail(email, code);

    res.json({
      success: true,
      message: 'Código de recuperação enviado',
    });
  } catch (error) {
    console.error('Erro ao enviar recuperação:', error);
    res.status(500).json({
      error: 'Erro ao enviar e-mail',
      details: error instanceof Error ? error.message : 'Erro desconhecido',
    });
  }
});

// POST /api/auth/reset-password
router.post('/reset-password', (req: Request, res: Response) => {
  const { email, code, newPassword }: ResetPasswordRequest = req.body;

  if (!email || !code || !newPassword) {
    return res.status(400).json({ error: 'Todos os campos são obrigatórios' });
  }

  // Buscar código
  const stored = resetCodes.get(email);

  if (!stored) {
    return res.status(400).json({ error: 'Código inválido ou expirado' });
  }

  // Verificar expiração
  if (Date.now() > stored.expiresAt) {
    resetCodes.delete(email);
    return res.status(400).json({ error: 'Código expirado' });
  }

  // Verificar código
  if (stored.code !== code) {
    return res.status(400).json({ error: 'Código incorreto' });
  }

  // Remover código
  resetCodes.delete(email);

  // Aqui você atualizaria a senha no banco
  // await userService.updatePassword(email, newPassword);

  res.json({
    success: true,
    message: 'Senha atualizada com sucesso',
  });
});

// GET /api/auth/health
router.get('/health', async (req: Request, res: Response) => {
  const smtpConnected = await emailService.verifyConnection();

  res.json({
    status: 'ok',
    smtp: smtpConnected,
    verificationCodes: verificationCodes.size,
    resetCodes: resetCodes.size,
  });
});

export default router;
```

## 🚀 Arquivo: `src/server.ts`

```typescript
import express from 'express';
import { env } from './config/env';
import authRoutes from './routes/auth';
import { EmailService } from './services/EmailService';

const app = express();

// Middlewares
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// CORS (se necessário)
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  next();
});

// Rotas
app.use('/api/auth', authRoutes);

// Health check raiz
app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    message: 'Email API TypeScript',
    version: '1.0.0',
  });
});

// Iniciar servidor
async function start() {
  const emailService = new EmailService();
  
  console.log('🚀 Iniciando servidor...');
  
  const smtpConnected = await emailService.verifyConnection();
  if (!smtpConnected && !env.EMAIL_LOG_ONLY) {
    console.warn('⚠️  SMTP não conectado (verifique Postfix)');
  }

  app.listen(env.PORT, () => {
    console.log(`✅ Servidor rodando na porta ${env.PORT}`);
    console.log(`📧 SMTP: ${env.SMTP_HOST}:${env.SMTP_PORT}`);
    console.log(`🔧 Modo: ${env.NODE_ENV}`);
  });
}

start().catch(console.error);
```

## ▶️ Como Executar

### 1. Instalar dependências:
```bash
npm install
```

### 2. Configurar `.env`

### 3. Rodar em desenvolvimento:
```bash
npm run dev
```

### 4. Build para produção:
```bash
npm run build
npm start
```

### 5. Testar:

```bash
# Registrar
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "usuario@email.com"}'

# Verificar código
curl -X POST http://localhost:3000/api/auth/verify-code \
  -H "Content-Type: application/json" \
  -d '{"email": "usuario@email.com", "code": "123456"}'

# Recuperar senha
curl -X POST http://localhost:3000/api/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{"email": "usuario@email.com"}'

# Resetar senha
curl -X POST http://localhost:3000/api/auth/reset-password \
  -H "Content-Type: application/json" \
  -d '{"email":"usuario@email.com","code":"123456","newPassword":"nova123"}'

# Health check
curl http://localhost:3000/api/auth/health
```

## 🔧 Com Redis (Recomendado)

```typescript
// src/services/RedisService.ts
import Redis from 'ioredis';
import { env } from '../config/env';

export class RedisService {
  private client: Redis;

  constructor() {
    this.client = new Redis({
      host: env.REDIS_HOST,
      port: env.REDIS_PORT,
    });
  }

  async saveCode(type: 'verification' | 'reset', email: string, code: string): Promise<void> {
    const key = `${type}:${email}`;
    const expirationSeconds = env.CODE_EXPIRATION_MINUTES * 60;
    await this.client.setex(key, expirationSeconds, code);
  }

  async getCode(type: 'verification' | 'reset', email: string): Promise<string | null> {
    const key = `${type}:${email}`;
    return await this.client.get(key);
  }

  async deleteCode(type: 'verification' | 'reset', email: string): Promise<void> {
    const key = `${type}:${email}`;
    await this.client.del(key);
  }
}
```

## ⚡ Rate Limiting (Express Rate Limit)

```bash
npm install express-rate-limit
```

```typescript
import rateLimit from 'express-rate-limit';

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 5, // 5 requisições por IP
  message: 'Muitas tentativas, tente novamente mais tarde',
});

router.post('/register', limiter, async (req, res) => {
  // ...
});
```

## ✅ Checklist

- [ ] Configurar package.json
- [ ] Criar .env
- [ ] Implementar EmailService
- [ ] Criar rotas de autenticação
- [ ] Testar endpoints
- [ ] Adicionar validações (Joi/Zod)
- [ ] Implementar Redis
- [ ] Adicionar rate limiting
- [ ] Configurar TypeScript
- [ ] Documentar API (Swagger)

---

**Status:** ✅ Implementação funcional
**Node.js:** 18+
**Framework:** Express + TypeScript
