# Sistema de E-mails - Implementação SQL

## 📋 Sobre Este Documento

SQL não é usado para criar a API de e-mails em si, mas sim para:
- Armazenar códigos de verificação no banco de dados
- Criar stored procedures para gerenciar códigos
- Implementar triggers para limpeza automática
- Fornecer queries úteis para integração

**Use este SQL junto com qualquer linguagem backend (Python, Java, PHP, etc)**

---

## 🗄️ Schema do Banco de Dados

### MySQL/MariaDB

```sql
-- Tabela para códigos de verificação
CREATE TABLE verification_codes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    code VARCHAR(6) NOT NULL,
    type ENUM('verification', 'reset') NOT NULL DEFAULT 'verification',
    expires_at DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    used_at DATETIME NULL,
    INDEX idx_email (email),
    INDEX idx_expires (expires_at),
    INDEX idx_type (type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabela de logs de e-mails (opcional, para auditoria)
CREATE TABLE email_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email_to VARCHAR(255) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,
    status ENUM('pending', 'sent', 'failed') NOT NULL DEFAULT 'pending',
    error_message TEXT NULL,
    sent_at DATETIME NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_email (email_to),
    INDEX idx_status (status),
    INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### PostgreSQL

```sql
-- Tabela para códigos de verificação
CREATE TABLE verification_codes (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    code VARCHAR(6) NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('verification', 'reset')),
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    used_at TIMESTAMP NULL
);

CREATE INDEX idx_verification_email ON verification_codes(email);
CREATE INDEX idx_verification_expires ON verification_codes(expires_at);
CREATE INDEX idx_verification_type ON verification_codes(type);

-- Tabela de logs de e-mails
CREATE TABLE email_logs (
    id SERIAL PRIMARY KEY,
    email_to VARCHAR(255) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'sent', 'failed')),
    error_message TEXT NULL,
    sent_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_email_logs_email ON email_logs(email_to);
CREATE INDEX idx_email_logs_status ON email_logs(status);
CREATE INDEX idx_email_logs_created ON email_logs(created_at);
```

---

## 🔧 Stored Procedures (MySQL/MariaDB)

### 1. Gerar e Salvar Código

```sql
DELIMITER $$

CREATE PROCEDURE sp_create_verification_code(
    IN p_email VARCHAR(255),
    IN p_type VARCHAR(20),
    IN p_expiration_minutes INT,
    OUT p_code VARCHAR(6)
)
BEGIN
    -- Gerar código de 6 dígitos
    SET p_code = LPAD(FLOOR(RAND() * 1000000), 6, '0');
    
    -- Deletar códigos antigos do mesmo email e tipo
    DELETE FROM verification_codes 
    WHERE email = p_email 
      AND type = p_type 
      AND used_at IS NULL;
    
    -- Inserir novo código
    INSERT INTO verification_codes (email, code, type, expires_at)
    VALUES (
        p_email,
        p_code,
        p_type,
        DATE_ADD(NOW(), INTERVAL p_expiration_minutes MINUTE)
    );
    
    -- Log
    INSERT INTO email_logs (email_to, subject, type, status)
    VALUES (p_email, CONCAT('Código ', p_type), p_type, 'pending');
END$$

DELIMITER ;
```

### 2. Verificar Código

```sql
DELIMITER $$

CREATE PROCEDURE sp_verify_code(
    IN p_email VARCHAR(255),
    IN p_code VARCHAR(6),
    IN p_type VARCHAR(20),
    OUT p_valid BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_expires_at DATETIME;
    DECLARE v_used_at DATETIME;
    
    -- Buscar código
    SELECT expires_at, used_at INTO v_expires_at, v_used_at
    FROM verification_codes
    WHERE email = p_email
      AND code = p_code
      AND type = p_type
    ORDER BY created_at DESC
    LIMIT 1;
    
    -- Verificar se existe
    IF v_expires_at IS NULL THEN
        SET p_valid = FALSE;
        SET p_message = 'Código não encontrado';
        
    -- Verificar se já foi usado
    ELSEIF v_used_at IS NOT NULL THEN
        SET p_valid = FALSE;
        SET p_message = 'Código já foi usado';
        
    -- Verificar se expirou
    ELSEIF NOW() > v_expires_at THEN
        SET p_valid = FALSE;
        SET p_message = 'Código expirado';
        
    -- Código válido
    ELSE
        SET p_valid = TRUE;
        SET p_message = 'Código válido';
        
        -- Marcar como usado
        UPDATE verification_codes
        SET used_at = NOW()
        WHERE email = p_email
          AND code = p_code
          AND type = p_type;
    END IF;
END$$

DELIMITER ;
```

### 3. Limpar Códigos Expirados

```sql
DELIMITER $$

CREATE PROCEDURE sp_clean_expired_codes()
BEGIN
    DELETE FROM verification_codes
    WHERE expires_at < NOW()
       OR (used_at IS NOT NULL AND used_at < DATE_SUB(NOW(), INTERVAL 1 DAY));
    
    SELECT ROW_COUNT() AS deleted_count;
END$$

DELIMITER ;
```

---

## 🔧 Stored Procedures (PostgreSQL)

### 1. Gerar e Salvar Código

```sql
CREATE OR REPLACE FUNCTION fn_create_verification_code(
    p_email VARCHAR(255),
    p_type VARCHAR(20),
    p_expiration_minutes INT
) RETURNS VARCHAR(6) AS $$
DECLARE
    v_code VARCHAR(6);
BEGIN
    -- Gerar código de 6 dígitos
    v_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
    
    -- Deletar códigos antigos
    DELETE FROM verification_codes 
    WHERE email = p_email 
      AND type = p_type 
      AND used_at IS NULL;
    
    -- Inserir novo código
    INSERT INTO verification_codes (email, code, type, expires_at)
    VALUES (
        p_email,
        v_code,
        p_type,
        NOW() + (p_expiration_minutes || ' minutes')::INTERVAL
    );
    
    -- Log
    INSERT INTO email_logs (email_to, subject, type, status)
    VALUES (p_email, 'Código ' || p_type, p_type, 'pending');
    
    RETURN v_code;
END;
$$ LANGUAGE plpgsql;
```

### 2. Verificar Código

```sql
CREATE OR REPLACE FUNCTION fn_verify_code(
    p_email VARCHAR(255),
    p_code VARCHAR(6),
    p_type VARCHAR(20)
) RETURNS TABLE(valid BOOLEAN, message TEXT) AS $$
DECLARE
    v_expires_at TIMESTAMP;
    v_used_at TIMESTAMP;
BEGIN
    -- Buscar código
    SELECT vc.expires_at, vc.used_at INTO v_expires_at, v_used_at
    FROM verification_codes vc
    WHERE vc.email = p_email
      AND vc.code = p_code
      AND vc.type = p_type
    ORDER BY vc.created_at DESC
    LIMIT 1;
    
    -- Verificar
    IF v_expires_at IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Código não encontrado'::TEXT;
        
    ELSIF v_used_at IS NOT NULL THEN
        RETURN QUERY SELECT FALSE, 'Código já foi usado'::TEXT;
        
    ELSIF NOW() > v_expires_at THEN
        RETURN QUERY SELECT FALSE, 'Código expirado'::TEXT;
        
    ELSE
        -- Marcar como usado
        UPDATE verification_codes
        SET used_at = NOW()
        WHERE email = p_email
          AND code = p_code
          AND type = p_type;
        
        RETURN QUERY SELECT TRUE, 'Código válido'::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;
```

---

## 🎯 Triggers para Limpeza Automática

### MySQL Event (executa a cada 1 hora)

```sql
-- Habilitar eventos
SET GLOBAL event_scheduler = ON;

-- Criar evento
CREATE EVENT IF NOT EXISTS evt_clean_expired_codes
ON SCHEDULE EVERY 1 HOUR
DO
    CALL sp_clean_expired_codes();
```

### PostgreSQL (usando pg_cron extension)

```sql
-- Instalar extensão (uma vez)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Agendar limpeza a cada 1 hora
SELECT cron.schedule('clean-expired-codes', '0 * * * *', $$
    DELETE FROM verification_codes
    WHERE expires_at < NOW()
       OR (used_at IS NOT NULL AND used_at < NOW() - INTERVAL '1 day');
$$);
```

---

## 📝 Queries Úteis

### 1. Criar Código de Verificação

```sql
-- MySQL
CALL sp_create_verification_code(
    'usuario@email.com',
    'verification',
    15,
    @code
);
SELECT @code AS codigo_gerado;

-- PostgreSQL
SELECT fn_create_verification_code(
    'usuario@email.com',
    'verification',
    15
) AS codigo_gerado;
```

### 2. Verificar Código

```sql
-- MySQL
CALL sp_verify_code(
    'usuario@email.com',
    '123456',
    'verification',
    @valid,
    @message
);
SELECT @valid AS valido, @message AS mensagem;

-- PostgreSQL
SELECT * FROM fn_verify_code(
    'usuario@email.com',
    '123456',
    'verification'
);
```

### 3. Listar Códigos Ativos

```sql
SELECT 
    email,
    code,
    type,
    expires_at,
    created_at,
    TIMESTAMPDIFF(MINUTE, NOW(), expires_at) AS minutes_remaining -- MySQL
    -- EXTRACT(EPOCH FROM (expires_at - NOW()))/60 AS minutes_remaining -- PostgreSQL
FROM verification_codes
WHERE expires_at > NOW()
  AND used_at IS NULL
ORDER BY created_at DESC;
```

### 4. Estatísticas de E-mails

```sql
SELECT 
    DATE(created_at) AS data,
    type,
    status,
    COUNT(*) AS total
FROM email_logs
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) -- MySQL
-- WHERE created_at >= NOW() - INTERVAL '7 days' -- PostgreSQL
GROUP BY DATE(created_at), type, status
ORDER BY data DESC;
```

### 5. Códigos Expirados (para debug)

```sql
SELECT 
    email,
    code,
    type,
    expires_at,
    TIMESTAMPDIFF(MINUTE, expires_at, NOW()) AS expired_minutes_ago -- MySQL
    -- EXTRACT(EPOCH FROM (NOW() - expires_at))/60 AS expired_minutes_ago -- PostgreSQL
FROM verification_codes
WHERE expires_at < NOW()
  AND used_at IS NULL
ORDER BY expires_at DESC
LIMIT 20;
```

---

## 🔗 Integração com Backend

### Python (usando stored procedures)

```python
import mysql.connector

def create_verification_code(email: str, expiration_minutes: int = 15) -> str:
    conn = mysql.connector.connect(...)
    cursor = conn.cursor()
    
    cursor.callproc('sp_create_verification_code', [
        email,
        'verification',
        expiration_minutes,
        0  # OUT parameter
    ])
    
    # Pegar resultado
    for result in cursor.stored_results():
        code = result.fetchone()[0]
    
    conn.commit()
    cursor.close()
    conn.close()
    
    return code

def verify_code(email: str, code: str) -> tuple[bool, str]:
    conn = mysql.connector.connect(...)
    cursor = conn.cursor()
    
    cursor.callproc('sp_verify_code', [
        email,
        code,
        'verification',
        0,  # OUT valid
        ''  # OUT message
    ])
    
    cursor.execute("SELECT @_sp_verify_code_3, @_sp_verify_code_4")
    valid, message = cursor.fetchone()
    
    conn.commit()
    cursor.close()
    conn.close()
    
    return (bool(valid), message)
```

### PHP (usando stored procedures)

```php
<?php
function createVerificationCode($pdo, $email, $expirationMinutes = 15) {
    $stmt = $pdo->prepare("CALL sp_create_verification_code(?, 'verification', ?, @code)");
    $stmt->execute([$email, $expirationMinutes]);
    
    $result = $pdo->query("SELECT @code AS code")->fetch();
    return $result['code'];
}

function verifyCode($pdo, $email, $code) {
    $stmt = $pdo->prepare("CALL sp_verify_code(?, ?, 'verification', @valid, @message)");
    $stmt->execute([$email, $code]);
    
    $result = $pdo->query("SELECT @valid AS valid, @message AS message")->fetch();
    return [
        'valid' => (bool)$result['valid'],
        'message' => $result['message']
    ];
}
?>
```

### Java (usando CallableStatement)

```java
public String createVerificationCode(Connection conn, String email) throws SQLException {
    CallableStatement stmt = conn.prepareCall("{CALL sp_create_verification_code(?, 'verification', 15, ?)}");
    stmt.setString(1, email);
    stmt.registerOutParameter(2, Types.VARCHAR);
    stmt.execute();
    
    return stmt.getString(2);
}

public boolean verifyCode(Connection conn, String email, String code) throws SQLException {
    CallableStatement stmt = conn.prepareCall("{CALL sp_verify_code(?, ?, 'verification', ?, ?)}");
    stmt.setString(1, email);
    stmt.setString(2, code);
    stmt.registerOutParameter(3, Types.BOOLEAN);
    stmt.registerOutParameter(4, Types.VARCHAR);
    stmt.execute();
    
    return stmt.getBoolean(3);
}
```

---

## 🔐 Segurança

### 1. Rate Limiting no Banco

```sql
-- Tabela para controle de rate limiting
CREATE TABLE rate_limits (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    action VARCHAR(50) NOT NULL,
    attempt_count INT DEFAULT 1,
    window_start DATETIME NOT NULL,
    blocked_until DATETIME NULL,
    INDEX idx_email_action (email, action)
);

-- Procedure para verificar rate limit
DELIMITER $$

CREATE PROCEDURE sp_check_rate_limit(
    IN p_email VARCHAR(255),
    IN p_action VARCHAR(50),
    IN p_max_attempts INT,
    IN p_window_minutes INT,
    OUT p_allowed BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_attempt_count INT;
    DECLARE v_window_start DATETIME;
    DECLARE v_blocked_until DATETIME;
    
    -- Buscar registro
    SELECT attempt_count, window_start, blocked_until 
    INTO v_attempt_count, v_window_start, v_blocked_until
    FROM rate_limits
    WHERE email = p_email AND action = p_action
    LIMIT 1;
    
    -- Se não existe, criar
    IF v_attempt_count IS NULL THEN
        INSERT INTO rate_limits (email, action, window_start)
        VALUES (p_email, p_action, NOW());
        SET p_allowed = TRUE;
        SET p_message = 'Permitido';
        
    -- Se está bloqueado
    ELSEIF v_blocked_until IS NOT NULL AND NOW() < v_blocked_until THEN
        SET p_allowed = FALSE;
        SET p_message = CONCAT('Bloqueado até ', v_blocked_until);
        
    -- Se janela expirou, resetar
    ELSEIF NOW() > DATE_ADD(v_window_start, INTERVAL p_window_minutes MINUTE) THEN
        UPDATE rate_limits
        SET attempt_count = 1, window_start = NOW(), blocked_until = NULL
        WHERE email = p_email AND action = p_action;
        SET p_allowed = TRUE;
        SET p_message = 'Permitido (janela resetada)';
        
    -- Se atingiu limite, bloquear
    ELSEIF v_attempt_count >= p_max_attempts THEN
        UPDATE rate_limits
        SET blocked_until = DATE_ADD(NOW(), INTERVAL 30 MINUTE)
        WHERE email = p_email AND action = p_action;
        SET p_allowed = FALSE;
        SET p_message = 'Limite excedido, bloqueado por 30 minutos';
        
    -- Incrementar contador
    ELSE
        UPDATE rate_limits
        SET attempt_count = attempt_count + 1
        WHERE email = p_email AND action = p_action;
        SET p_allowed = TRUE;
        SET p_message = CONCAT('Permitido (', v_attempt_count + 1, '/', p_max_attempts, ')');
    END IF;
END$$

DELIMITER ;
```

---

## ✅ Checklist de Implementação

- [ ] Criar tabela `verification_codes`
- [ ] Criar tabela `email_logs` (opcional)
- [ ] Implementar stored procedure para criar código
- [ ] Implementar stored procedure para verificar código
- [ ] Implementar limpeza automática (event/cron)
- [ ] Adicionar rate limiting (opcional)
- [ ] Criar índices para performance
- [ ] Testar todas as procedures
- [ ] Integrar com backend
- [ ] Documentar queries

---

**Status:** ✅ Implementação funcional
**Banco:** MySQL 8+, PostgreSQL 13+, MariaDB 10.5+
