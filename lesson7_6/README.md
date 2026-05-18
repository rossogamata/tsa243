# Змістовний модуль 7. Адміністрування серверів та балансування навантаження
## ЗАНЯТТЯ 6 (Групове) — Конфігурація веб-сервера Nginx

> **Дисципліна:** Технології Системного Адміністрування | **Курс:** 2-й  
> **ОС:** Ubuntu Server 24.04 LTS | **Тип заняття:** Групове  
> **Середовище:** Proxmox VE · підмережа курсанта `11.203.X.0/25`  
> **Час виконання:** ~90 хвилин  
> **Попереднє заняття:** Заняття 4 — Apache (lesson7_4), Заняття 5 — Сертифікати (lesson6_6)

---

## Навчальні питання

1. [Конфігураційні файли Nginx](#1-конфігураційні-файли-nginx)
   - [1.1 Структура директорії /etc/nginx/](#11-структура-директорії-etcnginx)
   - [1.2 Синтаксис конфігурації: контексти та директиви](#12-синтаксис-конфігурації-контексти-та-директиви)
   - [1.3 Файл nginx.conf — детальний огляд](#13-файл-nginxconf--детальний-огляд)
2. [Базова конфігурація Nginx, налаштування серверних блоків](#2-базова-конфігурація-nginx-налаштування-серверних-блоків)
   - [2.1 Встановлення та перший запуск](#21-встановлення-та-перший-запуск)
   - [2.2 Серверний блок (Virtual Host)](#22-серверний-блок-virtual-host)
   - [2.3 Директива location](#23-директива-location)
   - [2.4 Кілька Virtual Hosts на одному сервері](#24-кілька-virtual-hosts-на-одному-сервері)
   - [2.5 Nginx як зворотний проксі](#25-nginx-як-зворотний-проксі)
3. [Налаштування безпечного з'єднання у Nginx та Apache2](#3-налаштування-безпечного-зєднання-у-nginx-та-apache2)
   - [3.1 Підготовка TLS-сертифіката](#31-підготовка-tls-сертифіката)
   - [3.2 HTTPS у Nginx](#32-https-у-nginx)
   - [3.3 Перенаправлення HTTP → HTTPS](#33-перенаправлення-http--https)
   - [3.4 HTTPS у Apache2](#34-https-у-apache2)
   - [3.5 Порівняння налаштування SSL: Nginx vs Apache2](#35-порівняння-налаштування-ssl-nginx-vs-apache2)
4. [Практична частина](#4-практична-частина)
5. [Перевірка роботи](#5-перевірка-роботи)
6. [Завдання на самопідготовку](#6-завдання-на-самопідготовку)
7. [Корисні команди](#7-корисні-команди)

---

## Топологія стенду

```
                        Інтернет
                           │
                    11.203.0.1 (шлюз)
                           │
              ┌────────────┴────────────┐
              │    Підмережа викладача  │
              │     11.203.0.0/25       │
              │  .12 — Nginx (проксі)  │
              └────────────┬────────────┘
                           │  підмережі курсантів
          ┌────────────────┼────────────────┐
          │                │                │
  11.203.1.0/25    11.203.2.0/25   11.203.X.0/25
  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
  │ .10 DNS      │  │ .10 DNS      │  │ .10 DNS      │
  │ .11 SMTP     │  │ .11 SMTP     │  │ .11 SMTP     │
  │ .12 Nginx ◄──│  │ .12 Nginx ◄──│  │ .12 Nginx ◄──┤ ← ваш сервер
  │ .13 HAProxy  │  │ .13 HAProxy  │  │ .13 HAProxy  │
  │ .20 Work     │  │ .20 Work     │  │ .20 Work     │
  └──────────────┘  └──────────────┘  └──────────────┘
```

**Адреса вашого Nginx:** `11.203.X.12` (X = номер вашого варіанта)

---

## 1. Конфігураційні файли Nginx

### 1.1 Структура директорії /etc/nginx/

```
/etc/nginx/
├── nginx.conf                  ← Головний конфігураційний файл
├── mime.types                  ← Відповідність розширень та MIME-типів
├── conf.d/                     ← Додаткові конфіги (підключаються автоматично)
│   └── *.conf
├── sites-available/            ← Всі описані віртуальні хости
│   ├── default                 ← Типовий хост (встановлюється разом з nginx)
│   └── mysite.conf
└── sites-enabled/              ← Тільки активні хости (симлінки на sites-available)
    └── default -> ../sites-available/default
```

> **Принцип `sites-available` / `sites-enabled`** — той самий, що і в Apache. В `sites-available` зберігаються всі конфіги, в `sites-enabled` — лише симлінки на активні. Активація: `ln -s`, деактивація: видалення симлінка. Сам файл у `sites-available` не чіпаємо.

**Важливі одиночні файли:**

| Файл / Директорія | Призначення |
|-------------------|-------------|
| `/etc/nginx/nginx.conf` | Головний конфіг: глобальні параметри, підключення інших файлів |
| `/etc/nginx/mime.types` | Визначає Content-Type за розширенням файлу |
| `/etc/nginx/sites-available/` | Конфіги всіх сайтів (активних і ні) |
| `/etc/nginx/sites-enabled/` | Симлінки на активні сайти |
| `/var/www/html/` | Кореневий каталог веб-сайту за замовчуванням |
| `/var/log/nginx/access.log` | Журнал усіх HTTP-запитів |
| `/var/log/nginx/error.log` | Журнал помилок |
| `/run/nginx.pid` | PID головного процесу Nginx |

### 1.2 Синтаксис конфігурації: контексти та директиви

Конфігурація Nginx — це ієрархія **контекстів** (блоків у фігурних дужках) і **директив** (рядків із крапкою з комою):

```nginx
# Директива — одна інструкція з аргументами
worker_processes auto;

# Контекст — блок із директивами всередині
events {
    worker_connections 1024;
}

http {
    # Директиви http-контексту
    gzip on;

    server {
        # Директиви server-контексту (один Virtual Host)
        listen 80;
        server_name example.com;

        location / {
            # Директиви location-контексту
            root /var/www/html;
        }
    }
}
```

**Ієрархія контекстів:**

```
main (глобальний)
└── events           ← параметри мережевих з'єднань
└── http             ← весь HTTP-трафік
    └── server       ← один Virtual Host
        └── location ← обробка конкретного URI
```

> **Успадкування:** більшість директив успадковуються від батьківського контексту. Якщо `gzip on;` задано у `http {}` — воно діє для всіх `server {}` і `location {}`, якщо не перевизначено.

### 1.3 Файл nginx.conf — детальний огляд

```nginx
# ── MAIN контекст ──────────────────────────────────────────────
user www-data;                  # Від якого користувача запускаються worker-процеси
worker_processes auto;          # Кількість worker-процесів (auto = кількість CPU)
pid /run/nginx.pid;             # Файл з PID головного процесу
include /etc/nginx/modules-enabled/*.conf;  # Динамічні модулі

# ── EVENTS контекст ────────────────────────────────────────────
events {
    worker_connections 768;     # Максимум з'єднань на один worker
    # multi_accept on;          # Приймати кілька з'єднань за один раз
}

# ── HTTP контекст ──────────────────────────────────────────────
http {
    # Базові налаштування
    sendfile on;                # Передача файлів через ядро (швидше)
    tcp_nopush on;              # Оптимізація: надсилати заголовки разом з даними
    types_hash_max_size 2048;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Логування
    access_log /var/log/nginx/access.log;
    error_log  /var/log/nginx/error.log;

    # Стиснення
    gzip on;

    # Підключення конфігів з sites-enabled/
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
```

---

## 2. Базова конфігурація Nginx, налаштування серверних блоків

### 2.1 Встановлення та перший запуск

```bash
# Встановити Nginx
sudo apt update && sudo apt install -y nginx

# Перевірити статус
sudo systemctl status nginx

# Увімкнути автозапуск
sudo systemctl enable nginx

# Переглянути тестову сторінку у браузері або curl
curl http://localhost
```

**Перевірити та застосувати конфігурацію:**

```bash
# Перевірка синтаксису (перед кожним перезапуском!)
sudo nginx -t

# Перезавантажити без зупинки (graceful reload)
sudo systemctl reload nginx

# Повний перезапуск (уникайте без потреби — розриває активні з'єднання)
sudo systemctl restart nginx
```

> `nginx -t` — обов'язкова команда перед `reload`. Якщо в конфігу є помилка, `reload` не застосує зміни, але і не зупинить Nginx. Якщо помилка виявлена після `restart` — сервер не запуститься.

### 2.2 Серверний блок (Virtual Host)

Серверний блок — аналог `<VirtualHost>` в Apache. Один Nginx може обслуговувати кілька сайтів одночасно.

**Мінімальний конфіг для статичного сайту:**

```bash
sudo nano /etc/nginx/sites-available/mysite.conf
```

```nginx
server {
    listen 80;                          # Слухати порт 80 (HTTP)
    server_name mysite.tsa243.lab;      # Доменне ім'я (або IP)

    root /var/www/mysite;               # Кореневий каталог файлів
    index index.html index.htm;         # Файли-індекси (за порядком)

    access_log /var/log/nginx/mysite.access.log;
    error_log  /var/log/nginx/mysite.error.log;

    location / {
        try_files $uri $uri/ =404;      # Шукати файл → каталог → повернути 404
    }
}
```

**Створити каталог і сторінку:**

```bash
sudo mkdir -p /var/www/mysite
sudo nano /var/www/mysite/index.html
```

```html
<!DOCTYPE html>
<html lang="uk">
<head><meta charset="UTF-8"><title>Мій сайт</title></head>
<body>
  <h1>Курсант X — Nginx сервер</h1>
  <p>Адреса: 11.203.X.12</p>
</body>
</html>
```

**Активувати сайт:**

```bash
# Створити симлінк (активувати)
sudo ln -s /etc/nginx/sites-available/mysite.conf /etc/nginx/sites-enabled/

# Перевірити синтаксис
sudo nginx -t

# Застосувати
sudo systemctl reload nginx
```

**Деактивувати сайт (без видалення конфігу):**

```bash
sudo rm /etc/nginx/sites-enabled/mysite.conf
sudo systemctl reload nginx
```

### 2.3 Директива location

`location` визначає, як обробляти запити до конкретного URI.

**Типи співставлення (від вищого до нижчого пріоритету):**

| Синтаксис | Тип | Приклад |
|-----------|-----|---------|
| `location = /path` | Точне співставлення | `location = /favicon.ico` |
| `location ^~ /path` | Префікс (пріоритетний) | `location ^~ /static/` |
| `location ~ regex` | Регулярний вираз (чутливий до регістру) | `location ~ \.php$` |
| `location ~* regex` | Регулярний вираз (нечутливий) | `location ~* \.(jpg\|png)$` |
| `location /path` | Звичайний префікс | `location /api/` |

**Приклади:**

```nginx
server {
    listen 80;
    server_name example.com;
    root /var/www/html;

    # Точне співставлення — найвищий пріоритет
    location = / {
        return 200 "Головна сторінка\n";
    }

    # Статичні файли — кеш на 30 днів
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # Прихований від зовнішнього доступу каталог
    location /private/ {
        deny all;
    }

    # Стандартна обробка
    location / {
        try_files $uri $uri/ =404;
    }
}
```

**Змінні Nginx у location:**

| Змінна | Значення |
|--------|----------|
| `$uri` | Поточний URI (без query string) |
| `$args` | Query string |
| `$host` | Заголовок Host |
| `$remote_addr` | IP клієнта |
| `$request_method` | GET, POST, ... |
| `$server_port` | Порт сервера |

### 2.4 Кілька Virtual Hosts на одному сервері

Nginx вибирає серверний блок за значенням заголовка `Host:`.

```
Клієнт: GET / HTTP/1.1
         Host: site1.tsa243.lab
         ↓
Nginx:  порівнює з server_name всіх блоків → обирає відповідний
```

```bash
# Два сайти — два файли конфігурації
sudo nano /etc/nginx/sites-available/site1.conf
sudo nano /etc/nginx/sites-available/site2.conf
```

```nginx
# /etc/nginx/sites-available/site1.conf
server {
    listen 80;
    server_name site1.tsa243.lab;
    root /var/www/site1;
    index index.html;
    location / { try_files $uri $uri/ =404; }
}
```

```nginx
# /etc/nginx/sites-available/site2.conf
server {
    listen 80;
    server_name site2.tsa243.lab;
    root /var/www/site2;
    index index.html;
    location / { try_files $uri $uri/ =404; }
}
```

```bash
# Активувати обидва
sudo ln -s /etc/nginx/sites-available/site1.conf /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/site2.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

> Якщо жоден `server_name` не збігається — Nginx використовує **перший** серверний блок у `sites-enabled/` або блок з `default_server`.

**Позначення блоку за замовчуванням:**

```nginx
server {
    listen 80 default_server;   # ← цей блок обробляє невідомі хости
    server_name _;              # _ означає "будь-яке ім'я"
    return 444;                 # Закрити з'єднання без відповіді
}
```

### 2.5 Nginx як зворотний проксі

Зворотний проксі — ключова роль Nginx у нашій інфраструктурі. Nginx приймає запит від клієнта і передає його до backend-сервера.

```
Клієнт → Nginx (11.203.0.12) → Nginx курсанта (11.203.X.12) → HAProxy (.13) → Backend (.30+)
```

```nginx
server {
    listen 80;
    server_name X.tsa243.lab;       # Домен курсанта

    location / {
        proxy_pass http://11.203.X.13;          # Передати HAProxy
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 10s;
        proxy_read_timeout    30s;
    }
}
```

> **`proxy_set_header`** — важливо передавати реальну IP-адресу клієнта і протокол. Без цього backend буде бачити IP адресу Nginx, а не справжнього клієнта.

---

## 3. Налаштування безпечного з'єднання у Nginx та Apache2

### 3.1 Підготовка TLS-сертифіката

Для HTTPS потрібна пара: **приватний ключ** + **сертифікат**. У навчальному середовищі використовуємо сертифікат, підписаний нашим CA (з lesson6_5/lesson6_6).

**Варіант А — Самопідписаний сертифікат (швидко, для тестів):**

```bash
# Створити директорію для сертифікатів
sudo mkdir -p /etc/nginx/ssl

# Генерація ключа та самопідписаного сертифіката одною командою
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx-selfsigned.key \
    -out    /etc/nginx/ssl/nginx-selfsigned.crt \
    -subj "/C=UA/ST=Kyiv/O=VIIT/CN=11.203.X.12" \
    -addext "subjectAltName=IP:11.203.X.12,DNS:X.tsa243.lab"

# Встановити правильні права
sudo chmod 600 /etc/nginx/ssl/nginx-selfsigned.key
sudo chmod 644 /etc/nginx/ssl/nginx-selfsigned.crt
```

**Варіант Б — Сертифікат, підписаний CA кафедри (рекомендовано):**

```bash
# Використати CA та скрипти з lesson6_6
# (якщо CA кафедри вже встановлено як довірений у браузері)

# Генерація ключа та CSR
sudo openssl genrsa -out /etc/nginx/ssl/server.key 2048
sudo openssl req -new \
    -key /etc/nginx/ssl/server.key \
    -out /etc/nginx/ssl/server.csr \
    -subj "/C=UA/ST=Kyiv/O=VIIT/CN=X.tsa243.lab"

# Підписати CSR у CA викладача (файл server.csr передати викладачу)
# Отримати підписаний server.crt та помістити у /etc/nginx/ssl/
```

### 3.2 HTTPS у Nginx

```bash
sudo nano /etc/nginx/sites-available/mysite-ssl.conf
```

```nginx
server {
    listen 443 ssl;
    server_name X.tsa243.lab 11.203.X.12;

    # Шляхи до сертифіката та ключа
    ssl_certificate     /etc/nginx/ssl/nginx-selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;

    # Підтримувані протоколи (TLS 1.2 і 1.3 — сучасний стандарт)
    ssl_protocols TLSv1.2 TLSv1.3;

    # Набори шифрів — рекомендовані Mozilla
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:'
                'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:'
                'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305';
    ssl_prefer_server_ciphers off;      # TLS 1.3 сам обирає шифр

    # Кешування сесій SSL (зменшує накладні витрати на handshake)
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    # Заголовки безпеки
    add_header Strict-Transport-Security "max-age=63072000" always;  # HSTS

    root  /var/www/mysite;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/mysite-ssl.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

**Перевірити HTTPS:**

```bash
# Ігнорувати помилку самопідписаного сертифіката (-k)
curl -k https://11.203.X.12

# Переглянути деталі сертифіката
curl -kv https://11.203.X.12 2>&1 | grep -E "subject|issuer|SSL|TLS"

# Або через openssl
openssl s_client -connect 11.203.X.12:443 </dev/null 2>/dev/null \
    | openssl x509 -noout -subject -issuer -dates
```

### 3.3 Перенаправлення HTTP → HTTPS

Хороша практика: порт 80 лише перенаправляє на 443, весь контент — через HTTPS.

```nginx
# /etc/nginx/sites-available/mysite-ssl.conf

# Блок 1 — перенаправлення з HTTP на HTTPS
server {
    listen 80;
    server_name X.tsa243.lab 11.203.X.12;

    # 301 Moved Permanently
    return 301 https://$host$request_uri;
}

# Блок 2 — основний HTTPS сервер
server {
    listen 443 ssl;
    server_name X.tsa243.lab 11.203.X.12;

    ssl_certificate     /etc/nginx/ssl/nginx-selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    root  /var/www/mysite;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

**Перевірити редирект:**

```bash
# Має повернути 301 і заголовок Location
curl -I http://11.203.X.12

# Автоматично слідувати редиректам (-L), ігнорувати TLS (-k)
curl -Lk http://11.203.X.12
```

### 3.4 HTTPS у Apache2

Apache2 використовує **модуль `mod_ssl`** та власний формат конфігурації.

**Увімкнення SSL у Apache2:**

```bash
# Увімкнути модуль SSL
sudo a2enmod ssl

# Увімкнути готовий конфіг SSL-сайту за замовчуванням
sudo a2ensite default-ssl.conf

# Перезапустити (mod_ssl потребує повного перезапуску, не reload)
sudo systemctl restart apache2
```

**Переглянути та відредагувати конфіг SSL:**

```bash
sudo nano /etc/apache2/sites-available/default-ssl.conf
```

```apache
<IfModule mod_ssl.c>
    <VirtualHost _default_:443>
        ServerAdmin webmaster@localhost
        ServerName  X.tsa243.lab

        DocumentRoot /var/www/html

        # Шляхи до сертифіката та ключа
        SSLEngine on
        SSLCertificateFile    /etc/ssl/certs/ssl-cert-snakeoil.pem
        SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
        # Для власного сертифіката замінити на:
        # SSLCertificateFile    /etc/ssl/certs/mysite.crt
        # SSLCertificateKeyFile /etc/ssl/private/mysite.key

        # Протоколи та шифри
        SSLProtocol             all -SSLv3 -TLSv1 -TLSv1.1
        SSLCipherSuite          HIGH:!aNULL
        SSLHonorCipherOrder     off

        # Заголовки безпеки
        Header always set Strict-Transport-Security "max-age=63072000"

        <FilesMatch "\.(cgi|shtml|phtml|php)$">
            SSLOptions +StdEnvVars
        </FilesMatch>

        ErrorLog  ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
    </VirtualHost>
</IfModule>
```

**Увімкнути mod_headers для HSTS:**

```bash
sudo a2enmod headers
sudo systemctl reload apache2
```

**Перенаправлення HTTP → HTTPS в Apache2:**

```bash
# Увімкнути модуль redirect
sudo a2enmod rewrite

sudo nano /etc/apache2/sites-available/000-default.conf
```

```apache
<VirtualHost *:80>
    ServerName X.tsa243.lab
    Redirect permanent / https://X.tsa243.lab/
</VirtualHost>
```

```bash
sudo apache2ctl configtest
sudo systemctl reload apache2
```

### 3.5 Порівняння налаштування SSL: Nginx vs Apache2

| Параметр | Nginx | Apache2 |
|----------|-------|---------|
| Модуль SSL | вбудований | `mod_ssl` (`a2enmod ssl`) |
| Директива сертифіката | `ssl_certificate` | `SSLCertificateFile` |
| Директива ключа | `ssl_certificate_key` | `SSLCertificateKeyFile` |
| Протоколи | `ssl_protocols TLSv1.2 TLSv1.3` | `SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1` |
| Шифри | `ssl_ciphers HIGH:!aNULL:!MD5` | `SSLCipherSuite HIGH:!aNULL` |
| Порт | `listen 443 ssl` | `<VirtualHost *:443>` + `SSLEngine on` |
| HTTP→HTTPS | `return 301 https://...` | `Redirect permanent /` |
| Перевірка конфігу | `nginx -t` | `apache2ctl configtest` |
| Застосування змін | `systemctl reload nginx` | `systemctl reload apache2` |

---

## 4. Практична частина

### Крок 1 — Встановлення Nginx

```bash
sudo apt update && sudo apt install -y nginx
sudo systemctl enable nginx
sudo systemctl status nginx
```

### Крок 2 — Налаштування першого Virtual Host

```bash
# Відключити дефолтний сайт
sudo rm /etc/nginx/sites-enabled/default

# Створити каталог сайту
sudo mkdir -p /var/www/cadetX
sudo bash -c 'cat > /var/www/cadetX/index.html << EOF
<!DOCTYPE html>
<html lang="uk">
<head><meta charset="UTF-8"><title>Курсант X</title></head>
<body>
  <h1>Nginx — Курсант X</h1>
  <p>Сервер: 11.203.X.12</p>
  <p>Протокол: HTTP</p>
</body>
</html>
EOF'

# Створити конфіг
sudo nano /etc/nginx/sites-available/cadetX.conf
```

```nginx
server {
    listen 80 default_server;
    server_name X.tsa243.lab 11.203.X.12;

    root  /var/www/cadetX;
    index index.html;

    access_log /var/log/nginx/cadetX.access.log;
    error_log  /var/log/nginx/cadetX.error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/cadetX.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
curl http://11.203.X.12
```

### Крок 3 — Генерація сертифіката та HTTPS

```bash
# Замінити X на ваш номер варіанта
X=1    # <-- змінити!

sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/server.key \
    -out    /etc/nginx/ssl/server.crt \
    -subj "/C=UA/ST=Kyiv/O=VIIT/CN=11.203.${X}.12" \
    -addext "subjectAltName=IP:11.203.${X}.12,DNS:${X}.tsa243.lab"

sudo chmod 600 /etc/nginx/ssl/server.key
```

### Крок 4 — Налаштування HTTPS та редиректу

```bash
sudo nano /etc/nginx/sites-available/cadetX.conf
```

Замінити вміст файлу повністю:

```nginx
# HTTP → HTTPS redirect
server {
    listen 80 default_server;
    server_name X.tsa243.lab 11.203.X.12;
    return 301 https://$host$request_uri;
}

# HTTPS сервер
server {
    listen 443 ssl default_server;
    server_name X.tsa243.lab 11.203.X.12;

    ssl_certificate     /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 1d;

    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Content-Type-Options    "nosniff"          always;
    add_header X-Frame-Options           "SAMEORIGIN"       always;

    root  /var/www/cadetX;
    index index.html;

    access_log /var/log/nginx/cadetX-ssl.access.log;
    error_log  /var/log/nginx/cadetX-ssl.error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx

# Перевірка
curl -I http://11.203.X.12             # Очікувати: 301 Moved Permanently
curl -Ik https://11.203.X.12           # Очікувати: 200 OK
```

### Крок 5 — Налаштування Nginx як зворотного проксі

```bash
sudo nano /etc/nginx/sites-available/cadetX.conf
```

Додати location до HTTPS-блоку:

```nginx
    # Проксування до HAProxy
    location /app/ {
        proxy_pass http://11.203.X.13/;
        proxy_set_header Host            $host;
        proxy_set_header X-Real-IP       $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

---

## 5. Перевірка роботи

### На сервері Nginx (11.203.X.12):

```bash
# Статус служби
sudo systemctl status nginx

# Перевірити відкриті порти
sudo ss -tulnp | grep nginx

# Перевірити конфігурацію
sudo nginx -T              # Вивести повну конфігурацію з усіма includes
sudo nginx -t              # Тільки перевірка синтаксису

# Переглянути логи в реальному часі
sudo tail -f /var/log/nginx/cadetX.access.log
sudo tail -f /var/log/nginx/cadetX.error.log
sudo journalctl -u nginx -f
```

### З робочої станції (11.203.X.20):

```bash
# HTTP (повинен редиректити на HTTPS)
curl -I http://11.203.X.12

# HTTPS (самопідписаний — з -k)
curl -Ik https://11.203.X.12
curl -Ik https://X.tsa243.lab      # Якщо DNS налаштовано

# Переглянути сертифікат
openssl s_client -connect 11.203.X.12:443 </dev/null 2>/dev/null \
    | openssl x509 -noout -text | grep -A2 "Subject\|Issuer\|Not"

# Перевірити заголовки безпеки
curl -Isk https://11.203.X.12 | grep -iE "strict-transport|x-frame|x-content"
```

### Очікуваний результат:

```
# curl -I http://11.203.X.12
HTTP/1.1 301 Moved Permanently
Location: https://11.203.X.12/

# curl -Ik https://11.203.X.12
HTTP/2 200
server: nginx/1.24.0
strict-transport-security: max-age=63072000
x-content-type-options: nosniff
x-frame-options: SAMEORIGIN
```

---

## 6. Завдання на самопідготовку

### Завдання 1 — Базове (обов'язкове)

Налаштувати Nginx на вашій VM `11.203.X.12`:

1. Статичний HTTPS-сайт із самопідписаним сертифікатом
2. Перенаправлення HTTP → HTTPS (301)
3. Заголовки HSTS, X-Content-Type-Options, X-Frame-Options
4. Окремі access.log та error.log для вашого сайту

**Результат:** скріншот `curl -Ik https://11.203.X.12` з кодом 200 та заголовками безпеки.

---

### Завдання 2 — Середнє

Налаштувати два Virtual Hosts на одному Nginx:

- `site1.X.tsa243.lab` → `/var/www/site1/` (тільки HTTP)
- `site2.X.tsa243.lab` → `/var/www/site2/` (HTTPS, з редиректом з HTTP)

**Підказка:** Додати відповідні DNS-записи в BIND9 (`X.tsa243.lab` на `.10`).

**Результат:** `curl http://site1.X.tsa243.lab` і `curl -Lk http://site2.X.tsa243.lab` повертають різний контент.

---

### Завдання 3 — Підвищеної складності

Налаштувати Nginx як **зворотний HTTPS-проксі** з перевіркою сертифіката backend:

```
Клієнт → Nginx (443 SSL) → Backend (8080 HTTP)
```

1. На порту 8080 запустити простий Python HTTP-сервер:
   ```bash
   cd /var/www/mysite && python3 -m http.server 8080
   ```
2. Nginx на 443 проксює запити до `localhost:8080`
3. Налаштувати кастомні заголовки відповіді (`add_header X-Proxied-By "nginx"`)
4. Налаштувати буферизацію проксі (`proxy_buffering on`, `proxy_buffer_size 8k`)

**Результат:** `curl -Ik https://11.203.X.12` → заголовок `X-Proxied-By: nginx`.

---

### Питання для самоконтролю

1. Яка різниця між `systemctl reload nginx` та `systemctl restart nginx`? Коли використовувати кожен?
2. Що означає директива `try_files $uri $uri/ =404`? Що відбудеться для запиту `/about`?
3. Чому `ssl_protocols TLSv1.2 TLSv1.3` — а не `TLSv1.0`?
4. Що таке HSTS і навіщо встановлювати `max-age=63072000`?
5. Яка команда в Apache2 відповідає за `ln -s sites-available → sites-enabled` в Nginx?
6. Чому `ssl_session_tickets off` вважається кращою практикою?
7. Що буде, якщо `server_name` двох server-блоків однакові?

---

## 7. Корисні команди

### Управління службою

```bash
sudo systemctl start   nginx   # Запустити
sudo systemctl stop    nginx   # Зупинити
sudo systemctl restart nginx   # Перезапустити (розриває з'єднання)
sudo systemctl reload  nginx   # Graceful reload (без розриву з'єднань)
sudo systemctl enable  nginx   # Автозапуск при завантаженні
sudo systemctl status  nginx   # Статус
```

### Перевірка та діагностика

```bash
sudo nginx -t                       # Перевірка синтаксису
sudo nginx -T                       # Вивід всієї конфігурації
sudo nginx -v                       # Версія Nginx
sudo nginx -V                       # Версія + параметри компіляції (модулі)

sudo ss -tulnp | grep nginx         # Відкриті порти
sudo ps aux | grep nginx            # Процеси

# Логи
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
sudo journalctl -u nginx -f
sudo journalctl -u nginx --since "10 min ago"
```

### Сертифікати

```bash
# Переглянути деталі сертифіката
openssl s_client -connect host:443 </dev/null 2>/dev/null \
    | openssl x509 -noout -text

# Перевірити термін дії
openssl x509 -in /etc/nginx/ssl/server.crt -noout -dates

# Перевірити, що ключ відповідає сертифікату
openssl x509 -noout -modulus -in server.crt | md5sum
openssl rsa  -noout -modulus -in server.key | md5sum
# Обидва MD5 повинні збігатися
```

### Nginx та Apache2 — управління модулями та сайтами

| Дія | Nginx | Apache2 |
|-----|-------|---------|
| Увімкнути сайт | `ln -s sites-available/X sites-enabled/` | `a2ensite X` |
| Вимкнути сайт | `rm sites-enabled/X` | `a2dissite X` |
| Увімкнути модуль | *(вбудований або через nginx-extras)* | `a2enmod ssl` |
| Вимкнути модуль | — | `a2dismod ssl` |
| Перевірка конфігу | `nginx -t` | `apache2ctl configtest` |
| Graceful reload | `systemctl reload nginx` | `systemctl reload apache2` |

---

## Структура проєкту на GitHub

```
lesson7_6/
├── README.md                   ← Ця методичка
└── self_check/
    └── check.sh                ← Скрипт самоперевірки
```

---

> Матеріал підготовлено для навчальних занять ВІТІ.  
> Дисципліна: Технології Системного Адміністрування | Курс 2-й | 2026
