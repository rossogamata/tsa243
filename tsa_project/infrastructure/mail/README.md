# Mail — mail.tsa243.lab

**VM:** `mail.tsa243.lab` · `192.168.177.11`  
**Сервіси:** Postfix (SMTP :25, :587) · Dovecot (IMAP :143, IMAPS :993)  
**Домен:** `tsa243.lab`

---

## Що керує викладач

- Встановлення і базова конфігурація Postfix і Dovecot
- MX-запис у DNS: `tsa243.lab. IN MX 10 mail.tsa243.lab.`
- TLS-сертифікат для `mail.tsa243.lab`
- Загальна схема аутентифікації (PAM / virtual users)

## Що робить кожен курсант

1. Створює власну поштову скриньку:
   ```bash
   sudo useradd -m -s /sbin/nologin surname
   sudo passwd surname
   ```
2. Тестує відправку з CLI:
   ```bash
   echo "Test" | mail -s "Hello" surname@tsa243.lab
   ```
3. Підключається через IMAP (Thunderbird або mutt) і перевіряє отримання
4. Налаштовує пересилання або фільтри (`.forward`, sieve)

## Порти

| Порт | Протокол | Призначення |
|------|----------|-------------|
| 25 | SMTP | Прийом пошти між серверами |
| 587 | SMTP Submission | Відправка від клієнтів (з авторизацією) |
| 143 | IMAP | Читання пошти (без TLS) |
| 993 | IMAPS | Читання пошти (TLS) |
