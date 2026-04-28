# Mail — SMTP relay архітектура

---

## Архітектура

```
Курсант відправляє email
        │
        ▼
Postfix курсанта (11.203.X.11)
relayhost = [11.203.0.11]:587
        │
        ▼
SMTP relay викладача (11.203.0.11)
        │
        ├─▶ Інший курсант в tsa243.lab (local delivery)
        └─▶ Зовнішній MX (якщо є інтернет)
```

---

## Конфігурація на SMTP relay викладача

### `/etc/postfix/main.cf` — ключові параметри

```
myhostname = mail.tsa243.lab
mydomain = tsa243.lab
mynetworks = 127.0.0.0/8, 11.203.0.0/16
inet_interfaces = all

# Приймати relay-запити від підмереж курсантів
relay_domains = tsa243.lab
```

---

## Конфігурація на сервері курсанта

### `/etc/postfix/main.cf` — ключові параметри

```
myhostname = mail.surname.tsa243.lab
mydomain = surname.tsa243.lab
myorigin = $mydomain

# Відправляти всю пошту через relay викладача
relayhost = [11.203.0.11]:587

# Аутентифікація на relay (якщо налаштована)
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_security_level = encrypt
```

### `/etc/postfix/sasl_passwd`

```
[11.203.0.11]:587  surname:password
```

```bash
sudo postmap /etc/postfix/sasl_passwd
sudo systemctl reload postfix
```

---

## Dovecot — IMAP для курсанта

Курсант читає пошту через IMAP на власному сервері `11.203.X.11`:

| Протокол | Порт | TLS |
|----------|------|-----|
| IMAP | 143 | STARTTLS |
| IMAPS | 993 | TLS |
| SMTP Submission | 587 | STARTTLS |

---

## Перевірка

```bash
# Відправити тестовий лист
echo "Test from surname" | mail -s "Hello" other@tsa243.lab

# Перевірити чергу
mailq

# Журнал relay
sudo journalctl -u postfix -f

# Перевірити доставку на relay викладача
sudo tail -f /var/log/mail.log
```

---

## Навчальний момент

SMTP relay — стандартна enterprise-практика.
Корпоративні мережі зазвичай забороняють прямі з'єднання на порт 25 (anti-spam).
Вся пошта іде через централізований smarthost з авторизацією і логуванням.
