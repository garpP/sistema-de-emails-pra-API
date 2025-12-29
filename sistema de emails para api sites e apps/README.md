# 📧 Sistema de E-mails - Guia Completo

> Sistema de envio de e-mails self-hosted usando Postfix + API  
> **Custo:** R$ 0,00 | **Dependências:** Nenhuma | **Controle:** Total

---

## 📚 Índice de Documentação

### 📖 Guia Principal
- **[como Funciona.md](./como%20Funciona.md)** - Documentação completa sobre arquitetura, configuração e como replicar

### 💻 Implementações por Linguagem

| Linguagem | Arquivo | Framework | Complexidade | Status |
|-----------|---------|-----------|--------------|--------|
| **Python** | [implementacao_python.md](./implementacao_python.md) | Flask / FastAPI | ⭐⭐ Baixa | ✅ Completo |
| **Ruby** | [implementacao_ruby.md](./implementacao_ruby.md) | Sinatra / Rails | ⭐⭐ Baixa | ✅ Completo |
| **Java** | [implementacao_java.md](./implementacao_java.md) | Spring Boot | ⭐⭐⭐ Média | ✅ Completo |
| **TypeScript** | [implementacao_typescript.md](./implementacao_typescript.md) | Express | ⭐⭐ Baixa | ✅ Completo |
| **PHP** | [implementacao_php.md](./implementacao_php.md) | Vanilla / Laravel | ⭐⭐ Baixa | ✅ Completo |
| **Go** | [implementacao_golang.md](./implementacao_golang.md) | Gin | ⭐⭐⭐ Média | ✅ Completo |
| **SQL** | [implementacao_sql.md](./implementacao_sql.md) | MySQL / PostgreSQL | ⭐⭐⭐ Média | ✅ Completo |

---

## 🎯 O Que Este Sistema Oferece

### ✅ Funcionalidades
- ✉️ **Envio de e-mails de verificação** (códigos de 6 dígitos)
- 🔑 **Recuperação de senha** (códigos temporários)
- ⏱️ **Expiração automática** (configurável, padrão 15 min)
- 📝 **Templates HTML** personalizáveis
- 🔒 **Rate limiting** (proteção contra spam)
- 📊 **Logs e auditoria**

### 💰 Vantagens
- **R$ 0,00 de custo** (sem serviços pagos tipo SendGrid, Mailgun)
- **Controle total** sobre envio e dados
- **Sem limites** de envio (exceto recursos do servidor)
- **Privacy completa** (dados não passam por terceiros)
- **Personalização total** (templates, lógica, storage)

### ⚠️ Considerações
- Precisa configurar DNS (MX, SPF, DKIM, DMARC)
- Pode cair em spam sem configuração adequada
- Requer gerenciamento de servidor próprio
- Precisa monitorar reputação do IP

---

## 🚀 Quick Start

### 1️⃣ Leia a Documentação Principal
```bash
# Entenda a arquitetura e como funciona
cat "como Funciona.md"
```

### 2️⃣ Escolha Sua Linguagem
```bash
# Exemplo: Python
cat implementacao_python.md

# Exemplo: TypeScript
cat implementacao_typescript.md
```

### 3️⃣ Configure o Postfix (uma vez)
```bash
# Instalar Postfix
sudo apt install postfix

# Configurar (seguir guia no "como Funciona.md")
sudo nano /etc/postfix/main.cf
```

### 4️⃣ Configure DNS (uma vez)
```txt
# Adicionar no seu provedor de DNS:
MX    @ 10 mail.seudominio.com
A     mail 212.85.10.203 (seu IP)
TXT   @ "v=spf1 a mx ip4:212.85.10.203 ~all"
```

### 5️⃣ Implemente na Sua API
```bash
# Copie o código da sua linguagem
# Configure as variáveis de ambiente
# Conecte ao Postfix (127.0.0.1:25)
# Teste!
```

---

## 📂 Estrutura de Cada Implementação

Todos os arquivos seguem o mesmo padrão:

1. **📦 Dependências** - Pacotes necessários
2. **📁 Estrutura de arquivos** - Organização do projeto
3. **🔧 Configuração** (.env ou config)
4. **📧 EmailService** - Classe/módulo principal
5. **🛣️ Rotas/API** - Endpoints (register, verify, reset)
6. **💾 Storage** - Armazenamento de códigos (memória/Redis)
7. **▶️ Como executar** - Comandos passo a passo
8. **🧪 Testes** - Exemplos curl
9. **🔧 Melhorias** - Redis, rate limiting, logs

---

## 🔥 Exemplo Real: dubDramas

### Configuração em Produção
```env
# dubDramas (https://dubdramas.asia)
SMTP_HOST=127.0.0.1
SMTP_PORT=25
SMTP_FROM="dubDramas <no-reply@dubdramas.asia>"
EMAIL_LOG_ONLY=0

# DNS configurado:
MX: 10 mail.dubdramas.asia
SPF: v=spf1 a mx ip4:212.85.10.203 ~all
```

### Resultados
- ✅ **Enviando e-mails desde 17/12/2024**
- ✅ **Taxa de entrega:** ~95%
- ✅ **Custo:** R$ 0,00
- ✅ **Volume:** Ilimitado
- ✅ **Controle:** 100%

---

## 🎓 Casos de Uso

### ✅ Quando Usar Este Sistema

1. **Startups/MVPs** - Zero custo inicial
2. **APIs pequenas/médias** - Controle total
3. **Projetos pessoais** - Aprendizado
4. **Ambientes internos** - Sem dados externos
5. **Compliance rígido** - Dados sensíveis

### ❌ Quando NÃO Usar

1. **Grandes volumes** (>100k emails/dia) - Use serviço especializado
2. **E-commerce crítico** - Priorize entregabilidade
3. **Sem expertise DevOps** - Requer manutenção
4. **Sem tempo para setup** - Serviços prontos são mais rápidos

---

## 🛠️ Stack Tecnológica

### Backend (Escolha uma)
- Python (Flask/FastAPI)
- Ruby (Sinatra/Rails)
- Java (Spring Boot)
- TypeScript (Express)
- PHP (Laravel/Vanilla)
- Go (Gin)

### SMTP Server
- **Postfix** (recomendado)
- Exim
- Sendmail

### Storage (Códigos)
- **Redis** (recomendado)
- Memória (dev/teste)
- MySQL/PostgreSQL

### DNS
- Cloudflare
- Route53
- Qualquer provedor com controle de records

---

## 📊 Comparação com Serviços Pagos

| Aspecto | Self-Hosted | SendGrid | Mailgun |
|---------|-------------|----------|---------|
| **Custo/mês** | R$ 0,00 | R$ 60+ | R$ 50+ |
| **Limite envios** | ∞ (recursos) | 100/dia (free) | 5k/mês (free) |
| **Setup** | Complexo | Simples | Simples |
| **Controle** | Total | Limitado | Limitado |
| **Privacy** | 100% | Compartilhada | Compartilhada |
| **Entregabilidade** | Variável | Alta | Alta |
| **Suporte** | DIY | Email/Chat | Email/Chat |

---

## 🔍 Troubleshooting

### E-mails caindo em spam?
```bash
# Verificar DNS
dig +short seudominio.com MX
dig +short seudominio.com TXT | grep spf

# Testar deliverability
https://www.mail-tester.com/
```

### Porta 25 bloqueada?
```bash
# Testar conectividade
telnet gmail-smtp-in.l.google.com 25

# Se bloqueado, usar relay (porta 587)
# Ou contatar provedor para desbloquear
```

### Logs do Postfix
```bash
# Ver últimas tentativas
tail -f /var/log/mail.log

# Buscar erros
grep "error" /var/log/mail.log

# Ver fila
mailq
```

---

## 📚 Recursos Adicionais

### Documentação Oficial
- [Postfix](http://www.postfix.org/documentation.html)
- [SPF Records](https://www.dmarcanalyzer.com/spf/)
- [DKIM Setup](https://www.dkim.org/)

### Ferramentas
- [MXToolbox](https://mxtoolbox.com/) - Testar DNS
- [Mail-Tester](https://www.mail-tester.com/) - Testar spam score
- [MailHog](https://github.com/mailhog/MailHog) - Teste local

### Comunidade
- Stack Overflow: tag `postfix`, `smtp`
- Reddit: r/selfhosted
- DigitalOcean Community

---

## ✅ Checklist de Implementação

### Servidor
- [ ] VPS com IP fixo
- [ ] Postfix instalado e configurado
- [ ] DNS configurado (MX, A, SPF)
- [ ] Porta 25 aberta (outbound)
- [ ] DKIM configurado (opcional)
- [ ] DMARC configurado (opcional)

### Backend
- [ ] Linguagem escolhida
- [ ] EmailService implementado
- [ ] Rotas de autenticação criadas
- [ ] Storage de códigos (Redis/DB)
- [ ] Rate limiting ativo
- [ ] Logs configurados
- [ ] Testes realizados

### Produção
- [ ] HTTPS configurado
- [ ] Variáveis de ambiente seguras
- [ ] Monitoramento ativo
- [ ] Backups configurados
- [ ] Documentação atualizada

---

## 📞 Suporte

### Problemas com este guia?
1. Revise a documentação principal: `como Funciona.md`
2. Verifique os logs do Postfix: `/var/log/mail.log`
3. Teste conectividade SMTP: `telnet localhost 25`
4. Verifique DNS: `dig seudominio.com MX`

### Melhorias
Este é um projeto em evolução. Sugestões:
- Adicionar mais linguagens
- Melhorar exemplos
- Incluir Docker
- Adicionar CI/CD

---

## 📄 Licença

Este projeto é open source e pode ser usado livremente em qualquer projeto pessoal ou comercial.

**Créditos:** Baseado no sistema de produção do dubDramas (dubdramas.asia)

---

## 🎯 Conclusão

Este sistema é perfeito para:
- ✅ Aprender sobre SMTP e e-mails
- ✅ Economizar em serviços pagos
- ✅ Ter controle total sobre dados
- ✅ Implementar em qualquer linguagem
- ✅ Escalar conforme necessidade

**Comece agora:** Escolha sua linguagem favorita e siga o guia!

---

**Última atualização:** 29/12/2024  
**Versão:** 1.0.0  
**Status:** ✅ Produção (testado no dubDramas)
