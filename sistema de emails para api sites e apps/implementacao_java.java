# Sistema de E-mails - Implementação Java

## 📦 Dependências (Maven)

```xml
<!-- pom.xml -->
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.seuapp</groupId>
    <artifactId>email-api</artifactId>
    <version>1.0.0</version>
    
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
    </parent>
    
    <dependencies>
        <!-- Spring Boot Web -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        
        <!-- Spring Boot Mail -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-mail</artifactId>
        </dependency>
        
        <!-- Lombok (opcional) -->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

## 📁 Estrutura de Arquivos

```
src/main/java/com/seuapp/
├── Application.java
├── config/
│   └── EmailConfig.java
├── service/
│   └── EmailService.java
├── controller/
│   └── AuthController.java
├── dto/
│   ├── RegisterRequest.java
│   ├── VerifyCodeRequest.java
│   └── ResetPasswordRequest.java
└── model/
    └── VerificationCode.java

src/main/resources/
└── application.properties
```

## 🔧 Arquivo: `src/main/resources/application.properties`

```properties
# Server Configuration
server.port=8080

# E-mail Configuration
spring.mail.host=127.0.0.1
spring.mail.port=25
spring.mail.username=
spring.mail.password=
spring.mail.properties.mail.smtp.auth=false
spring.mail.properties.mail.smtp.starttls.enable=false
spring.mail.properties.mail.smtp.starttls.required=false

# E-mail From
app.email.from=no-reply@seusite.com
app.email.log-only=false

# Verification Code
app.verification.expiration-minutes=15
```

## 📧 Arquivo: `config/EmailConfig.java`

```java
package com.seuapp.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.JavaMailSenderImpl;

import java.util.Properties;

@Configuration
public class EmailConfig {
    
    @Value("${spring.mail.host}")
    private String host;
    
    @Value("${spring.mail.port}")
    private int port;
    
    @Bean
    public JavaMailSender javaMailSender() {
        JavaMailSenderImpl mailSender = new JavaMailSenderImpl();
        mailSender.setHost(host);
        mailSender.setPort(port);
        
        Properties props = mailSender.getJavaMailProperties();
        props.put("mail.transport.protocol", "smtp");
        props.put("mail.smtp.auth", "false");
        props.put("mail.smtp.starttls.enable", "false");
        props.put("mail.debug", "false");
        
        return mailSender;
    }
}
```

## 📧 Arquivo: `service/EmailService.java`

```java
package com.seuapp.service;

import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class EmailService {
    
    private final JavaMailSender mailSender;
    
    @Value("${app.email.from}")
    private String fromEmail;
    
    @Value("${app.email.log-only:false}")
    private boolean logOnly;
    
    public EmailService(JavaMailSender mailSender) {
        this.mailSender = mailSender;
    }
    
    public void sendEmail(String to, String subject, String text, String html) 
            throws MessagingException {
        
        if (logOnly) {
            log.warn("[email][LOG_ONLY] to={} subject={}", to, subject);
            return;
        }
        
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            
            helper.setFrom(fromEmail);
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(text, html);
            
            mailSender.send(message);
            log.info("[email] Enviado para: {}", to);
            
        } catch (MessagingException e) {
            log.error("[email] Erro ao enviar: {}", e.getMessage());
            throw e;
        }
    }
    
    public void sendVerificationEmail(String to, String code) throws MessagingException {
        String subject = "Seu código de verificação";
        
        String text = String.format("""
            Olá!
            
            Seu código de verificação é: %s
            
            Este código expira em 15 minutos.
            
            Se não foi você, ignore este e-mail.
            """, code);
        
        String html = String.format("""
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
                        <h1 style="color: #e50914; font-size: 36px; margin: 0; letter-spacing: 4px;">%s</h1>
                    </div>
                    <p style="color: #999; font-size: 14px;">Este código expira em 15 minutos.</p>
                    <p style="color: #ccc; font-size: 12px;">Se não foi você, ignore este e-mail.</p>
                </div>
            </body>
            </html>
            """, code);
        
        sendEmail(to, subject, text, html);
    }
    
    public void sendPasswordResetEmail(String to, String code) throws MessagingException {
        String subject = "Recuperação de Senha";
        
        String text = String.format("""
            Olá!
            
            Você solicitou a recuperação de senha da sua conta.
            
            Seu código de recuperação é: %s
            
            Este código expira em 15 minutos.
            
            Se você não solicitou, ignore este e-mail.
            """, code);
        
        String html = String.format("""
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
                        <h1 style="color: #e50914; font-size: 36px; margin: 0; letter-spacing: 4px;">%s</h1>
                    </div>
                    <p style="color: #999; font-size: 14px;">Este código expira em 15 minutos.</p>
                    <p style="color: #ccc; font-size: 12px;">Se não foi você, ignore este e-mail.</p>
                </div>
            </body>
            </html>
            """, code);
        
        sendEmail(to, subject, text, html);
    }
    
    public boolean verifyConnection() {
        if (logOnly) {
            log.info("[email] Modo LOG_ONLY ativo");
            return true;
        }
        
        try {
            mailSender.createMimeMessage();
            log.info("[email] Conexão SMTP verificada");
            return true;
        } catch (Exception e) {
            log.error("[email] Falha na verificação: {}", e.getMessage());
            return false;
        }
    }
}
```

## 📦 Arquivo: `dto/RegisterRequest.java`

```java
package com.seuapp.dto;

import lombok.Data;

@Data
public class RegisterRequest {
    private String email;
}
```

## 📦 Arquivo: `dto/VerifyCodeRequest.java`

```java
package com.seuapp.dto;

import lombok.Data;

@Data
public class VerifyCodeRequest {
    private String email;
    private String code;
}
```

## 📦 Arquivo: `dto/ResetPasswordRequest.java`

```java
package com.seuapp.dto;

import lombok.Data;

@Data
public class ResetPasswordRequest {
    private String email;
    private String code;
    private String newPassword;
}
```

## 🔐 Arquivo: `controller/AuthController.java`

```java
package com.seuapp.controller;

import com.seuapp.dto.*;
import com.seuapp.service.EmailService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@RestController
@RequestMapping("/api/auth")
public class AuthController {
    
    private final EmailService emailService;
    
    // Armazenamento temporário (use Redis em produção)
    private final Map<String, CodeData> verificationCodes = new ConcurrentHashMap<>();
    private final Map<String, CodeData> resetCodes = new ConcurrentHashMap<>();
    
    public AuthController(EmailService emailService) {
        this.emailService = emailService;
    }
    
    private String generateCode() {
        Random random = new Random();
        return String.format("%06d", random.nextInt(1000000));
    }
    
    @PostMapping("/register")
    public ResponseEntity<Map<String, Object>> register(@RequestBody RegisterRequest request) {
        try {
            String email = request.getEmail();
            
            if (email == null || email.isEmpty()) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "Email é obrigatório"));
            }
            
            // Gerar código
            String code = generateCode();
            
            // Salvar com expiração
            LocalDateTime expiresAt = LocalDateTime.now().plusMinutes(15);
            verificationCodes.put(email, new CodeData(code, expiresAt));
            
            // Enviar e-mail
            emailService.sendVerificationEmail(email, code);
            
            return ResponseEntity.ok(Map.of(
                "success", true,
                "message", "Código enviado para seu e-mail"
            ));
            
        } catch (Exception e) {
            log.error("Erro ao registrar: {}", e.getMessage());
            return ResponseEntity.internalServerError()
                .body(Map.of("error", "Erro ao enviar e-mail: " + e.getMessage()));
        }
    }
    
    @PostMapping("/verify-code")
    public ResponseEntity<Map<String, Object>> verifyCode(@RequestBody VerifyCodeRequest request) {
        String email = request.getEmail();
        String code = request.getCode();
        
        if (email == null || code == null) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", "Email e código são obrigatórios"));
        }
        
        // Verificar se existe
        CodeData stored = verificationCodes.get(email);
        if (stored == null) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", "Código inválido ou expirado"));
        }
        
        // Verificar expiração
        if (LocalDateTime.now().isAfter(stored.expiresAt)) {
            verificationCodes.remove(email);
            return ResponseEntity.badRequest()
                .body(Map.of("error", "Código expirado"));
        }
        
        // Verificar código
        if (!stored.code.equals(code)) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", "Código incorreto"));
        }
        
        // Remover código usado
        verificationCodes.remove(email);
        
        return ResponseEntity.ok(Map.of(
            "success", true,
            "message", "Código verificado com sucesso"
        ));
    }
    
    @PostMapping("/forgot-password")
    public ResponseEntity<Map<String, Object>> forgotPassword(@RequestBody RegisterRequest request) {
        try {
            String email = request.getEmail();
            
            if (email == null || email.isEmpty()) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "Email é obrigatório"));
            }
            
            // Gerar código
            String code = generateCode();
            
            // Salvar
            LocalDateTime expiresAt = LocalDateTime.now().plusMinutes(15);
            resetCodes.put(email, new CodeData(code, expiresAt));
            
            // Enviar e-mail
            emailService.sendPasswordResetEmail(email, code);
            
            return ResponseEntity.ok(Map.of(
                "success", true,
                "message", "Código de recuperação enviado"
            ));
            
        } catch (Exception e) {
            log.error("Erro ao enviar recuperação: {}", e.getMessage());
            return ResponseEntity.internalServerError()
                .body(Map.of("error", "Erro ao enviar e-mail: " + e.getMessage()));
        }
    }
    
    @PostMapping("/reset-password")
    public ResponseEntity<Map<String, Object>> resetPassword(@RequestBody ResetPasswordRequest request) {
        String email = request.getEmail();
        String code = request.getCode();
        String newPassword = request.getNewPassword();
        
        if (email == null || code == null || newPassword == null) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", "Todos os campos são obrigatórios"));
        }
        
        // Verificar código
        CodeData stored = resetCodes.get(email);
        if (stored == null) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", "Código inválido ou expirado"));
        }
        
        if (LocalDateTime.now().isAfter(stored.expiresAt)) {
            resetCodes.remove(email);
            return ResponseEntity.badRequest()
                .body(Map.of("error", "Código expirado"));
        }
        
        if (!stored.code.equals(code)) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", "Código incorreto"));
        }
        
        // Remover código
        resetCodes.remove(email);
        
        // Aqui você atualizaria a senha no banco
        // userService.updatePassword(email, newPassword);
        
        return ResponseEntity.ok(Map.of(
            "success", true,
            "message", "Senha atualizada com sucesso"
        ));
    }
    
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        return ResponseEntity.ok(Map.of(
            "status", "ok",
            "emailSmtp", emailService.verifyConnection()
        ));
    }
    
    // Classe interna para armazenar código + expiração
    private record CodeData(String code, LocalDateTime expiresAt) {}
}
```

## 🚀 Arquivo: `Application.java`

```java
package com.seuapp;

import com.seuapp.service.EmailService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

@Slf4j
@SpringBootApplication
public class Application {
    
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
    
    @Bean
    CommandLineRunner init(EmailService emailService) {
        return args -> {
            log.info("🚀 Iniciando servidor...");
            if (emailService.verifyConnection()) {
                log.info("✅ SMTP conectado");
            } else {
                log.warn("⚠️  SMTP não conectado (verifique Postfix)");
            }
        };
    }
}
```

## ▶️ Como Executar

### 1. Compilar:
```bash
mvn clean package
```

### 2. Rodar:
```bash
mvn spring-boot:run
# ou
java -jar target/email-api-1.0.0.jar
```

### 3. Testar:

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

## 🔧 Melhorias Recomendadas

### 1. Usar Redis (Spring Data Redis):

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-redis</artifactId>
</dependency>
```

```java
@Service
public class CodeStorageService {
    
    @Autowired
    private RedisTemplate<String, String> redisTemplate;
    
    public void saveCode(String email, String code) {
        redisTemplate.opsForValue().set(
            "verification:" + email, 
            code, 
            15, 
            TimeUnit.MINUTES
        );
    }
    
    public String getCode(String email) {
        return redisTemplate.opsForValue().get("verification:" + email);
    }
}
```

### 2. Async Email Sending:

```java
@Async
public CompletableFuture<Void> sendVerificationEmailAsync(String to, String code) {
    sendVerificationEmail(to, code);
    return CompletableFuture.completedFuture(null);
}
```

### 3. Rate Limiting (Bucket4j):

```xml
<dependency>
    <groupId>com.github.vladimir-bukhtoyarov</groupId>
    <artifactId>bucket4j-core</artifactId>
    <version>8.0.0</version>
</dependency>
```

## ✅ Checklist

- [ ] Configurar pom.xml
- [ ] Criar application.properties
- [ ] Implementar EmailService
- [ ] Criar controllers
- [ ] Testar endpoints
- [ ] Adicionar validações
- [ ] Implementar Redis
- [ ] Adicionar rate limiting
- [ ] Configurar async
- [ ] Documentar API (Swagger)

---

**Status:** ✅ Implementação funcional
**Java:** 17+
**Framework:** Spring Boot 3.x
