# Змістовний модуль 7. Адміністрування серверів та балансування навантаження
## ЗАНЯТТЯ 7_10 (Практичне) — Розгортання та конфігурація HAProxy як балансувальника навантаження

> **Дисципліна:** Технології Системного Адміністрування | **Курс:** 2-й  
> **ОС:** Ubuntu Server 24.04 LTS | **Тип заняття:** Практичне  
> **Середовище:** Proxmox VE · підмережа курсанта `11.203.X.0/25`  
> **Час виконання:** ~90 хвилин  
> **Попередні заняття:** lesson7_9 (Лекція: балансування навантаження), lesson7_7 (Nginx)

---

## Навчальне питання

1. [Розгортання та конфігурація HAProxy як балансувальника навантаження](#питання-1--haproxy)

---

## Середовище заняття

| VM | Адреса | Роль |
|----|--------|------|
| Nginx VM | `11.203.X.12` | Reverse proxy → HAProxy |
| HAProxy VM | `11.203.X.13` | Балансувальник навантаження |
| Backend-01 | `11.203.X.30` | HTTP backend, порт 8080 |
| Backend-02 | `11.203.X.31` | HTTP backend, порт 8080 |

> Замінюйте `X` на номер вашого варіанта, `surname` — на ваше прізвище латинкою.

**Загальна схема:**

```
Client
  │
  ▼
Nginx (11.203.X.12:80)        ← TLS-термінатор та проксі
  │  proxy_pass
  ▼
HAProxy (11.203.X.13:80)      ← Балансувальник (цей урок)
  │  balance roundrobin
  ├─▶ backend-01 (11.203.X.30:8080)
  └─▶ backend-02 (11.203.X.31:8080)
```

---

# Питання 1 — HAProxy

Робота виконується у чотирьох термінальних вікнах паралельно — по одному на кожну VM. Відкрийте їх одразу перед початком.

```bash
# Вікно 1 — HAProxy VM
ssh user@11.203.X.13

# Вікно 2 — Backend-01
ssh user@11.203.X.30

# Вікно 3 — Backend-02
ssh user@11.203.X.31

# Вікно 4 — Nginx VM (для фінального тесту)
ssh user@11.203.X.12
```

---

## Крок 1 — Підготовка backend-серверів

> Виконати на **Backend-01 (11.203.X.30)** і **Backend-02 (11.203.X.31)** — однакові кроки, але з різним ідентифікатором backend.

### На Backend-01 (11.203.X.30):

```bash
# Встановити Nginx як простий HTTP-сервер
sudo apt update && sudo apt install -y nginx

# Видалити default-сайт
sudo rm -f /etc/nginx/sites-enabled/default

# Створити директорію сайту
sudo mkdir -p /var/www/backend01

# Головна сторінка з ідентифікатором backend
sudo tee /var/www/backend01/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html lang="uk">
<head>
  <meta charset="UTF-8">
  <title>Backend-01</title>
  <style>
    body { font-family: sans-serif; max-width: 600px; margin: 60px auto; text-align: center; }
    h1   { color: #1a5276; font-size: 3em; }
    .box { background: #d6eaf8; border-radius: 8px; padding: 20px; margin: 20px 0; }
    code { background: #f0f0f0; padding: 2px 8px; border-radius: 3px; }
  </style>
</head>
<body>
  <h1>BACKEND-01</h1>
  <div class="box">
    <strong>IP:</strong> 11.203.X.30<br>
    <strong>Port:</strong> 8080<br>
    <strong>Курсант:</strong> X
  </div>
  <p>Відповідь від <code>backend-01 (11.203.X.30:8080)</code></p>
</body>
</html>
EOF

# Health check endpoint
sudo tee /var/www/backend01/health > /dev/null << 'EOF'
OK
EOF

# Конфіг Nginx на порту 8080
sudo tee /etc/nginx/sites-available/backend01.conf > /dev/null << 'EOF'
server {
    listen 8080;
    server_name _;

    root  /var/www/backend01;
    index index.html;

    server_tokens off;

    location / {
        try_files $uri $uri/ =404;
    }

    location /health {
        access_log off;
        try_files $uri =404;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/backend01.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# Переконатись, що сервер відповідає на порту 8080
curl -s http://localhost:8080/health
```

Очікуваний вивід:
```
OK
```

```bash
# Перевірити що сервер слухає потрібний порт
sudo ss -tulnp | grep :8080
```

Очікуваний вивід:
```
tcp LISTEN  0  511  0.0.0.0:8080  users:(("nginx",...))
```

### На Backend-02 (11.203.X.31):

Виконати ті самі кроки, замінивши `backend01` на `backend02` і `11.203.X.30` на `11.203.X.31`:

```bash
sudo apt update && sudo apt install -y nginx
sudo rm -f /etc/nginx/sites-enabled/default
sudo mkdir -p /var/www/backend02

sudo tee /var/www/backend02/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html lang="uk">
<head>
  <meta charset="UTF-8">
  <title>Backend-02</title>
  <style>
    body { font-family: sans-serif; max-width: 600px; margin: 60px auto; text-align: center; }
    h1   { color: #1e8449; font-size: 3em; }
    .box { background: #d5f5e3; border-radius: 8px; padding: 20px; margin: 20px 0; }
    code { background: #f0f0f0; padding: 2px 8px; border-radius: 3px; }
  </style>
</head>
<body>
  <h1>BACKEND-02</h1>
  <div class="box">
    <strong>IP:</strong> 11.203.X.31<br>
    <strong>Port:</strong> 8080<br>
    <strong>Курсант:</strong> X
  </div>
  <p>Відповідь від <code>backend-02 (11.203.X.31:8080)</code></p>
</body>
</html>
EOF

sudo tee /var/www/backend02/health > /dev/null << 'EOF'
OK
EOF

sudo tee /etc/nginx/sites-available/backend02.conf > /dev/null << 'EOF'
server {
    listen 8080;
    server_name _;

    root  /var/www/backend02;
    index index.html;

    server_tokens off;

    location / {
        try_files $uri $uri/ =404;
    }

    location /health {
        access_log off;
        try_files $uri =404;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/backend02.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

curl -s http://localhost:8080/health
```

### Взаємна перевірка backend-ів з HAProxy VM:

```bash
# З HAProxy VM (11.203.X.13) — переконатись, що backend-и досяжні
curl -s http://11.203.X.30:8080/health
curl -s http://11.203.X.31:8080/health
```

Обидві команди повинні повернути `OK`. Якщо ні — перевірте firewall і статус Nginx на відповідному backend.

---

## Крок 2 — Встановлення HAProxy

> Виконується на **HAProxy VM (11.203.X.13)**

```bash
sudo apt update && sudo apt install -y haproxy
```

Перевірити встановлену версію:

```bash
haproxy -v
```

Очікуваний вивід:
```
HAProxy version 2.8.x (Ubuntu)
```

```bash
# Перевірити статус (після встановлення ще не налаштований)
sudo systemctl status haproxy
```

---

## Крок 3 — Базова конфігурація HAProxy (Round Robin)

> Виконується на **HAProxy VM (11.203.X.13)**

Зробіть резервну копію оригінального конфігу перед редагуванням:

```bash
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.orig
```

Відредагуйте конфіг:

```bash
sudo nano /etc/haproxy/haproxy.cfg
```

Замінити весь вміст файлу (підставте `X` — ваш номер варіанта):

```haproxy
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 1024

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    option  forwardfor
    option  http-server-close
    timeout connect  5s
    timeout client   30s
    timeout server   30s
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

frontend http_front
    bind *:80
    default_backend web_backends

backend web_backends
    balance roundrobin
    option  httpchk GET /health
    http-check expect string OK
    server backend01 11.203.X.30:8080 check inter 2s fall 3 rise 2
    server backend02 11.203.X.31:8080 check inter 2s fall 3 rise 2

listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 5s
    stats show-legends
    stats show-node
```

Перевірте синтаксис конфігурації (обов'язково перед запуском):

```bash
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
```

Очікуваний вивід:
```
Configuration file is valid
```

Запустіть HAProxy:

```bash
sudo systemctl enable haproxy
sudo systemctl restart haproxy
sudo systemctl status haproxy
```

Перевірте, що HAProxy слухає потрібні порти:

```bash
sudo ss -tulnp | grep haproxy
```

Очікуваний вивід:
```
tcp LISTEN  0.0.0.0:80    users:(("haproxy",...))
tcp LISTEN  0.0.0.0:8404  users:(("haproxy",...))
```

---

## Крок 4 — Перевірка балансування Round Robin

> Виконується на **HAProxy VM (11.203.X.13)**

```bash
# Відправити 6 запитів і подивитися, з якого backend приходить відповідь
for i in {1..6}; do
    curl -s http://11.203.X.13/ | grep -o 'BACKEND-[0-9]*'
done
```

Очікуваний вивід (поперемінно):
```
BACKEND-01
BACKEND-02
BACKEND-01
BACKEND-02
BACKEND-01
BACKEND-02
```

```bash
# Перевірити, що health check працює
curl -s http://11.203.X.13/health
```

Очікуваний вивід:
```
OK
```

### Панель статистики HAProxy

Відкрийте у браузері: `http://11.203.X.13:8404/stats`

Або переглянути через curl:

```bash
curl -s http://11.203.X.13:8404/stats | grep -E "backend|BACKEND|Status"
```

На панелі зверніть увагу:
- **Status** — `UP` для обох backend-ів
- **Scur / Smax** — поточні та максимальні з'єднання
- **Stot** — загальна кількість запитів (зростає після ваших тестів)
- **Check** — результат останнього health check (зелений = OK)

---

## Крок 5 — Тестування Health Check (відмова backend)

Цей крок демонструє ключову перевагу балансувальника: автоматичне виключення недоступного backend.

### Зупинити Backend-01:

```bash
# На Backend-01 VM (11.203.X.30)
sudo systemctl stop nginx
```

### На HAProxy VM — спостерігати за реакцією:

```bash
# Почекати 6 секунд (3 перевірки по 2 секунди = fall 3) і надіслати запити
sleep 6

for i in {1..6}; do
    curl -s http://11.203.X.13/ | grep -o 'BACKEND-[0-9]*'
done
```

Очікуваний вивід (тільки backend-02, backend-01 виведено з ротації):
```
BACKEND-02
BACKEND-02
BACKEND-02
BACKEND-02
BACKEND-02
BACKEND-02
```

```bash
# Переглянути статус backend-ів у реальному часі
watch -n 1 'echo "show stat" | sudo socat stdio /run/haproxy/admin.sock | cut -d, -f1,2,18 | grep -v "^#"'
```

> На панелі `http://11.203.X.13:8404/stats` backend-01 відобразиться червоним зі статусом `DOWN`.

### Відновити Backend-01:

```bash
# На Backend-01 VM (11.203.X.30)
sudo systemctl start nginx
```

### На HAProxy VM — перевірити відновлення:

```bash
# Почекати 4 секунди (2 успішні перевірки = rise 2) і перевірити
sleep 4

for i in {1..6}; do
    curl -s http://11.203.X.13/ | grep -o 'BACKEND-[0-9]*'
done
```

Очікуваний вивід (знову чергуються обидва backend):
```
BACKEND-01
BACKEND-02
BACKEND-01
BACKEND-02
BACKEND-01
BACKEND-02
```

> **Ключовий висновок:** HAProxy автоматично вивів backend-01 з ротації після 3 невдалих перевірок (6 секунд) і повернув його після 2 успішних (4 секунди). Жодного ручного втручання не потрібно.

---

## Крок 6 — Зміна алгоритму на Least Connections

> Виконується на **HAProxy VM (11.203.X.13)**

```bash
sudo nano /etc/haproxy/haproxy.cfg
```

Знайдіть і змініть тільки один рядок у секції `backend`:

```haproxy
# Було:
    balance roundrobin

# Стало:
    balance leastconn
```

```bash
# Перевірити конфіг і застосувати без зупинки трафіку
sudo haproxy -c -f /etc/haproxy/haproxy.cfg && sudo systemctl reload haproxy
```

```bash
# Перевірити, що балансування продовжує працювати
for i in {1..4}; do
    curl -s http://11.203.X.13/ | grep -o 'BACKEND-[0-9]*'
done
```

При `leastconn` з простими короткими запитами розподіл може виглядати як round robin — алгоритм проявляє себе при різному часі обробки запитів (файловий upload, повільні запити до БД).

```bash
# Повернути roundrobin для подальшої роботи
sudo nano /etc/haproxy/haproxy.cfg
# Змінити назад на: balance roundrobin
sudo haproxy -c -f /etc/haproxy/haproxy.cfg && sudo systemctl reload haproxy
```

---

## Крок 7 — Налаштування Nginx для проксювання до HAProxy

> Виконується на **Nginx VM (11.203.X.12)**

Nginx курсанта повинен приймати трафік і передавати його до HAProxy. Відредагуйте конфіг, створений у lesson7_7:

```bash
sudo nano /etc/nginx/sites-available/proxy.conf
```

Переконайтеся, що конфіг містить `proxy_pass` до HAProxy:

```nginx
server {
    listen 80;
    server_name surname.tsa243.lab www.surname.tsa243.lab;

    server_tokens off;

    access_log /var/log/nginx/surname.access.log;
    error_log  /var/log/nginx/surname.error.log;

    location / {
        proxy_pass         http://11.203.X.13;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;

        proxy_connect_timeout  5s;
        proxy_read_timeout     30s;
    }

    # Статичний контент — обслуговуємо безпосередньо
    location /static/ {
        root /var/www/surname;
    }

    # Health check без звернення до backend
    location /health {
        return 200 "surname.tsa243.lab OK\n";
        add_header Content-Type text/plain;
    }
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### Перевірити повний ланцюжок:

```bash
# З Nginx VM — через весь ланцюжок Nginx → HAProxy → backend
for i in {1..4}; do
    curl -s http://11.203.X.12/ | grep -o 'BACKEND-[0-9]*'
done
```

Очікуваний вивід (чергуються):
```
BACKEND-01
BACKEND-02
BACKEND-01
BACKEND-02
```

```bash
# Перевірити, що заголовок X-Forwarded-For передається
curl -s http://11.203.X.12/ -D - 2>/dev/null | grep -i "x-forwarded"
```

---

## Крок 8 — Перевірка збереження X-Forwarded-For на backend

Переконайтеся, що backend-и бачать реальну IP-адресу клієнта, а не IP HAProxy.

```bash
# На Backend-01 (11.203.X.30) — переглянути логи доступу
sudo tail -5 /var/log/nginx/access.log
```

У логах ви побачите два IP:
- Перший — IP HAProxy (`11.203.X.13`) у полі клієнтського IP (тому що Nginx на backend бачить HAProxy)
- Заголовок `X-Forwarded-For` — реальна IP клієнта (передається через `option forwardfor` у HAProxy)

> Щоб backend логував реальний IP клієнта — потрібно налаштувати Nginx на backend читати заголовок `X-Forwarded-For`. Це тема для наступного курсу (Nginx + log_format).

---

## Крок 9 — Підсумкова перевірка всього ланцюжку

```bash
# Зі своєї робочої станції (11.203.X.20) — перевірити повний шлях
curl -v http://surname.tsa243.lab/ 2>&1 | grep -E "< HTTP|BACKEND|Connected"
```

```bash
# Переконатися, що всі компоненти запущені
for vm_ip in 11.203.X.12 11.203.X.13 11.203.X.30 11.203.X.31; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://${vm_ip}:$([ "${vm_ip}" = "11.203.X.30" ] || [ "${vm_ip}" = "11.203.X.31" ] && echo "8080" || echo "80")/health --max-time 3)
    echo "${vm_ip} → HTTP ${STATUS}"
done
```

Очікуваний вивід:
```
11.203.X.12 → HTTP 200   (Nginx, /health endpoint)
11.203.X.13 → HTTP 200   (HAProxy → backend)
11.203.X.30 → HTTP 200   (backend-01 /health)
11.203.X.31 → HTTP 200   (backend-02 /health)
```

---

## Перевірка виконання роботи

Запустіть скрипт самоперевірки на **HAProxy VM (11.203.X.13)**:

```bash
chmod +x check.sh && sudo ./check.sh
```

Або виконати вручну:

```bash
# 1. HAProxy встановлено та активно
systemctl is-active haproxy

# 2. HAProxy слухає порт 80
ss -tulnp | grep -q ':80.*haproxy' && echo "OK: порт 80" || echo "FAIL: порт 80"

# 3. HAProxy слухає порт 8404 (stats)
ss -tulnp | grep -q ':8404.*haproxy' && echo "OK: порт 8404" || echo "FAIL: порт 8404"

# 4. Backend-01 відповідає
curl -sf http://11.203.X.30:8080/health | grep -q "OK" && echo "OK: backend-01" || echo "FAIL: backend-01"

# 5. Backend-02 відповідає
curl -sf http://11.203.X.31:8080/health | grep -q "OK" && echo "OK: backend-02" || echo "FAIL: backend-02"

# 6. HAProxy балансує між обома backend-ами
RESULTS=$(for i in {1..4}; do curl -s http://11.203.X.13/ | grep -o 'BACKEND-[0-9]*'; done | sort | uniq)
echo "$RESULTS" | grep -q "BACKEND-01" && echo "$RESULTS" | grep -q "BACKEND-02" \
    && echo "OK: балансування (обидва backend)" \
    || echo "FAIL: балансування (відповідає лише один backend)"

# 7. Синтаксис конфігу
sudo haproxy -c -f /etc/haproxy/haproxy.cfg > /dev/null 2>&1 \
    && echo "OK: конфіг валідний" || echo "FAIL: помилка в конфізі"
```

---

## Звіт про виконання роботи

Збережіть у звіті наступний вивід команд або скриншоти:

| № | Команда / дія | Що демонструє |
|---|--------------|---------------|
| 1 | `haproxy -v` | Версія HAProxy |
| 2 | `sudo haproxy -c -f /etc/haproxy/haproxy.cfg` | Конфіг валідний |
| 3 | `sudo ss -tulnp \| grep haproxy` | Слухає порти 80 і 8404 |
| 4 | `for i in {1..6}; do curl -s http://11.203.X.13/ \| grep -o 'BACKEND-[0-9]*'; done` | Балансування Round Robin |
| 5 | Скриншот `http://11.203.X.13:8404/stats` (обидва backend UP) | Панель статистики, обидва UP |
| 6 | `sudo systemctl stop nginx` на backend-01 → `sleep 6` → 6 запитів → `sudo systemctl start nginx` | Health check: backend-01 виведено і повернуто |
| 7 | Скриншот `http://11.203.X.13:8404/stats` (backend-01 DOWN) | Панель статистики під час відмови |
| 8 | `for i in {1..4}; do curl -s http://11.203.X.12/ \| grep -o 'BACKEND-[0-9]*'; done` | Повний ланцюжок Nginx → HAProxy → backend |

---

## Завдання підвищеної складності

> Виконати за наявності часу.

### Завдання А — Weighted Round Robin

Призначити backend-01 вдвічі більше ваги:

```haproxy
backend web_backends
    balance roundrobin
    option  httpchk GET /health
    http-check expect string OK
    server backend01 11.203.X.30:8080 weight 2 check inter 2s fall 3 rise 2
    server backend02 11.203.X.31:8080 weight 1 check inter 2s fall 3 rise 2
```

Перевірити:
```bash
for i in {1..9}; do curl -s http://11.203.X.13/ | grep -o 'BACKEND-[0-9]*'; done
```

Очікуваний результат: 6 відповідей від backend-01, 3 — від backend-02.

### Завдання Б — Резервний backend

Додати `backup`-сервер, який вмикається лише коли обидва основних недоступні:

```haproxy
backend web_backends
    balance roundrobin
    option  httpchk GET /health
    http-check expect string OK
    server backend01 11.203.X.30:8080 check inter 2s fall 3 rise 2
    server backend02 11.203.X.31:8080 check inter 2s fall 3 rise 2
    server backup    11.203.X.32:8080 check backup
```

Зупиніть обидва основних backend та перевірте, що відповідає backup.

### Завдання В — ACL-маршрутизація

Налаштувати різні backend-пули для різних URL:

```haproxy
frontend http_front
    bind *:80

    acl is_api   path_beg /api/
    acl is_static path_beg /static/

    use_backend api_backends    if is_api
    use_backend static_backends if is_static
    default_backend web_backends

backend api_backends
    balance leastconn
    server backend01 11.203.X.30:8080 check

backend static_backends
    balance roundrobin
    server backend02 11.203.X.31:8080 check

backend web_backends
    balance roundrobin
    server backend01 11.203.X.30:8080 check
    server backend02 11.203.X.31:8080 check
```

---

## Типові помилки та вирішення

| Помилка | Причина | Вирішення |
|---------|---------|-----------|
| `[ALERT] Cannot bind socket [0.0.0.0:80]` | Порт 80 вже зайнятий (Nginx?) | `sudo ss -tulnp \| grep :80`; зупинити конфліктуючий сервіс |
| `backend01 is DOWN` одразу після старту | Backend не запущено або порт недоступний | `curl http://11.203.X.30:8080/health` з HAProxy VM |
| `curl: (7) Failed to connect` до backend | Firewall блокує порт 8080 | `sudo ufw allow 8080` на backend VM |
| `[NOTICE] haproxy, process #1 (1234) exited with code 1` | Синтаксична помилка в конфізі | `sudo haproxy -c -f /etc/haproxy/haproxy.cfg` |
| Тільки один backend відповідає | health check рядок не збігається | Перевірити: `curl http://11.203.X.30:8080/health` — має повернути рівно `OK` |
| `reload` не застосовує нові backend | Стара версія HAProxy | Замінити на `restart` (з коротким downtime) |

---

## Корисні команди — шпаргалка

```bash
# HAProxy
sudo haproxy -c -f /etc/haproxy/haproxy.cfg   # Перевірити синтаксис (завжди перед reload!)
sudo systemctl reload  haproxy                 # Graceful reload (без downtime)
sudo systemctl restart haproxy                 # Повний перезапуск
sudo journalctl -u haproxy -f                  # Журнал в реальному часі

# Статистика через сокет
echo "show stat"  | sudo socat stdio /run/haproxy/admin.sock | cut -d, -f1,2,18
echo "show info"  | sudo socat stdio /run/haproxy/admin.sock | grep -E "Name|Ver|MaxConn|CurrConns"
echo "show servers state" | sudo socat stdio /run/haproxy/admin.sock

# Тест балансування
for i in {1..6}; do curl -s http://11.203.X.13/ | grep -o 'BACKEND-[0-9]*'; done

# Тест відмовостійкості (зупинити backend і спостерігати)
watch -n 1 'curl -s http://11.203.X.13/ | grep -o "BACKEND-[0-9]*"'
```

---

## Структура проєкту на GitHub

```
lesson7_10/
├── README.md           ← Ця методичка
└── self_check/
    └── check.sh        ← Скрипт самоперевірки
```

---

> Матеріал підготовлено для навчальних занять ВІТІ.  
> Дисципліна: Технології Системного Адміністрування | Курс 2-й | 2026
