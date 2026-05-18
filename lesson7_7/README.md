# Змістовний модуль 7. Адміністрування серверів та балансування навантаження
## ЗАНЯТТЯ 7 (Практичне) — Встановлення та базове налаштування веб-сервера Nginx

> **Дисципліна:** Технології Системного Адміністрування | **Курс:** 2-й  
> **ОС:** Ubuntu Server 24.04 LTS | **Тип заняття:** Практичне  
> **Середовище:** Proxmox VE · VM Nginx курсанта `11.203.X.12`  
> **Час виконання:** ~90 хвилин  
> **Попереднє заняття:** Заняття 6 — Конфігурація Nginx (lesson7_6)

---

## Навчальні питання

1. [Встановлення Nginx](#питання-1--встановлення-nginx)
2. [Налаштування серверних блоків для різних сайтів](#питання-2--налаштування-серверних-блоків-для-різних-сайтів)

---

## Підготовка робочого місця

Підключіться до вашої VM Nginx (замінити `X` на номер вашого варіанта):

```bash
ssh user@11.203.X.12
```

Перевірте, що система оновлена:

```bash
sudo apt update
```

> Всі наступні команди виконуються на VM `11.203.X.12`, якщо не вказано інше.

---

# Питання 1 — Встановлення Nginx

## Крок 1.1 — Встановлення пакету

```bash
sudo apt install -y nginx
```

Перевірте встановлену версію:

```bash
nginx -v
```

Очікуваний вивід:

```
nginx version: nginx/1.24.0 (Ubuntu)
```

## Крок 1.2 — Управління службою

```bash
# Перевірити статус
sudo systemctl status nginx
```

Очікуваний вивід (скорочено):

```
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled)
     Active: active (running) since ...
```

```bash
# Увімкнути автозапуск при завантаженні системи
sudo systemctl enable nginx
```

## Крок 1.3 — Перевірка роботи за замовчуванням

```bash
# Перевірити, що nginx слухає порт 80
sudo ss -tulnp | grep nginx
```

Очікуваний вивід:

```
tcp   LISTEN  0  511  0.0.0.0:80  0.0.0.0:*  users:(("nginx",pid=...,fd=6))
```

```bash
# Зробити GET-запит до localhost
curl -I http://localhost
```

Очікуваний вивід:

```
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Content-Type: text/html
```

> Якщо отримали `200 OK` — Nginx встановлено та працює. Зверніть увагу на заголовок `Server:` — він показує версію. Пізніше ми його приховаємо.

## Крок 1.4 — Огляд структури конфігурації

```bash
# Переглянути структуру директорій
ls -la /etc/nginx/
ls -la /etc/nginx/sites-available/
ls -la /etc/nginx/sites-enabled/
```

```bash
# Переглянути поточний активний конфіг
cat /etc/nginx/sites-available/default
```

```bash
# Переглянути головний файл конфігурації
cat /etc/nginx/nginx.conf
```

**Зверніть увагу** на рядки в `nginx.conf`:

```nginx
include /etc/nginx/conf.d/*.conf;
include /etc/nginx/sites-enabled/*;
```

Саме ці рядки підключають ваші Virtual Host-конфіги.

## Крок 1.5 — Вимкнення сайту за замовчуванням

```bash
# Видалити симлінк на default (не видаляємо файл у sites-available!)
sudo rm /etc/nginx/sites-enabled/default

# Перевірити синтаксис
sudo nginx -t

# Застосувати зміни
sudo systemctl reload nginx

# Переконатися, що default більше не активний
ls /etc/nginx/sites-enabled/
```

Очікуваний вивід (порожній або відсутній список):

```
(порожньо)
```

```bash
# Тепер запит до localhost поверне 502 або порожню відповідь
curl -I http://localhost
```

---

# Питання 2 — Налаштування серверних блоків для різних сайтів

Ми налаштуємо **три серверні блоки**, кожен для окремого сайту:

| № | Домен | Документ-корінь | Призначення |
|---|-------|-----------------|-------------|
| 1 | `www.X.tsa243.lab` | `/var/www/www` | Головний статичний сайт |
| 2 | `info.X.tsa243.lab` | `/var/www/info` | Інформаційна сторінка з кастомними помилками |
| 3 | `proxy.X.tsa243.lab` | — | Зворотній проксі до HAProxy (`.13`) |

> Замінюйте `X` на номер вашого варіанта у всіх командах і файлах.

---

## Сайт 1 — Головний статичний сайт (`www.X.tsa243.lab`)

### Крок 2.1 — Створення директорії та контенту

```bash
sudo mkdir -p /var/www/www

sudo tee /var/www/www/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html lang="uk">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Курсант X — Головний сайт</title>
  <style>
    body { font-family: sans-serif; max-width: 800px; margin: 60px auto; padding: 0 20px; }
    h1   { color: #1a5276; }
    .info { background: #eaf2ff; border-left: 4px solid #2e86c1; padding: 12px 16px; margin: 20px 0; }
    code { background: #f0f0f0; padding: 2px 6px; border-radius: 3px; }
  </style>
</head>
<body>
  <h1>Nginx — Сайт 1: www</h1>
  <div class="info">
    <strong>Курсант:</strong> X<br>
    <strong>Сервер:</strong> 11.203.X.12<br>
    <strong>Сайт:</strong> www.X.tsa243.lab
  </div>
  <p>Головний статичний сайт. Налаштований через Virtual Host в Nginx.</p>
  <p>Конфіг: <code>/etc/nginx/sites-available/www.conf</code></p>
</body>
</html>
EOF
```

### Крок 2.2 — Створення конфігурації Virtual Host

```bash
sudo nano /etc/nginx/sites-available/www.conf
```

Вміст файлу (замінити `X` на ваш номер):

```nginx
server {
    listen 80;
    server_name www.X.tsa243.lab;

    root  /var/www/www;
    index index.html;

    access_log /var/log/nginx/www.access.log;
    error_log  /var/log/nginx/www.error.log;

    # Приховати версію nginx у відповідях
    server_tokens off;

    location / {
        try_files $uri $uri/ =404;
    }

    # Кешування статичних ресурсів на 7 днів
    location ~* \.(css|js|png|jpg|ico|svg|woff2)$ {
        expires 7d;
        add_header Cache-Control "public, no-transform";
    }
}
```

### Крок 2.3 — Активація та перевірка

```bash
# Створити симлінк (активувати сайт)
sudo ln -s /etc/nginx/sites-available/www.conf /etc/nginx/sites-enabled/

# Перевірити синтаксис
sudo nginx -t

# Застосувати
sudo systemctl reload nginx

# Перевірити відповідь (за IP, якщо DNS ще не налаштовано)
curl -H "Host: www.X.tsa243.lab" http://11.203.X.12
```

Очікуваний вивід: HTML-сторінка з вмістом index.html.

---

## Сайт 2 — Інформаційний сайт з кастомними помилками (`info.X.tsa243.lab`)

### Крок 2.4 — Створення директорії та сторінок

```bash
sudo mkdir -p /var/www/info

# Головна сторінка
sudo tee /var/www/info/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html lang="uk">
<head>
  <meta charset="UTF-8">
  <title>Курсант X — Інформація</title>
  <style>
    body { font-family: sans-serif; max-width: 800px; margin: 60px auto; padding: 0 20px; }
    h1   { color: #1e8449; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ccc; padding: 8px 12px; text-align: left; }
    th { background: #eafaf1; }
  </style>
</head>
<body>
  <h1>Nginx — Сайт 2: info</h1>
  <table>
    <tr><th>Параметр</th><th>Значення</th></tr>
    <tr><td>Курсант</td><td>X</td></tr>
    <tr><td>VM</td><td>11.203.X.12</td></tr>
    <tr><td>Сайт</td><td>info.X.tsa243.lab</td></tr>
    <tr><td>Служба</td><td>Nginx</td></tr>
  </table>
</body>
</html>
EOF

# Кастомна сторінка 404
sudo tee /var/www/info/404.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html lang="uk">
<head>
  <meta charset="UTF-8">
  <title>404 — Сторінку не знайдено</title>
  <style>
    body { font-family: sans-serif; text-align: center; padding-top: 80px; color: #555; }
    h1   { font-size: 6em; color: #c0392b; margin: 0; }
    p    { font-size: 1.2em; }
    a    { color: #2e86c1; }
  </style>
</head>
<body>
  <h1>404</h1>
  <p>Сторінку не знайдено.</p>
  <p><a href="/">← Повернутися на головну</a></p>
</body>
</html>
EOF

# Кастомна сторінка 50x
sudo tee /var/www/info/50x.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html lang="uk">
<head>
  <meta charset="UTF-8">
  <title>Помилка сервера</title>
  <style>
    body { font-family: sans-serif; text-align: center; padding-top: 80px; color: #555; }
    h1   { font-size: 6em; color: #e67e22; margin: 0; }
  </style>
</head>
<body>
  <h1>5xx</h1>
  <p>Помилка сервера. Спробуйте пізніше.</p>
</body>
</html>
EOF
```

### Крок 2.5 — Конфігурація з кастомними сторінками помилок

```bash
sudo nano /etc/nginx/sites-available/info.conf
```

```nginx
server {
    listen 80;
    server_name info.X.tsa243.lab;

    root  /var/www/info;
    index index.html;

    server_tokens off;

    access_log /var/log/nginx/info.access.log;
    error_log  /var/log/nginx/info.error.log;

    # Кастомні сторінки помилок
    error_page 404             /404.html;
    error_page 500 502 503 504 /50x.html;

    # Дозволити доступ до файлів помилок напряму
    location = /404.html {
        internal;               # тільки внутрішній redirect, не прямий URL
    }
    location = /50x.html {
        internal;
    }

    # Заборонити доступ до прихованих файлів (.htaccess тощо)
    location ~ /\. {
        deny all;
    }

    location / {
        try_files $uri $uri/ =404;
    }
}
```

### Крок 2.6 — Активація та перевірка

```bash
sudo ln -s /etc/nginx/sites-available/info.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Перевірити головну сторінку
curl -H "Host: info.X.tsa243.lab" http://11.203.X.12

# Перевірити кастомну 404 (запит до неіснуючої сторінки)
curl -I -H "Host: info.X.tsa243.lab" http://11.203.X.12/nonexistent
```

Очікуваний вивід для 404:

```
HTTP/1.1 404 Not Found
Content-Type: text/html
```

---

## Сайт 3 — Зворотній проксі до HAProxy (`proxy.X.tsa243.lab`)

### Крок 2.7 — Конфігурація зворотного проксі

```bash
sudo nano /etc/nginx/sites-available/proxy.conf
```

```nginx
server {
    listen 80;
    server_name proxy.X.tsa243.lab;

    server_tokens off;

    access_log /var/log/nginx/proxy.access.log;
    error_log  /var/log/nginx/proxy.error.log;

    # Передати всі запити до HAProxy
    location / {
        proxy_pass http://11.203.X.13;

        # Передати реальну IP-адресу клієнта
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Таймаути
        proxy_connect_timeout 5s;
        proxy_read_timeout    30s;

        # Якщо HAProxy недоступний — повернути 502
        proxy_intercept_errors on;
        error_page 502 /50x.html;
    }

    # Сторінка помилки якщо backend недоступний
    location = /50x.html {
        root /var/www/info;
        internal;
    }
}
```

### Крок 2.8 — Активація та перевірка

```bash
sudo ln -s /etc/nginx/sites-available/proxy.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Перевірити проксування (HAProxy має бути запущений на .13)
curl -I -H "Host: proxy.X.tsa243.lab" http://11.203.X.12
```

---

## Крок 2.9 — Додавання DNS-записів

Для доступу за доменними іменами додайте A-записи на DNS-сервері (`11.203.X.10`):

```bash
# Підключитися до DNS VM
ssh user@11.203.X.10

# Відредагувати файл зони
sudo nano /etc/bind/zones/db.X.tsa243.lab
```

Додати записи (замінити `X`):

```dns
; Nginx — Virtual Hosts
www     IN  A   11.203.X.12
info    IN  A   11.203.X.12
proxy   IN  A   11.203.X.12
```

```bash
# Збільшити Serial (наступне число після поточного)
# Перевірити та перезапустити BIND
sudo named-checkzone X.tsa243.lab /etc/bind/zones/db.X.tsa243.lab
sudo systemctl reload bind9
```

Повернутися на Nginx VM і перевірити DNS:

```bash
# З Nginx VM (11.203.X.12)
dig www.X.tsa243.lab @11.203.X.10
curl http://www.X.tsa243.lab
curl http://info.X.tsa243.lab
curl -I http://proxy.X.tsa243.lab
```

---

## Крок 2.10 — Підсумкова перевірка всіх сайтів

```bash
# Переглянути всі активні сайти
ls -la /etc/nginx/sites-enabled/

# Переглянути відкриті порти
sudo ss -tulnp | grep nginx

# Перевірити всю конфігурацію разом
sudo nginx -T | grep -E "server_name|listen|root|proxy_pass"
```

Очікуваний вивід `ls sites-enabled/`:

```
lrwxrwxrwx  www.conf   -> ../sites-available/www.conf
lrwxrwxrwx  info.conf  -> ../sites-available/info.conf
lrwxrwxrwx  proxy.conf -> ../sites-available/proxy.conf
```

```bash
# Протестувати всі три сайти одночасно
for site in www info proxy; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" \
           -H "Host: ${site}.X.tsa243.lab" http://11.203.X.12 --max-time 3)
    echo "${site}.X.tsa243.lab → HTTP ${CODE}"
done
```

Очікуваний вивід:

```
www.X.tsa243.lab   → HTTP 200
info.X.tsa243.lab  → HTTP 200
proxy.X.tsa243.lab → HTTP 200  (або 502, якщо HAProxy не запущено)
```

---

## Перевірка виконання роботи

Запустіть скрипт самоперевірки:

```bash
# Завантажити скрипт з репозиторію або скопіювати на VM
chmod +x check.sh
sudo ./check.sh
```

Або виконати перевірку вручну:

```bash
# 1. nginx встановлено та активно
systemctl is-active nginx

# 2. Три конфіги у sites-available
ls /etc/nginx/sites-available/ | grep -E "www|info|proxy"

# 3. Три симлінки у sites-enabled
ls /etc/nginx/sites-enabled/ | grep -E "www|info|proxy"

# 4. Три директорії з контентом
ls /var/www/www/ /var/www/info/

# 5. Відповіді від сайтів
curl -sI -H "Host: www.X.tsa243.lab"   http://localhost | head -1
curl -sI -H "Host: info.X.tsa243.lab"  http://localhost | head -1
curl -sI -H "Host: proxy.X.tsa243.lab" http://localhost | head -1
```

---

## Звіт про виконання роботи

Збережіть у звіті наступні скриншоти або вивід команд:

| № | Команда | Що демонструє |
|---|---------|---------------|
| 1 | `nginx -v` | Встановлена версія Nginx |
| 2 | `sudo systemctl status nginx` | Служба активна |
| 3 | `ls -la /etc/nginx/sites-enabled/` | Три активні сайти |
| 4 | `curl -H "Host: www.X.tsa243.lab" http://11.203.X.12` | Відповідь сайту 1 |
| 5 | `curl -I -H "Host: info.X.tsa243.lab" http://11.203.X.12/nonexistent` | 404 на сайті 2 |
| 6 | `curl -I -H "Host: proxy.X.tsa243.lab" http://11.203.X.12` | Проксування |
| 7 | `sudo nginx -T \| grep server_name` | Всі server_name у конфігурації |

---

## Завдання підвищеної складності

> Виконати за наявності часу. Результат — додаткові скриншоти або конфіги у PR.

### Завдання А — Четвертий Virtual Host з обмеженням доступу

Налаштувати `private.X.tsa243.lab`:

```nginx
server {
    listen 80;
    server_name private.X.tsa243.lab;
    root /var/www/private;

    # Дозволити доступ лише з підмережі
    location / {
        allow 11.203.X.0/25;    # Ваша підмережа
        allow 11.203.0.0/25;    # Підмережа викладача
        deny  all;
        try_files $uri $uri/ =404;
    }
}
```

Перевірити: `curl -H "Host: private.X.tsa243.lab" http://11.203.X.12` — код 200, а з іншої підмережі — 403.

### Завдання Б — Логи у форматі JSON

Додати у `nginx.conf` кастомний формат логів:

```nginx
log_format json_combined escape=json
  '{'
    '"time":"$time_iso8601",'
    '"ip":"$remote_addr",'
    '"method":"$request_method",'
    '"uri":"$uri",'
    '"status":$status,'
    '"size":$body_bytes_sent,'
    '"host":"$host",'
    '"ua":"$http_user_agent"'
  '}';
```

Підключити у server-блоці:

```nginx
access_log /var/log/nginx/www.json.log json_combined;
```

Переглянути: `tail -f /var/log/nginx/www.json.log | python3 -m json.tool`

---

## Корисні команди — швидка шпаргалка

```bash
sudo nginx -t                          # Перевірка синтаксису (завжди перед reload!)
sudo systemctl reload nginx            # Застосувати зміни без розриву з'єднань
sudo systemctl restart nginx           # Повний перезапуск

sudo ln -s /etc/nginx/sites-available/X.conf /etc/nginx/sites-enabled/   # Активувати
sudo rm /etc/nginx/sites-enabled/X.conf                                   # Деактивувати

sudo nginx -T | grep server_name       # Всі server_name у конфігурації
sudo tail -f /var/log/nginx/www.access.log      # Логи в реальному часі
sudo journalctl -u nginx -f                     # Системний журнал nginx
```

---

## Структура проєкту на GitHub

```
lesson7_7/
├── README.md           ← Ця методичка
└── self_check/
    └── check.sh        ← Скрипт самоперевірки
```

---

> Матеріал підготовлено для навчальних занять ВІТІ.  
> Дисципліна: Технології Системного Адміністрування | Курс 2-й | 2026
