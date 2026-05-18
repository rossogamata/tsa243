# Змістовний модуль 7. Адміністрування серверів та балансування навантаження
## ЗАНЯТТЯ 8 (Практичне) — Налаштування цифрових сертифікатів для захисту веб-сервера

> **Дисципліна:** Технології Системного Адміністрування | **Курс:** 2-й  
> **ОС:** Ubuntu Server 24.04 LTS | **Тип заняття:** Практичне  
> **Середовище:** Proxmox VE · підмережа курсанта `11.203.X.0/25`  
> **Час виконання:** ~90 хвилин  
> **Попередні заняття:** lesson6_6 (сертифікати OpenSSL), lesson7_4 (Apache), lesson7_7 (Nginx)

---

## Навчальні питання

1. [Налаштування цифрових сертифікатів для захисту веб-сервера Apache](#питання-1--apache2)
2. [Налаштування цифрових сертифікатів для захисту веб-сервера Nginx](#питання-2--nginx)

---

## Середовище заняття

| VM | Адреса | Роль |
|----|--------|------|
| Workstation | `11.203.X.20` | Apache2 — `surname.tsa243.lab` |
| Nginx VM | `11.203.X.12` | Nginx — `www.X.tsa243.lab` |

> Замінюйте `X` на номер вашого варіанта, `surname` — на ваше прізвище латинкою.

---

## Підготовка — Генерація сертифікатів

Перед роботою з веб-серверами підготуємо SSL-сертифікати. Виконайте кроки на **кожній VM**, де буде налаштовано HTTPS.

### Варіант А — Самопідписаний сертифікат (швидко)

Підходить для тестування. Браузер буде показувати попередження про недовірений сертифікат.

**На Workstation (11.203.X.20) — для Apache:**

```bash
sudo mkdir -p /etc/ssl/viit

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/viit/apache.key \
    -out    /etc/ssl/viit/apache.crt \
    -subj   "/C=UA/ST=Kyiv/O=VIIT/CN=surname.tsa243.lab" \
    -addext "subjectAltName=DNS:surname.tsa243.lab,DNS:www.surname.tsa243.lab,IP:11.203.X.20"

sudo chmod 600 /etc/ssl/viit/apache.key
sudo chmod 644 /etc/ssl/viit/apache.crt
```

**На Nginx VM (11.203.X.12) — для Nginx:**

```bash
sudo mkdir -p /etc/ssl/viit

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/viit/nginx.key \
    -out    /etc/ssl/viit/nginx.crt \
    -subj   "/C=UA/ST=Kyiv/O=VIIT/CN=11.203.X.12" \
    -addext "subjectAltName=IP:11.203.X.12,DNS:www.X.tsa243.lab"

sudo chmod 600 /etc/ssl/viit/nginx.key
sudo chmod 644 /etc/ssl/viit/nginx.crt
```

### Варіант Б — Сертифікат від CA кафедри (рекомендовано)

Якщо CA кафедри вже встановлено як довірений (lesson6_6), браузер не показуватиме попереджень.

```bash
# 1. Згенерувати приватний ключ та CSR
sudo openssl genrsa -out /etc/ssl/viit/server.key 2048
sudo chmod 600 /etc/ssl/viit/server.key

sudo openssl req -new \
    -key  /etc/ssl/viit/server.key \
    -out  /tmp/server.csr \
    -subj "/C=UA/ST=Kyiv/O=VIIT/CN=surname.tsa243.lab"

# 2. Передати server.csr викладачу для підпису
# 3. Отримати підписаний server.crt та помістити у /etc/ssl/viit/
```

### Перевірка сертифіката

```bash
# Переглянути деталі щойно створеного сертифіката
openssl x509 -in /etc/ssl/viit/apache.crt -noout -text | \
    grep -A1 -E "Subject:|Issuer:|Not Before|Not After|DNS:"
```

Очікуваний вивід:

```
Subject: C=UA, ST=Kyiv, O=VIIT, CN=surname.tsa243.lab
Issuer: C=UA, ST=Kyiv, O=VIIT, CN=surname.tsa243.lab
Not Before: Jan  1 00:00:00 2026 GMT
Not After : Jan  1 00:00:00 2027 GMT
    DNS:surname.tsa243.lab, DNS:www.surname.tsa243.lab
```

---

# Питання 1 — Apache2

> Виконується на **Workstation: 11.203.X.20**

```bash
ssh user@11.203.X.20
```

## Крок 1.1 — Увімкнення модулів SSL та заголовків

```bash
# Увімкнути модуль SSL
sudo a2enmod ssl

# Увімкнути модуль для заголовків безпеки (HSTS тощо)
sudo a2enmod headers

# Перевірити, що модулі увімкнено
apache2ctl -M | grep -E "ssl|headers"
```

Очікуваний вивід:

```
headers_module (shared)
ssl_module (shared)
```

```bash
# Перевірити, що Apache слухає порт 443
# (після перезапуску — зараз ще не слухає)
sudo grep -r "Listen" /etc/apache2/ports.conf
```

> Файл `ports.conf` вже містить `Listen 443` при увімкненому `mod_ssl`. Якщо рядка немає — додайте вручну.

## Крок 1.2 — Налаштування HTTPS Virtual Host

Створіть окремий конфіг для HTTPS-версії сайту:

```bash
sudo nano /etc/apache2/sites-available/surname.tsa243.lab-ssl.conf
```

```apache
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName   surname.tsa243.lab
    ServerAlias  www.surname.tsa243.lab
    ServerAdmin  surname@tsa243.lab
    DocumentRoot /var/www/main

    # ── TLS/SSL ──────────────────────────────────────────────
    SSLEngine on

    SSLCertificateFile    /etc/ssl/viit/apache.crt
    SSLCertificateKeyFile /etc/ssl/viit/apache.key

    # Протоколи: TLS 1.2 і 1.3, відключити застарілі
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1

    # Шифри — рекомендований набір
    SSLCipherSuite HIGH:!aNULL:!MD5:!3DES
    SSLHonorCipherOrder off

    # ── Заголовки безпеки ────────────────────────────────────
    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains"
    Header always set X-Content-Type-Options    "nosniff"
    Header always set X-Frame-Options           "SAMEORIGIN"

    # ── Логування ────────────────────────────────────────────
    ErrorLog  ${APACHE_LOG_DIR}/surname-ssl-error.log
    CustomLog ${APACHE_LOG_DIR}/surname-ssl-access.log combined

</VirtualHost>
</IfModule>
```

```bash
# Активувати HTTPS-сайт
sudo a2ensite surname.tsa243.lab-ssl.conf

# Перевірити синтаксис
sudo apache2ctl configtest
```

Очікуваний вивід:

```
Syntax OK
```

```bash
# Застосувати зміни (mod_ssl потребує повного restart, не reload)
sudo systemctl restart apache2

# Перевірити, що тепер слухає обидва порти
sudo ss -tulnp | grep apache2
```

Очікуваний вивід:

```
tcp LISTEN  0.0.0.0:80   users:(("apache2",...))
tcp LISTEN  0.0.0.0:443  users:(("apache2",...))
```

## Крок 1.3 — Перенаправлення HTTP → HTTPS

Відредагуйте HTTP-конфіг сайту, щоб усі запити перенаправлялися на HTTPS:

```bash
sudo nano /etc/apache2/sites-available/surname.tsa243.lab.conf
```

Замінити вміст `<VirtualHost *:80>` на:

```apache
<VirtualHost *:80>
    ServerName  surname.tsa243.lab
    ServerAlias www.surname.tsa243.lab

    # Постійний редирект усього трафіку на HTTPS
    Redirect permanent / https://surname.tsa243.lab/
</VirtualHost>
```

```bash
sudo apache2ctl configtest && sudo systemctl reload apache2
```

## Крок 1.4 — Перевірка Apache HTTPS

```bash
# Перевірити редирект з HTTP
curl -I http://11.203.X.20
```

Очікуваний вивід:

```
HTTP/1.1 301 Moved Permanently
Location: https://surname.tsa243.lab/
```

```bash
# Перевірити HTTPS (ігноруємо помилку самопідписаного сертифіката -k)
curl -Ik https://11.203.X.20
```

Очікуваний вивід:

```
HTTP/1.1 200 OK
Strict-Transport-Security: max-age=63072000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
```

```bash
# Переглянути деталі TLS-з'єднання
openssl s_client -connect 11.203.X.20:443 </dev/null 2>/dev/null | \
    openssl x509 -noout -subject -issuer -dates
```

```bash
# Перевірити протокол TLS
openssl s_client -connect 11.203.X.20:443 </dev/null 2>/dev/null | \
    grep -E "Protocol|Cipher"
```

Очікуваний вивід:

```
Protocol  : TLSv1.3
Cipher    : TLS_AES_256_GCM_SHA384
```

```bash
# Перевірити, що старий TLS 1.1 відхиляється
openssl s_client -tls1_1 -connect 11.203.X.20:443 </dev/null 2>&1 | \
    grep -E "alert|Error|no protocols"
```

Очікуваний вивід (помилка — це правильно, старий протокол заблоковано):

```
no protocols available
```

## Крок 1.5 — Перевірка в браузері

Відкрийте з робочої станції: `https://11.203.X.20`

- Браузер покаже попередження "Your connection is not private" (для самопідписаного сертифіката)
- Натисніть **Advanced → Proceed** (або Розширені → Продовжити)
- Переконайтеся, що відображається замок і `https://` в адресному рядку
- Натисніть на замок → переглянути деталі сертифіката

> Якщо CA кафедри встановлено в браузері — попередження не з'явиться.

---

# Питання 2 — Nginx

> Виконується на **Nginx VM: 11.203.X.12**

```bash
ssh user@11.203.X.12
```

## Крок 2.1 — Підготовка конфігурації HTTPS

Відредагуйте конфіг сайту (створений у lesson7_7):

```bash
sudo nano /etc/nginx/sites-available/www.conf
```

Повністю замінити вміст файлу:

```nginx
# ── Блок 1: HTTP → HTTPS редирект ────────────────────────────
server {
    listen 80;
    server_name www.X.tsa243.lab 11.203.X.12;

    # 301 Permanent redirect
    return 301 https://$host$request_uri;
}

# ── Блок 2: HTTPS сервер ──────────────────────────────────────
server {
    listen 443 ssl;
    server_name www.X.tsa243.lab 11.203.X.12;

    # ── Сертифікат та ключ ────────────────────────────────────
    ssl_certificate     /etc/ssl/viit/nginx.crt;
    ssl_certificate_key /etc/ssl/viit/nginx.key;

    # ── Протоколи та шифри ────────────────────────────────────
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5:!3DES;
    ssl_prefer_server_ciphers off;      # TLS 1.3 сам обирає найкращий шифр

    # ── Оптимізація сесій ─────────────────────────────────────
    ssl_session_cache   shared:SSL:10m; # Кеш TLS-сесій між worker-процесами
    ssl_session_timeout 1d;
    ssl_session_tickets off;            # Відключити session tickets (Forward Secrecy)

    # ── Заголовки безпеки ─────────────────────────────────────
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;
    add_header X-Content-Type-Options    "nosniff"    always;
    add_header X-Frame-Options           "SAMEORIGIN" always;
    add_header X-XSS-Protection          "1; mode=block" always;

    # ── Приховати версію Nginx ────────────────────────────────
    server_tokens off;

    # ── Контент ───────────────────────────────────────────────
    root  /var/www/www;
    index index.html;

    access_log /var/log/nginx/www-ssl.access.log;
    error_log  /var/log/nginx/www-ssl.error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

## Крок 2.2 — Перевірка та застосування

```bash
# Обов'язково перевірити синтаксис перед reload
sudo nginx -t
```

Очікуваний вивід:

```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

```bash
sudo systemctl reload nginx

# Перевірити, що nginx слухає обидва порти
sudo ss -tulnp | grep nginx
```

Очікуваний вивід:

```
tcp LISTEN  0.0.0.0:80   users:(("nginx",...))
tcp LISTEN  0.0.0.0:443  users:(("nginx",...))
```

## Крок 2.3 — Перевірка Nginx HTTPS

```bash
# Перевірити редирект
curl -I http://11.203.X.12
```

Очікуваний вивід:

```
HTTP/1.1 301 Moved Permanently
Location: https://11.203.X.12/
```

```bash
# Перевірити HTTPS та заголовки безпеки
curl -Ik https://11.203.X.12
```

Очікуваний вивід:

```
HTTP/2 200
server: nginx
strict-transport-security: max-age=63072000; includeSubDomains
x-content-type-options: nosniff
x-frame-options: SAMEORIGIN
x-xss-protection: 1; mode=block
```

> Зверніть увагу: заголовок `server:` показує лише `nginx` без версії — це ефект `server_tokens off`.

```bash
# Переглянути сертифікат та параметри TLS
openssl s_client -connect 11.203.X.12:443 </dev/null 2>/dev/null | \
    openssl x509 -noout -subject -issuer -dates

openssl s_client -connect 11.203.X.12:443 </dev/null 2>/dev/null | \
    grep -E "Protocol|Cipher"
```

```bash
# Переконатися, що TLS 1.1 заблоковано
openssl s_client -tls1_1 -connect 11.203.X.12:443 </dev/null 2>&1 | \
    grep -E "alert|Error|no protocols"
```

## Крок 2.4 — Перевірка відповідності ключа та сертифіката

Важливий діагностичний крок: переконатися, що ключ і сертифікат — пара.

```bash
# MD5 публічного ключа з сертифіката
openssl x509 -noout -modulus -in /etc/ssl/viit/nginx.crt | md5sum

# MD5 публічного ключа з приватного ключа
openssl rsa  -noout -modulus -in /etc/ssl/viit/nginx.key | md5sum
```

Обидва рядки MD5 **повинні збігатися**. Якщо різні — ключ і сертифікат не пара, Nginx не запуститься.

---

## Порівняння конфігурацій

| Параметр | Apache2 | Nginx |
|----------|---------|-------|
| Увімкнення SSL | `SSLEngine on` | `listen 443 ssl` |
| Сертифікат | `SSLCertificateFile /path/cert.crt` | `ssl_certificate /path/cert.crt` |
| Приватний ключ | `SSLCertificateKeyFile /path/cert.key` | `ssl_certificate_key /path/cert.key` |
| Протоколи | `SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1` | `ssl_protocols TLSv1.2 TLSv1.3` |
| Шифри | `SSLCipherSuite HIGH:!aNULL:!MD5` | `ssl_ciphers HIGH:!aNULL:!MD5` |
| HTTP → HTTPS | `Redirect permanent / https://...` | `return 301 https://...` |
| HSTS | `Header always set Strict-Transport-Security "..."` | `add_header Strict-Transport-Security "..." always` |
| Приховати версію | `ServerTokens Prod` у `apache2.conf` | `server_tokens off` |
| Перевірка конфігу | `apache2ctl configtest` | `nginx -t` |
| Застосування | `systemctl restart apache2` | `systemctl reload nginx` |

---

## Звіт про виконання роботи

Збережіть у звіті наступні вивід команд або скриншоти:

**Питання 1 — Apache2:**

| № | Команда | Що демонструє |
|---|---------|---------------|
| 1 | `sudo ss -tulnp \| grep apache2` | Apache слухає порти 80 і 443 |
| 2 | `curl -I http://11.203.X.20` | Редирект 301 на HTTPS |
| 3 | `curl -Ik https://11.203.X.20` | Відповідь 200 + заголовки безпеки |
| 4 | `openssl s_client -connect 11.203.X.20:443 </dev/null 2>/dev/null \| grep -E "Protocol\|Cipher"` | Протокол TLS 1.3, шифр |
| 5 | `openssl x509 -in /etc/ssl/viit/apache.crt -noout -subject -dates` | Деталі сертифіката |

**Питання 2 — Nginx:**

| № | Команда | Що демонструє |
|---|---------|---------------|
| 1 | `sudo ss -tulnp \| grep nginx` | Nginx слухає порти 80 і 443 |
| 2 | `curl -I http://11.203.X.12` | Редирект 301 на HTTPS |
| 3 | `curl -Ik https://11.203.X.12` | Відповідь 200 + заголовки безпеки |
| 4 | `openssl s_client -connect 11.203.X.12:443 </dev/null 2>/dev/null \| grep -E "Protocol\|Cipher"` | Протокол TLS 1.3, шифр |
| 5 | Два MD5 від `openssl x509/rsa -noout -modulus \| md5sum` | Ключ і сертифікат — пара |

---

## Типові помилки та вирішення

| Помилка | Причина | Вирішення |
|---------|---------|-----------|
| `apache2: bad user name www-data` | Apache не встановлено | `sudo apt install apache2` |
| `SSLCertificateFile: file '/etc/.../cert.crt' does not exist` | Невірний шлях у конфігу | Перевірити шлях: `ls /etc/ssl/viit/` |
| `nginx: [emerg] SSL_CTX_use_PrivateKey_file(...)` | Ключ не відповідає сертифікату | Перевірити MD5 обох файлів |
| `nginx: [emerg] cannot load certificate key` | Права доступу на ключ | `sudo chmod 600 /etc/ssl/viit/nginx.key` |
| `curl: (35) OpenSSL SSL_connect: Connection reset` | SSL не запущено або неправильний порт | `sudo ss -tulnp \| grep :443` |
| Браузер: "NET::ERR_CERT_AUTHORITY_INVALID" | Самопідписаний сертифікат | Нормально для тесту; встановити CA кафедри для усунення |
| Браузер: "ERR_TOO_MANY_REDIRECTS" | HTTP-блок перенаправляє на себе | Перевірити: `listen` у HTTPS-блоці має бути `443`, а не `80` |

---

## Структура проєкту на GitHub

```
lesson7_8/
└── README.md       ← Ця методичка
```

---

> Матеріал підготовлено для навчальних занять ВІТІ.  
> Дисципліна: Технології Системного Адміністрування | Курс 2-й | 2026
