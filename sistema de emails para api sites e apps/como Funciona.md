# Sistema de E-mails Próprio - Sem Dependências de Terceiros

## 📋 Índice
1. [Visão Geral](#visão-geral)
2. [Arquitetura](#arquitetura)
3. [Como Funciona](#como-funciona)
4. [Implementação na API](#implementação-na-api)
5. [Configuração do Servidor](#configuração-do-servidor)
6. [DNS e Domínio](#dns-e-domínio)
7. [Como Replicar em Outras APIs](#como-replicar-em-outras-apis)
8. [Vantagens e Desvantagens](#vantagens-e-desvantagens)

---

## 🎯 Visão Geral

Este sistema envia e-mails **sem depender de serviços terceiros** como SendGrid, Mailgun, Amazon SES, etc. 

**Tecnologia Base:** Postfix (servidor SMTP) + Node.js (nodemailer)

**Custo:** **R$ 0,00** (apenas o servidor que você já tem)

**Diferencial:** Você é o dono do servidor de e-mail, não depende de limites, pagamentos ou políticas de terceiros.

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    SERVIDOR VPS (Linux)                      │
│                                                              │
│  ┌──────────────────┐         ┌─────────────────────────┐  │
│  │   API Node.js    │         │   Postfix (SMTP Server) │  │
│  │   (Backend)      │ ──────> │   Porta 25              │  │
│  │                  │  SMTP   │   127.0.0.1:25          │  │
│  │  nodemailer      │         │                         │  │
│  └──────────────────┘         └─────────────────────────┘  │
│         ↓                                 ↓                  │
│  Gera e-mails                    Envia para internet        │
└─────────────────────────────────────────────────────────────┘
                                    ↓
                     ┌──────────────────────────────┐
                     │  Internet / Destinatário     │
                     │  (Gmail, Outlook, etc)       │
                     └──────────────────────────────┘
```

### Fluxo Completo:
1. **Usuário** solicita código de verificação no app
2. **API Node.js** gera código de 6 dígitos
3. **nodemailer** cria e-mail HTML formatado
4. **nodemailer** conecta no **Postfix local** (porta 25)
5. **Postfix** envia para servidor de destino (Gmail, etc)
6. **Destinatário** recebe o e-mail

---

## ⚙️ Como Funciona

### 1. Servidor SMTP (Postfix)

O **Postfix** é um servidor SMTP instalado no mesmo servidor da API. Ele funciona como:
- **MTA (Mail Transfer Agent)**: Envia e-mails para a internet
- **Porta 25**: Interface local para aplicações enviarem e-mails
- **Autenticação**: Não requer login quando conexão é local (127.0.0.1)

### 2. API Node.js (nodemailer)

A API usa o **nodemailer** para se conectar ao Postfix:

```typescript
// Configuração do transporter
const transporter = nodemailer.createTransport({
  host: '127.0.0.1',           // Postfix local
  port: 25,                    // Porta SMTP padrão
  secure: false,               // Sem SSL (conexão local)
  auth: undefined,             // Sem autenticação (local)
  tls: { rejectUnauthorized: false }
});
```

### 3. Funções de E-mail

#### Verificação de Conta:
```typescript
export async function sendVerificationEmail(to: string, code: string) {
  const mail = {
    from: 'dubDramas <no-reply@dubdramas.asia>',
    to: to,
    subject: 'Seu código de verificação - dubDramas',
    html: `<h2>Seu código: ${code}</h2>`
  };
  await transporter.sendMail(mail);
}
```

#### Recuperação de Senha:
```typescript
export async function sendPasswordResetEmail(to: string, code: string) {
  const mail = {
    from: 'dubDramas <no-reply@dubdramas.asia>',
    to: to,
    subject: 'Recuperação de Senha - dubDramas',
    html: `<div>Seu código de recuperação: ${code}</div>`
  };
  await transporter.sendMail(mail);
}
```

---

## 💻 Implementação na API

### Estrutura de Arquivos:

```
backend/
├── src/
│   ├── utils/
│   │   └── email.ts         # Lógica de envio
│   ├── routes/
│   │   └── auth.ts          # Rotas que usam e-mail
│   └── app.ts               # Inicialização
└── .env                     # Configurações
```

### Arquivo: `src/utils/email.ts`

```typescript
import nodemailer, { Transporter, SendMailOptions } from 'nodemailer';

// Configurações do .env
const SMTP_HOST = process.env.SMTP_HOST || '127.0.0.1';
const SMTP_PORT = Number(process.env.SMTP_PORT || 25);
const SMTP_FROM = process.env.SMTP_FROM || 'no-reply@seusite.com';

// Modo de desenvolvimento (apenas log, sem envio real)
export const LOG_ONLY = process.env.EMAIL_LOG_ONLY === '1';

// Criar transporter
const transporter: Transporter = LOG_ONLY
  ? nodemailer.createTransport({ jsonTransport: true })
  : nodemailer.createTransport({
      host: SMTP_HOST,
      port: SMTP_PORT,
      secure: false,        // true para porta 465 (SSL)
      auth: undefined,      // Não precisa de auth se for local
      tls: { rejectUnauthorized: false }
    });

// Verificar conexão SMTP
export async function verifyEmailTransport() {
  if (LOG_ONLY) {
    console.info('[email] Modo LOG_ONLY - sem envio real');
    return;
  }
  try {
    await transporter.verify();
    console.info(`[email] Conectado ao SMTP ${SMTP_HOST}:${SMTP_PORT}`);
  } catch (err) {
    console.error('[email] Erro ao conectar SMTP:', err);
  }
}

// Enviar e-mail de verificação
export async function sendVerificationEmail(to: string, code: string) {
  const mail: SendMailOptions = {
    from: SMTP_FROM,
    to: to,
    subject: 'Seu código de verificação',
    text: `Seu código é: ${code}`,
    html: `
      <div style="font-family:sans-serif;padding:20px">
        <h2>Verificação de Conta</h2>
        <p>Seu código de verificação é:</p>
        <h1 style="font-size:32px;color:#e50914">${code}</h1>
        <p>Válido por 15 minutos.</p>
      </div>
    `
  };

  const info = await transporter.sendMail(mail);
  
  if (LOG_ONLY) {
    console.log('[email] LOG:', to, code);
  } else {
    console.log('[email] Enviado para:', to);
  }
}

// Enviar e-mail de recuperação de senha
export async function sendPasswordResetEmail(to: string, code: string) {
  const mail: SendMailOptions = {
    from: SMTP_FROM,
    to: to,
    subject: 'Recuperação de Senha',
    html: `
      <div style="font-family:sans-serif;padding:20px">
        <h2>Recuperação de Senha</h2>
        <p>Seu código de recuperação:</p>
        <h1 style="font-size:32px;color:#e50914">${code}</h1>
        <p>Expira em 15 minutos.</p>
      </div>
    `
  };

  await transporter.sendMail(mail);
  console.log('[email] Recuperação enviada para:', to);
}
```

### Arquivo: `.env`

```env
# E-mail Configuration
EMAIL_LOG_ONLY=0                    # 0=enviar real, 1=apenas log
SMTP_HOST=127.0.0.1                 # Postfix local
SMTP_PORT=25                        # Porta SMTP
SMTP_FROM="SeuApp <no-reply@seusite.com>"
```

### Uso nas Rotas:

```typescript
// src/routes/auth.ts
import { sendVerificationEmail, sendPasswordResetEmail } from '../utils/email';

// Rota de registro
router.post('/register', async (req, res) => {
  const { email } = req.body;
  
  // Gerar código de 6 dígitos
  const code = Math.floor(100000 + Math.random() * 900000).toString();
  
  // Salvar código no banco (com expiração)
  await saveVerificationCode(email, code);
  
  // Enviar e-mail
  await sendVerificationEmail(email, code);
  
  res.json({ success: true });
});

// Rota de recuperação de senha
router.post('/forgot-password', async (req, res) => {
  const { email } = req.body;
  
  const code = Math.floor(100000 + Math.random() * 900000).toString();
  await savePasswordResetCode(email, code);
  await sendPasswordResetEmail(email, code);
  
  res.json({ success: true });
});
```

---

## 🖥️ Configuração do Servidor

### Passo 1: Instalar Postfix

```bash
# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar Postfix
sudo apt install postfix -y

# Durante instalação:
# - Tipo: Internet Site
# - System mail name: seusite.com
```

### Passo 2: Configurar Postfix

Editar `/etc/postfix/main.cf`:

```conf
# Hostname e domínio
myhostname = mail.seusite.com
mydomain = seusite.com
myorigin = $mydomain

# Aceitar conexões de onde?
inet_interfaces = all

# Quem pode receber?
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain

# Banner SMTP
smtpd_banner = $myhostname ESMTP SeuApp Mail Server

# TLS (opcional mas recomendado)
smtpd_tls_cert_file = /etc/ssl/certs/ssl-cert-snakeoil.pem
smtpd_tls_key_file = /etc/ssl/private/ssl-cert-snakeoil.key
smtpd_tls_security_level = may

# Relay (vazio = não usar relay)
relayhost =

# Rede local confiável
mynetworks = 127.0.0.0/8
```

### Passo 3: Reiniciar Postfix

```bash
sudo systemctl restart postfix
sudo systemctl enable postfix
sudo systemctl status postfix
```

### Passo 4: Testar Envio

```bash
# Teste local
echo "Teste de e-mail" | mail -s "Assunto" seuemail@gmail.com

# Verificar fila
mailq

# Ver logs
tail -f /var/log/mail.log
```

---

## 🌐 DNS e Domínio

### Registros DNS Necessários:

#### 1. Registro MX (Mail Exchange)
```
Tipo: MX
Nome: @
Prioridade: 10
Valor: mail.seusite.com
```

#### 2. Registro A (IP do servidor de e-mail)
```
Tipo: A
Nome: mail
Valor: 212.85.10.203  # IP do seu servidor
```

#### 3. Registro SPF (Sender Policy Framework)
```
Tipo: TXT
Nome: @
Valor: v=spf1 a mx ip4:212.85.10.203 ~all
```

Significado:
- `v=spf1` = versão SPF
- `a` = aceitar e-mails do IP do registro A
- `mx` = aceitar e-mails do servidor MX
- `ip4:212.85.10.203` = aceitar desse IP específico
- `~all` = softfail para outros (marca como suspeito mas não rejeita)

#### 4. Registro DKIM (opcional, recomendado)
```bash
# Instalar OpenDKIM
sudo apt install opendkim opendkim-tools -y

# Gerar chaves
sudo opendkim-genkey -s mail -d seusite.com

# Ver chave pública
sudo cat /etc/opendkim/keys/seusite.com/mail.txt
```

Adicionar no DNS:
```
Tipo: TXT
Nome: mail._domainkey
Valor: v=DKIM1; k=rsa; p=MIIBIjANBgkqhki...  # Chave pública
```

#### 5. Registro DMARC (opcional)
```
Tipo: TXT
Nome: _dmarc
Valor: v=DMARC1; p=none; rua=mailto:postmaster@seusite.com
```

### Verificar DNS:

```bash
# Verificar MX
dig +short seusite.com MX

# Verificar SPF
dig +short seusite.com TXT | grep spf

# Verificar DKIM
dig +short mail._domainkey.seusite.com TXT

# Verificar DMARC
dig +short _dmarc.seusite.com TXT
```

---

## 🔄 Como Replicar em Outras APIs

### Checklist Completo:

#### 1. Preparar Servidor VPS
- [ ] Linux (Ubuntu/Debian recomendado)
- [ ] IP fixo público
- [ ] Porta 25 aberta (saída)
- [ ] Acesso root/sudo

#### 2. Instalar Postfix
```bash
sudo apt update
sudo apt install postfix mailutils -y
```

Escolher:
- **Internet Site**
- **System mail name**: seudominio.com

#### 3. Configurar DNS (no seu provedor de domínio)

**No Cloudflare, GoDaddy, HostGator, etc:**

```
# Registro MX
Tipo: MX
Nome: @
Prioridade: 10
Valor: mail.seudominio.com

# Registro A (para mail.seudominio.com)
Tipo: A
Nome: mail
Valor: SEU_IP_DO_SERVIDOR

# Registro SPF
Tipo: TXT
Nome: @
Valor: v=spf1 a mx ip4:SEU_IP_DO_SERVIDOR ~all
```

**Aguardar propagação** (pode levar até 24h, geralmente 1-2h)

#### 4. Configurar Postfix

Editar `/etc/postfix/main.cf`:

```conf
myhostname = mail.seudominio.com
mydomain = seudominio.com
myorigin = $mydomain
inet_interfaces = all
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain
mynetworks = 127.0.0.0/8
relayhost =
smtpd_banner = $myhostname ESMTP
```

Reiniciar:
```bash
sudo systemctl restart postfix
sudo systemctl enable postfix
```

#### 5. Implementar na API Node.js

**Instalar dependências:**
```bash
npm install nodemailer
npm install --save-dev @types/nodemailer
```

**Criar arquivo `src/utils/email.ts`:**

Copiar o código completo da seção [Implementação na API](#implementação-na-api)

**Configurar `.env`:**
```env
EMAIL_LOG_ONLY=0
SMTP_HOST=127.0.0.1
SMTP_PORT=25
SMTP_FROM="SeuApp <no-reply@seudominio.com>"
```

#### 6. Testar Envio

**Teste simples:**
```bash
echo "Teste" | mail -s "Assunto" seuemail@gmail.com
```

**Teste na API:**
```typescript
// Adicionar no bootstrap da aplicação
import { verifyEmailTransport } from './utils/email';

async function startServer() {
  await verifyEmailTransport();  // Verifica conexão SMTP
  // ... resto do código
}
```

#### 7. Verificar Recebimento

- Enviar e-mail de teste
- Verificar caixa de entrada
- Se cair no spam, verificar:
  - DNS (MX, SPF)
  - Reverse DNS do IP
  - DKIM configurado
  - Reputação do IP

#### 8. Monitoramento

**Ver fila de e-mails:**
```bash
mailq
```

**Ver logs em tempo real:**
```bash
tail -f /var/log/mail.log
```

**Limpar fila (se necessário):**
```bash
sudo postsuper -d ALL
```

---

## ✅ Vantagens e Desvantagens

### ✅ Vantagens:

1. **Custo Zero**
   - Sem mensalidades
   - Sem limites de envio
   - Sem cobrança por e-mail

2. **Controle Total**
   - Você gerencia tudo
   - Sem depender de terceiros
   - Sem bloqueios arbitrários

3. **Privacidade**
   - Dados não passam por terceiros
   - Conformidade com LGPD/GDPR mais fácil

4. **Simplicidade**
   - Integração direta (localhost)
   - Menos código
   - Sem APIs externas

5. **Performance**
   - Latência mínima (localhost)
   - Sem chamadas HTTP externas

### ❌ Desvantagens:

1. **Reputação de IP**
   - IP novo pode cair no spam inicialmente
   - Precisa "esquentar" o IP gradualmente
   - Pode ser bloqueado se não configurar DNS corretamente

2. **Manutenção**
   - Você é responsável pela infraestrutura
   - Precisa monitorar logs
   - Precisa resolver problemas de entrega

3. **Deliverability**
   - Serviços profissionais (SendGrid, etc) têm melhor reputação
   - Grandes volumes podem ter problemas
   - Sem analytics avançados

4. **Escalabilidade**
   - Para milhões de e-mails, serviços terceiros são melhores
   - Precisa otimizar Postfix para alto volume

5. **Recursos Limitados**
   - Sem templates prontos
   - Sem estatísticas de abertura/cliques
   - Sem gestão de bounces automatizada

---

## 📊 Quando Usar Este Sistema?

### ✅ Ideal Para:

- **Pequenas e médias aplicações** (até 10k e-mails/dia)
- **E-mails transacionais** (verificação, senha, notificações)
- **Projetos com orçamento limitado**
- **Aplicações que valorizam privacidade**
- **Prototipagem e MVPs**

### ❌ Não Recomendado Para:

- **Marketing em massa** (newsletters para milhares)
- **Alto volume** (100k+ e-mails/dia)
- **Aplicações críticas** que não podem ter downtime
- **Empresas sem equipe técnica** para manutenção
- **E-commerce grande** (melhor usar serviço profissional)

---

## 🔧 Troubleshooting

### E-mails caindo no spam?

**1. Verificar SPF:**
```bash
dig +short seudominio.com TXT | grep spf
```

**2. Configurar Reverse DNS:**
Solicitar ao provedor do VPS que configure PTR record:
```
IP: 212.85.10.203
PTR: mail.seudominio.com
```

**3. Implementar DKIM:**
```bash
sudo apt install opendkim opendkim-tools
sudo opendkim-genkey -s mail -d seudominio.com
```

**4. Testar reputação do IP:**
- https://mxtoolbox.com/blacklists.aspx
- https://www.mail-tester.com/

### E-mails não estão saindo?

**1. Verificar Postfix:**
```bash
sudo systemctl status postfix
```

**2. Ver fila:**
```bash
mailq
```

**3. Ver logs:**
```bash
sudo tail -f /var/log/mail.log
```

**4. Testar porta 25:**
```bash
telnet 127.0.0.1 25
```

### Porta 25 bloqueada?

Alguns provedores VPS bloqueiam porta 25. Soluções:

**1. Usar relay SMTP:**
```conf
# /etc/postfix/main.cf
relayhost = [smtp.sendgrid.net]:587
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_security_level = encrypt
```

**2. Solicitar desbloqueio:**
Abrir ticket com o provedor pedindo liberação da porta 25.

**3. Usar outro provedor:**
DigitalOcean, Vultr, Linode geralmente permitem porta 25.

---

## 📝 Exemplo Real: dubDramas

### Configuração Atual:

**Servidor:**
- VPS Linux
- IP: 212.85.10.203
- Domínio: dubdramas.asia

**DNS:**
```
MX:  10 mail.dubdramas.asia
A:   mail.dubdramas.asia → 212.85.10.203
SPF: v=spf1 a mx ip4:212.85.10.203 ~all
```

**Postfix:**
```conf
myhostname = mail.dubdramas.asia
mydomain = dubdramas.asia
myorigin = $mydomain
```

**API:**
```typescript
// src/utils/email.ts
SMTP_HOST = '127.0.0.1'
SMTP_PORT = 25
SMTP_FROM = 'dubDramas <no-reply@dubdramas.asia>'
```

**Resultado:**
- ✅ Emails entregues com sucesso
- ✅ Não cai no spam (Gmail, Outlook testados)
- ✅ Custo zero
- ✅ 100% independente

---

## 🚀 Próximos Passos (Melhorias)

### 1. Implementar DKIM
```bash
sudo apt install opendkim opendkim-tools
```

### 2. Adicionar Templates HTML Profissionais
```typescript
const templates = {
  verification: (code: string) => `
    <div style="max-width:600px;margin:0 auto;font-family:Arial">
      <img src="https://seusite.com/logo.png" alt="Logo" />
      <h1>Verificação de Conta</h1>
      <p>Código: <strong>${code}</strong></p>
    </div>
  `
};
```

### 3. Sistema de Retry
```typescript
async function sendEmailWithRetry(mail: MailOptions, retries = 3) {
  for (let i = 0; i < retries; i++) {
    try {
      return await transporter.sendMail(mail);
    } catch (err) {
      if (i === retries - 1) throw err;
      await sleep(1000 * (i + 1));
    }
  }
}
```

### 4. Logging Avançado
```typescript
import winston from 'winston';

const logger = winston.createLogger({
  transports: [
    new winston.transports.File({ filename: 'email.log' })
  ]
});

logger.info('Email sent', { to, subject, timestamp: new Date() });
```

### 5. Fila de E-mails (Bull/Redis)
```typescript
import Queue from 'bull';

const emailQueue = new Queue('emails', {
  redis: { host: '127.0.0.1', port: 6379 }
});

emailQueue.process(async (job) => {
  await sendEmail(job.data);
});

// Adicionar na fila
emailQueue.add({ to, subject, html });
```

---

## 📚 Recursos Adicionais

### Documentação:
- [Postfix Documentation](http://www.postfix.org/documentation.html)
- [nodemailer Documentation](https://nodemailer.com/)
- [SPF Record Syntax](https://www.dmarcanalyzer.com/spf/)
- [DKIM Setup Guide](https://www.linode.com/docs/guides/configure-spf-and-dkim-in-postfix-on-debian-8/)

### Ferramentas de Teste:
- [MXToolbox](https://mxtoolbox.com/) - Testar DNS, MX, SPF
- [Mail Tester](https://www.mail-tester.com/) - Testar spam score
- [DKIM Validator](https://dkimvalidator.com/) - Validar DKIM
- [Blacklist Check](https://mxtoolbox.com/blacklists.aspx) - Ver se IP está bloqueado

### Comunidade:
- Stack Overflow: `[postfix]` `[nodemailer]`
- Reddit: r/selfhosted
- ServerFault: Para questões de infraestrutura

---

## ✨ Conclusão

Este sistema de e-mails próprio é:
- **Gratuito** (custo zero)
- **Independente** (sem terceiros)
- **Simples** (fácil de implementar)
- **Eficiente** (baixa latência)
- **Privado** (dados não vazam)

**Perfeito para:**
- Aplicações pequenas e médias
- E-mails transacionais (verificação, senha)
- Projetos com orçamento limitado
- Equipes que valorizam privacidade

**Use serviços terceiros (SendGrid, Mailgun) se:**
- Precisar de alto volume (100k+/dia)
- Precisar de analytics avançados
- Não tiver equipe técnica
- For fazer marketing em massa

---

## 📞 Suporte

Para dúvidas sobre este sistema:
- Consulte os logs: `/var/log/mail.log`
- Teste DNS: `dig +short seudominio.com MX`
- Verifique Postfix: `sudo systemctl status postfix`
- Teste envio: `echo "teste" | mail -s "assunto" email@test.com`

---

**Última atualização:** 29/12/2025
**Sistema testado em:** dubDramas (dubdramas.asia)
**Status:** ✅ Funcionando em produção
