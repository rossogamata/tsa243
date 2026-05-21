# Змістовний модуль 7. Адміністрування серверів та балансування навантаження
## ЗАНЯТТЯ 7_9 (Лекція) — Балансування навантаження

> **Дисципліна:** Технології Системного Адміністрування | **Курс:** 2-й  
> **ОС:** Ubuntu Server 24.04 LTS | **Тип заняття:** Лекційне  
> **Середовище:** Proxmox VE · підмережа курсанта `11.203.X.0/25`  
> **Час:** ~90 хвилин  
> **Попередні заняття:** lesson7_7 (Nginx), lesson7_8 (SSL/TLS)

---

## Навчальні питання

1. [Поняття балансування навантаження, алгоритми та методи](#питання-1--балансування-навантаження)
2. [Поняття та типи проксі-серверів](#питання-2--проксі-сервери)
3. [Налаштування HAProxy та Nginx як балансувальника](#питання-3--налаштування-haproxy-та-nginx)

---

## Місце заняття в архітектурі курсу

У нашому проекті `tsa243.lab` кожен курсант вже підняв DNS, SMTP та Nginx. На цьому занятті розберемо **останній ключовий елемент** — балансувальник навантаження, який завершує ланцюжок обробки запитів:

```
Client
  │
  ▼  HTTP/HTTPS
proxy.tsa243.lab (11.203.0.12)     ← Nginx викладача (центральна точка входу)
  │
  ▼  proxy_pass
www.surname.tsa243.lab (11.203.X.12)  ← Nginx курсанта (TLS-термінатор)
  │
  ▼  proxy_pass
lb.surname.tsa243.lab (11.203.X.13)   ← HAProxy (БАЛАНСУВАЛЬНИК)
  │
  ├─▶ backend-01 (11.203.X.30:8080)
  └─▶ backend-02 (11.203.X.31:8080)
```

> HAProxy на `11.203.X.13` — це VM, яку ви конфігурували, але ще не вводили в дію. Після цього заняття та практичної роботи ланцюжок буде повністю завершений.

---

## Питання 1 — Балансування навантаження

### 1.1 Навіщо балансувати навантаження?

**Проблема одного сервера:**

```
         Клієнти (1000 запитів/с)
              │
              ▼
    ┌─────────────────┐
    │  Один сервер    │  ← Єдина точка відмови (SPOF)
    │  CPU: 100%      │  ← Не масштабується
    │  RAM: переповн. │  ← Якщо впав — весь сервіс недоступний
    └─────────────────┘
```

**Рішення — горизонтальне масштабування:**

```
         Клієнти (1000 запитів/с)
              │
              ▼
    ┌─────────────────┐
    │  Балансувальник │
    └────────┬────────┘
             │
      ┌──────┴──────┐
      ▼             ▼
┌──────────┐  ┌──────────┐
│ Backend1 │  │ Backend2 │  ← Кожен обробляє ~500 запитів/с
│ CPU: 50% │  │ CPU: 50% │  ← Якщо один впав — другий продовжує
└──────────┘  └──────────┘
```

**Три основні задачі балансувальника:**

| Задача | Опис |
|--------|------|
| **Розподіл навантаження** | Рівномірно розподіляє запити між backend-серверами |
| **Висока доступність** | Виводить з ротації backend, що не відповідає на health check |
| **Масштабованість** | Додавання нового backend не потребує зміни клієнтського коду |

---

### 1.2 Алгоритми балансування

#### Round Robin (по черзі)

```
Запит 1  →  Backend-01
Запит 2  →  Backend-02
Запит 3  →  Backend-01
Запит 4  →  Backend-02
...
```

**HAProxy:** `balance roundrobin`  
**Nginx:** `upstream { ... }` (алгоритм за замовчуванням)

**Коли застосовувати:** Однакові сервери, короткі статeless-запити (API, статичний контент).  
**Не підходить:** Якщо запити мають суттєво різний час обробки.

---

#### Weighted Round Robin (зважений)

```
backend-01 weight 3  →  отримує 3/4 запитів
backend-02 weight 1  →  отримує 1/4 запитів
```

**HAProxy:**
```
backend web_backends
    balance roundrobin
    server backend01 11.203.X.30:8080 weight 3 check
    server backend02 11.203.X.31:8080 weight 1 check
```

**Nginx:**
```nginx
upstream backends {
    server 11.203.X.30:8080 weight=3;
    server 11.203.X.31:8080 weight=1;
}
```

**Коли застосовувати:** Сервери з різною потужністю (новий та старий сервер в кластері).

---

#### Least Connections (найменше з'єднань)

```
Запит надходить →  балансувальник перевіряє активні з'єднання:
    backend-01: 42 з'єднання
    backend-02: 17 з'єднань  ← обирає цей
```

**HAProxy:** `balance leastconn`  
**Nginx:** `least_conn;`

**Коли застосовувати:** Запити з різним часом обробки (file upload, WebSocket, DB queries). Запит не закривається відразу — важливо, хто менш зайнятий.

---

#### IP Hash (за IP-адресою клієнта)

```
Client 192.168.1.10  →  завжди Backend-01 (hash(192.168.1.10) % 2 = 0)
Client 192.168.1.11  →  завжди Backend-02 (hash(192.168.1.11) % 2 = 1)
```

**HAProxy:** `balance source`  
**Nginx:** `ip_hash;`

**Коли застосовувати:** Sticky sessions — коли сервер зберігає стан сесії в пам'яті (не в базі даних). Той самий клієнт завжди потрапляє на той самий backend.

**Увага:** Якщо backend-01 виходить з ладу — всі його клієнти переходять на backend-02 і втрачають сесію. Це не вирішує проблему, а лише відкладає її. Правильне рішення — зберігати сесії в Redis/Memcached.

---

#### URL Hash

```
GET /api/users/123  →  завжди Backend-01 (hash("/api/users") % 2 = 0)
GET /api/orders/456 →  завжди Backend-02 (hash("/api/orders") % 2 = 1)
```

**HAProxy:** `balance uri`

**Коли застосовувати:** Кешування на backend-серверах. Запити до одного URL завжди потрапляють на один сервер → cache hit rate зростає.

---

### 1.3 Порівняння алгоритмів

| Алгоритм | HAProxy | Nginx | Рівномірність | Sticky | Складність |
|----------|---------|-------|--------------|--------|------------|
| Round Robin | `roundrobin` | (default) | Висока | Ні | Мінімальна |
| Weighted RR | `roundrobin` + weight | `weight=N` | Контрольована | Ні | Низька |
| Least Conn | `leastconn` | `least_conn` | Динамічна | Ні | Середня |
| IP Hash | `source` | `ip_hash` | Нерівномірна | Так | Низька |
| URL Hash | `uri` | `hash $uri` | Нерівномірна | По URL | Середня |

---

### 1.4 Health Check — перевірка доступності backend

Балансувальник повинен знати, що backend живий. Є три рівні перевірки:

**Рівень 1 — TCP (порт відкритий?):**
```
HAProxy → TCP connect → 11.203.X.30:8080
Успіх: порт відповідає → backend в ротації
Провал: connection refused → backend виводиться з ротації
```

**Рівень 2 — HTTP (додаток відповідає?):**
```
HAProxy → GET /health HTTP/1.0 → 11.203.X.30:8080
Очікуємо: HTTP 2xx
Провал: 5xx або таймаут → backend виводиться
```

**Рівень 3 — Content check (відповідь правильна?):**
```
HAProxy → GET /health → 11.203.X.30:8080
Очікуємо: body містить "OK"
Провал: будь-яке інше тіло → backend виводиться
```

**У нашому проекті** backend-сервери повинні мати ендпоінт `/health`:
```bash
# Простий Python HTTP server як backend (для тестування)
python3 -m http.server 8080

# Або static file
echo "OK" > /var/www/html/health
```

**HAProxy health check конфігурація:**
```
option httpchk GET /health
http-check expect string OK
server backend01 11.203.X.30:8080 check inter 2s fall 3 rise 2
```

| Параметр | Значення | Опис |
|----------|----------|------|
| `check` | — | Вмикає health check |
| `inter 2s` | 2 секунди | Інтервал між перевірками |
| `fall 3` | 3 провали | Після 3 невдач — backend DOWN |
| `rise 2` | 2 успіхи | Після 2 успіхів — backend UP |

---

### 1.5 Рівні балансування (OSI)

| Рівень | Назва | Де балансує | Інструменти |
|--------|-------|-------------|-------------|
| L4 | Transport | TCP/UDP (IP + порт) | HAProxy (mode tcp), LVS, AWS NLB |
| L7 | Application | HTTP (URL, заголовки, cookies) | HAProxy (mode http), Nginx, AWS ALB |

**L4 балансування:**
- Не дивиться на вміст пакету — тільки на IP:port
- Дуже швидке, мінімальний overhead
- Не може аналізувати URL, cookies, заголовки
- Підходить для: MySQL cluster, PostgreSQL, TCP-сервіси

**L7 балансування:**
- Розбирає HTTP-запит повністю
- Може маршрутизувати за URL: `/api/` → backend cluster A, `/static/` → CDN
- Може вставляти/читати cookies для sticky sessions
- Підходить для: веб-додатки, API, мікросервіси

> У нашому проекті HAProxy працює в **mode http** (L7) — це дозволяє робити health check за URL і аналізувати HTTP-заголовки.

---

## Питання 2 — Проксі-сервери

### 2.1 Що таке проксі?

**Проксі** — посередник між клієнтом і сервером, який перехоплює трафік і виконує додаткові функції.

```
Без проксі:
Client ──────────────────────────────▶ Server

З проксі:
Client ──▶ Proxy ──▶ Server
            │
            ├─ кешує відповіді
            ├─ логує запити
            ├─ фільтрує контент
            ├─ змінює заголовки
            └─ балансує навантаження
```

---

### 2.2 Типи проксі

#### Forward Proxy (пряме проксі)

```
[Внутрішня мережа]              [Інтернет]
    Client
      │
      ▼
  Forward Proxy  ────────────▶  example.com
      │
      ▼
  Client отримує відповідь
```

**Хто знає про проксі:** Клієнт (браузер налаштований явно).  
**Хто НЕ знає:** Цільовий сервер (бачить IP проксі, не клієнта).

**Задачі:**
- Корпоративна фільтрація: блокувати соціальні мережі
- Анонімізація: приховати IP клієнта
- Кешування: зберегти популярний контент, прискорити доступ
- Обхід гео-блокувань

**Приклади:** Squid, CCProxy, 3proxy

---

#### Reverse Proxy (зворотне проксі)

```
[Інтернет]               [Внутрішня мережа]
  Client
    │
    ▼
Reverse Proxy  ──────────▶  Backend-01
    │          ──────────▶  Backend-02
    │          ──────────▶  Backend-03
```

**Хто знає про проксі:** Backend-сервери (бачать IP проксі, не клієнта).  
**Хто НЕ знає:** Клієнт (думає, що спілкується безпосередньо з `surname.tsa243.lab`).

**Задачі:**
- Балансування навантаження (наш основний кейс)
- TLS-термінація: SSL розшифровується на проксі, до backend йде HTTP
- Кешування: зберегти відповіді backend, зменшити навантаження
- Захист: backend не доступний з інтернету напряму
- Стиснення: gzip перед відправкою клієнту

**Приклади:** Nginx, HAProxy, Apache (mod_proxy), Traefik

---

#### Transparent Proxy (прозоре проксі)

```
Client ──▶ [мережа] ──▶ Proxy (перехоплює автоматично) ──▶ Server
```

Клієнт **не налаштований** на проксі і не знає про нього. Трафік перехоплюється на рівні мережі (iptables REDIRECT).

**Застосування:** Корпоративний моніторинг, DPI (deep packet inspection), батьківський контроль.

---

#### Порівняльна таблиця

| Характеристика | Forward Proxy | Reverse Proxy | Transparent |
|---------------|---------------|---------------|-------------|
| Хто налаштовує | Клієнт | Адміністратор сервера | Адміністратор мережі |
| Клієнт знає | Так | Ні | Ні |
| Сервер знає | Ні | Так | Ні |
| Захищає | Клієнта | Backend-сервери | Мережу |
| Типовий кейс | Корп. фільтрація | Балансування, CDN | DPI, моніторинг |

---

### 2.3 Проксі в нашій архітектурі tsa243.lab

Наш проект використовує **два рівні reverse proxy**:

```
┌─────────────────────────────────────────────────────────────┐
│ Рівень 1: Nginx викладача (11.203.0.12)                     │
│   — Точка входу для всього домену tsa243.lab                │
│   — Маршрутизація за hostname: surname.tsa243.lab → X.12    │
│   — TLS-термінація (якщо є HTTPS)                           │
└─────────────────────────┬───────────────────────────────────┘
                          │ proxy_pass http://11.203.X.12
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Рівень 2: Nginx курсанта (11.203.X.12)                      │
│   — Обслуговує static files (location /static/)             │
│   — Решту проксує до HAProxy                                │
│   — Встановлює X-Real-IP, X-Forwarded-For                   │
└─────────────────────────┬───────────────────────────────────┘
                          │ proxy_pass http://11.203.X.13
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Рівень 3: HAProxy (11.203.X.13)                             │
│   — L7 балансувальник                                       │
│   — Health check backend-серверів                           │
│   — Round Robin / Least Conn між backend-01 і backend-02    │
└──────────┬────────────────────────────┬──────────────────────┘
           │                            │
           ▼                            ▼
┌─────────────────┐          ┌─────────────────┐
│ backend-01      │          │ backend-02      │
│ 11.203.X.30:8080│          │ 11.203.X.31:8080│
└─────────────────┘          └─────────────────┘
```

**Чому два рівні Nginx, а не один?**

| Критерій | Один рівень | Два рівні (наш підхід) |
|----------|-------------|------------------------|
| Ізоляція | Помилки курсанта впливають на всіх | Проблема курсанта ізольована |
| Гнучкість | Всі під одними правилами | Кожен може налаштовувати свій Nginx |
| Навчання | Один сервер — менше матеріалу | Кожен вивчає повний стек |
| Реальність | Спрощена | Відображає продакшн-архітектуру |

---

### 2.4 Важливі HTTP-заголовки в ланцюжку проксі

Коли запит проходить через декілька проксі, реальний IP клієнта губиться. Для його збереження використовуються заголовки:

```
Client (1.2.3.4) → Nginx 0.12 → Nginx X.12 → HAProxy X.13 → Backend
```

**X-Real-IP** — IP першого клієнта:
```nginx
proxy_set_header X-Real-IP $remote_addr;
```

**X-Forwarded-For** — ланцюжок всіх IP:
```
X-Forwarded-For: 1.2.3.4, 11.203.0.12, 11.203.X.12
# клієнт,         proxy1,              proxy2
```

```nginx
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```

**Чому це важливо:** Логи backend-сервера без цих заголовків показуватимуть IP проксі (`11.203.X.13`), а не реального клієнта. Неможливо відстежити атаку або зробити аналіз трафіку.

---

## Питання 3 — Налаштування HAProxy та Nginx

### 3.1 HAProxy — архітектура конфігурації

Конфігурація `/etc/haproxy/haproxy.cfg` складається з чотирьох секцій:

```
global       ← Системні параметри: логування, процеси, безпека
defaults     ← Значення за замовчуванням для frontend/backend
frontend     ← Де слухаємо і як розподіляємо запити
backend      ← Куди відправляємо і як балансуємо
```

---

#### Секція `global`

```haproxy
global
    log /dev/log local0           # Логувати в syslog
    log /dev/log local1 notice    # Окремо notice-рівень
    chroot /var/lib/haproxy       # Обмежити доступ до ФС
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy                  # Запускатись від непривілейованого користувача
    group haproxy
    daemon                        # Фоновий процес
    maxconn 2000                  # Максимум одночасних з'єднань
```

---

#### Секція `defaults`

```haproxy
defaults
    log     global               # Використовувати налаштування з global
    mode    http                 # Режим: http (L7) або tcp (L4)
    option  httplog              # Детальне логування HTTP-запитів
    option  dontlognull          # Не логувати порожні з'єднання (health check)
    option  forwardfor           # Додавати X-Forwarded-For
    option  http-server-close    # Закривати з'єднання після відповіді
    timeout connect  5s          # Таймаут встановлення з'єднання з backend
    timeout client   30s         # Таймаут очікування від клієнта
    timeout server   30s         # Таймаут очікування від backend
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 502 /etc/haproxy/errors/502.http
```

---

#### Секція `frontend`

```haproxy
frontend http_front
    bind *:80                    # Слухати на всіх інтерфейсах, порт 80
    
    # ACL — умовна маршрутизація
    acl is_api   path_beg /api/
    acl is_static path_beg /static/
    
    # Маршрутизація за ACL
    use_backend api_servers   if is_api
    use_backend static_files  if is_static
    
    # За замовчуванням
    default_backend web_backends
```

**Що таке ACL в HAProxy:**
```haproxy
# Умови за URL
acl is_api       path_beg /api/         # URL починається з /api/
acl is_login     path_eq /login         # URL точно /login
acl is_image     path_end .jpg .png     # URL закінчується на .jpg або .png

# Умови за заголовками
acl is_mobile    hdr_sub(User-Agent) Mobile
acl is_https     hdr(X-Forwarded-Proto) https

# Умови за методом
acl is_post      method POST
```

---

#### Секція `backend`

```haproxy
backend web_backends
    balance roundrobin           # Алгоритм балансування
    
    option httpchk GET /health   # HTTP health check
    http-check expect status 200 # Очікуємо HTTP 200
    
    # Сервери з параметрами
    server backend01 11.203.X.30:8080 check inter 2s fall 3 rise 2
    server backend02 11.203.X.31:8080 check inter 2s fall 3 rise 2
    
    # Резервний сервер (використовується тільки якщо всі основні DOWN)
    server backup01 11.203.X.32:8080 check backup
```

---

#### Секція `listen` — комбінований frontend+backend

```haproxy
listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
    stats auth admin:password    # Опційно: базова автентифікація
    stats show-legends
```

> Панель статистики HAProxy за адресою `http://11.203.X.13:8404/stats` — ваш головний інструмент моніторингу балансувальника.

---

### 3.2 Повна базова конфігурація HAProxy для проекту

```haproxy
# /etc/haproxy/haproxy.cfg

global
    log /dev/log local0
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
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
    timeout connect  5s
    timeout client   30s
    timeout server   30s

frontend http_front
    bind *:80
    default_backend web_backends

backend web_backends
    balance roundrobin
    option httpchk GET /health
    server backend01 11.203.X.30:8080 check inter 2s fall 3 rise 2
    server backend02 11.203.X.31:8080 check inter 2s fall 3 rise 2

listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
```

---

### 3.3 Nginx як балансувальник навантаження

Nginx може виконувати роль балансувальника без HAProxy. Конфігурація використовує блок `upstream`:

```nginx
# /etc/nginx/sites-available/lb.conf

upstream web_backends {
    # Алгоритм (оберіть один):
    # round robin — за замовчуванням, не вказується
    least_conn;           # або: least connections
    # ip_hash;            # або: ip hash
    # hash $uri consistent; # або: url hash

    server 11.203.X.30:8080 weight=1;
    server 11.203.X.31:8080 weight=1;
    
    # Параметри:
    # weight=N     — вага сервера (за замовчуванням 1)
    # max_fails=3  — після 3 невдач сервер вважається недоступним
    # fail_timeout=30s — на 30 секунд вивести з ротації
    # backup       — резервний (використовується якщо всі основні DOWN)
    # down         — примусово позначити як недоступний
}

server {
    listen 80;
    server_name lb.surname.tsa243.lab;

    location / {
        proxy_pass         http://web_backends;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        
        # Таймаути
        proxy_connect_timeout  5s;
        proxy_send_timeout     30s;
        proxy_read_timeout     30s;
    }
}
```

---

### 3.4 Порівняння HAProxy vs Nginx як балансувальника

| Критерій | HAProxy | Nginx |
|----------|---------|-------|
| **Основна роль** | Балансувальник / проксі | Веб-сервер / проксі |
| **Продуктивність** | Вища при L7 балансуванні | Висока, але поступається HAProxy |
| **ACL та маршрутизація** | Потужна (path, header, method, cookie) | Базова (location blocks) |
| **Статистика** | Вбудована панель `/stats` | Тільки через nginx-plus або stub_status |
| **Health check** | HTTP з перевіркою тіла відповіді | Базовий TCP/HTTP (пасивний за замовчуванням) |
| **Sticky sessions** | Cookie-based, IP hash, URI hash | IP hash |
| **SSL/TLS** | Підтримується | Підтримується + SSL-offloading |
| **Serving static** | Ні | Так |
| **Типовий кейс** | Dedicated load balancer | Web server + basic LB |

**Коли HAProxy кращий:**
- Потрібна детальна статистика і моніторинг
- Складна маршрутизація за ACL
- Продуктивність — тисячі з'єднань на секунду
- Потрібен HTTP health check з перевіркою тіла

**Коли Nginx достатньо:**
- Простий round robin між 2-3 backend-ами
- Nginx вже є в ролі веб-сервера / TLS-термінатора
- Не потрібні розширені можливості HAProxy

> У нашому проекті ми використовуємо **обидва**: Nginx як TLS-термінатор і проксі, HAProxy як спеціалізований балансувальник — це типова продакшн-архітектура.

---

### 3.5 Управління HAProxy

```bash
# Встановлення
sudo apt install haproxy

# Перевірка конфігурації (обов'язково перед перезапуском!)
sudo haproxy -c -f /etc/haproxy/haproxy.cfg

# Управління сервісом
sudo systemctl start   haproxy
sudo systemctl stop    haproxy
sudo systemctl restart haproxy
sudo systemctl reload  haproxy   # Graceful reload без перерви трафіку
sudo systemctl status  haproxy

# Журнали
sudo journalctl -u haproxy -f
sudo tail -f /var/log/haproxy.log
```

**Різниця між restart та reload:**

| Команда | Що відбувається | Вплив на трафік |
|---------|-----------------|-----------------|
| `restart` | Зупиняє та запускає новий процес | Короткий downtime |
| `reload` | Новий процес перехоплює сокет, старий завершує активні з'єднання | Zero downtime |

> У продакшні **завжди** використовуйте `reload`. У навчальному середовищі — обидва варіанти допустимі.

---

### 3.6 Управління Nginx upstream

```bash
# Перевірка конфігурації
sudo nginx -t

# Graceful reload (без перерви з'єднань)
sudo systemctl reload nginx

# Журнали
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

**Тимчасово вивести backend з ротації** (без редагування конфігу):
```nginx
upstream web_backends {
    server 11.203.X.30:8080;
    server 11.203.X.31:8080 down;  # ← позначаємо як down
}
```

---

## Підсумок заняття

### Що вивчили

| Тема | Ключові поняття |
|------|----------------|
| Балансування навантаження | Горизонтальне масштабування, high availability, SPOF |
| Алгоритми | Round Robin, Weighted, Least Conn, IP Hash, URL Hash |
| Health Check | TCP, HTTP, content check; fall/rise порогові значення |
| Рівні OSI | L4 (TCP) vs L7 (HTTP) — різні можливості й overhead |
| Проксі | Forward, Reverse, Transparent — кожен для своєї задачі |
| Заголовки | X-Real-IP, X-Forwarded-For — збереження IP клієнта |
| HAProxy | global / defaults / frontend / backend / listen |
| Nginx upstream | upstream {} блок, алгоритми, weight, backup |

### Архітектурний висновок

```
ЗАДАЧА               ІНСТРУМЕНТ
─────────────────────────────────────────────────
TLS-термінація    →  Nginx
Static files      →  Nginx
HTTP балансування →  HAProxy або Nginx
TCP балансування  →  HAProxy (mode tcp)
Моніторинг LB     →  HAProxy stats + Prometheus
```

### До наступної практичної роботи

На практичному занятті (lesson9_2) потрібно:

1. Підняти два backend-сервери на `11.203.X.30:8080` і `11.203.X.31:8080`
2. Налаштувати HAProxy на `11.203.X.13` з алгоритмом `roundrobin`
3. Налаштувати Nginx на `11.203.X.12` для проксювання до HAProxy
4. Перевірити балансування: `for i in {1..6}; do curl -s http://surname.tsa243.lab/; done`
5. Переключити алгоритм на `leastconn` і порівняти поведінку
6. Вимкнути один backend — переконатись що health check виводить його з ротації

---

## Контрольні запитання

1. Що таке SPOF і як балансування навантаження вирішує цю проблему?
2. Який алгоритм балансування найкраще підходить для long-lived з'єднань (WebSocket, файловий upload)? Чому?
3. У чому принципова різниця між forward і reverse proxy? Наведіть приклад застосування кожного.
4. Навіщо потрібні заголовки `X-Forwarded-For` і `X-Real-IP`? Що відбувається якщо їх не виставляти?
5. Що таке health check і які рівні перевірки існують? Що означають параметри `fall 3` і `rise 2`?
6. Чому в нашій архітектурі два рівні Nginx (викладача і курсанта), а не один?
7. В чому різниця між `systemctl restart haproxy` та `systemctl reload haproxy`? Коли важливо використовувати `reload`?
8. Порівняйте HAProxy і Nginx як балансувальники. Коли доцільно використовувати кожен?
