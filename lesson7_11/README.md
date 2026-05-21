# Змістовний модуль 7. Адміністрування серверів та балансування навантаження
## ЗАНЯТТЯ 7_11 (Практичне) — Налаштування Nginx для зворотного проксі та балансування навантаження

> **Дисципліна:** Технології Системного Адміністрування | **Курс:** 2-й  
> **ОС:** Ubuntu Server 24.04 LTS | **Тип заняття:** Практичне  
> **Середовище:** Proxmox VE · підмережа курсанта `11.203.X.0/25`  
> **Час виконання:** ~90 хвилин  
> **Попередні заняття:** lesson7_10 (HAProxy), lesson7_7 (Nginx Virtual Hosts)

---

## Навчальне питання

1. [Налаштування Nginx для зворотного проксі та балансування навантаження](#питання-1--nginx-reverse-proxy--load-balancer)

---

## Середовище заняття

| VM | Адреса | Роль |
|----|--------|------|
| Nginx VM | `11.203.X.12` | Reverse proxy + балансувальник |
| Backend-01 | `11.203.X.30` | HTTP backend, порт 8080 |
| Backend-02 | `11.203.X.31` | HTTP backend, порт 8080 |

> Замінюйте `X` на номер вашого варіанта, `surname` — на ваше прізвище латинкою.

> Backend-сервери вже підняті у lesson7_10 (Nginx на порту 8080 з ендпоінтом `/health`). Якщо виконуєте це заняття окремо — повторіть Крок 1 з lesson7_10.

**Що робимо на цьому занятті:**

У lesson7_10 Nginx на `.12` просто передавав трафік до HAProxy на `.13`. Сьогодні **прибираємо HAProxy з ланцюжку** і налаштовуємо Nginx безпосередньо як балансувальник між двома backend-ами. Це показує, що Nginx здатний виконувати роль балансувальника без окремого інструменту.

```
До (lesson7_10):
Client → Nginx (11.203.X.12) → HAProxy (11.203.X.13) → backend-01 / backend-02

Після (це заняття):
Client → Nginx (11.203.X.12) ─┬─▶ backend-01 (11.203.X.30:8080)
                               └─▶ backend-02 (11.203.X.31:8080)
```

---

# Питання 1 — Nginx: Reverse Proxy + Load Balancer

## Крок 1 — Перевірка backend-серверів

> Виконується на **Nginx VM (11.203.X.12)**

Перш ніж налаштовувати балансування — переконайтеся, що обидва backend-и доступні:

```bash
curl -s http://11.203.X.30:8080/health
curl -s http://11.203.X.31:8080/health
```

Обидві команди мають повернути `OK`. Якщо ні — перевірте Nginx на backend-VM (lesson7_10, Крок 1).

---

## Крок 2 — Upstream блок: Round Robin

> Виконується на **Nginx VM (11.203.X.12)**

Nginx використовує директиву `upstream` для опису групи backend-серверів. Блок `upstream` оголошується **поза** блоком `server` і потім використовується у `proxy_pass`.

Створіть новий конфіг:

```bash
sudo nano /etc/nginx/sites-available/lb.conf
```

```nginx
# Група backend-серверів
upstream web_backends {
    # Round Robin — алгоритм за замовчуванням, не потребує явного оголошення
    server 11.203.X.30:8080;
    server 11.203.X.31:8080;
}

server {
    listen 80;
    server_name surname.tsa243.lab;

    server_tokens off;

    access_log /var/log/nginx/lb.access.log;
    error_log  /var/log/nginx/lb.error.log;

    location / {
        proxy_pass         http://web_backends;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;

        proxy_connect_timeout  5s;
        proxy_read_timeout     30s;
    }
}
```

Деактивуйте старий конфіг (якщо є) і активуйте новий:

```bash
# Видалити попередній конфіг proxy.conf, якщо був активований
sudo rm -f /etc/nginx/sites-enabled/proxy.conf

# Активувати новий
sudo ln -s /etc/nginx/sites-available/lb.conf /etc/nginx/sites-enabled/

# Перевірити синтаксис
sudo nginx -t
```

Очікуваний вивід:
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

```bash
sudo systemctl reload nginx
```

### Перевірка Round Robin:

```bash
for i in {1..6}; do
    curl -s http://11.203.X.12/ | grep -o 'BACKEND-[0-9]*'
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

---

## Крок 3 — Weighted Round Robin

Якщо backend-сервери мають різну потужність — призначте ваги. Сервер з вагою `2` отримає вдвічі більше запитів.

```bash
sudo nano /etc/nginx/sites-available/lb.conf
```

Змініть блок `upstream`:

```nginx
upstream web_backends {
    server 11.203.X.30:8080 weight=2;   # отримує 2/3 запитів
    server 11.203.X.31:8080 weight=1;   # отримує 1/3 запитів
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### Перевірка розподілу:

```bash
for i in {1..9}; do
    curl -s http://11.203.X.12/ | grep -o 'BACKEND-[0-9]*'
done
```

Очікуваний вивід: приблизно 6 відповідей від BACKEND-01 і 3 від BACKEND-02.

```bash
# Підрахувати статистику
for i in {1..9}; do curl -s http://11.203.X.12/ | grep -o 'BACKEND-[0-9]*'; done | sort | uniq -c
```

Очікуваний вивід:
```
6 BACKEND-01
3 BACKEND-02
```

Поверніть рівну вагу перед наступним кроком:

```bash
sudo nano /etc/nginx/sites-available/lb.conf
# Видалити weight або поставити weight=1 для обох
sudo nginx -t && sudo systemctl reload nginx
```

---

## Крок 4 — Least Connections

Алгоритм `least_conn` направляє запит до сервера з найменшою кількістю активних з'єднань. Ефективний для запитів з різним часом обробки.

```bash
sudo nano /etc/nginx/sites-available/lb.conf
```

Додайте директиву `least_conn` першим рядком у блоці `upstream`:

```nginx
upstream web_backends {
    least_conn;
    server 11.203.X.30:8080;
    server 11.203.X.31:8080;
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx

for i in {1..6}; do
    curl -s http://11.203.X.12/ | grep -o 'BACKEND-[0-9]*'
done
```

> При коротких статичних відповідях розподіл виглядає як round robin. Різниця помітна при тривалих запитах — backend з повільним обробником отримує менше нових запитів.

---

## Крок 5 — IP Hash (Sticky Sessions)

Алгоритм `ip_hash` гарантує, що запити від одного IP-клієнта завжди потрапляють на один і той самий backend.

```bash
sudo nano /etc/nginx/sites-available/lb.conf
```

```nginx
upstream web_backends {
    ip_hash;
    server 11.203.X.30:8080;
    server 11.203.X.31:8080;
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx

# З одного IP — завжди той самий backend
for i in {1..6}; do
    curl -s http://11.203.X.12/ | grep -o 'BACKEND-[0-9]*'
done
```

Очікуваний вивід (один і той самий backend для вашого IP):
```
BACKEND-01
BACKEND-01
BACKEND-01
BACKEND-01
BACKEND-01
BACKEND-01
```

> IP-адреса вашої робочої станції хешується і завжди дає той самий результат. Інший клієнт з іншим IP може потрапити на backend-02.

Поверніть round robin для подальшої роботи:

```bash
sudo nano /etc/nginx/sites-available/lb.conf
# Видалити ip_hash
sudo nginx -t && sudo systemctl reload nginx
```

---

## Крок 6 — Passive Health Check та параметри відмовостійкості

Nginx (без комерційної версії Nginx Plus) виконує **пасивний** health check: сервер вважається недоступним після N послідовних невдалих спроб з'єднання.

Параметри додаються безпосередньо до директиви `server` у блоці `upstream`:

```nginx
upstream web_backends {
    server 11.203.X.30:8080 max_fails=3 fail_timeout=30s;
    server 11.203.X.31:8080 max_fails=3 fail_timeout=30s;
}
```

| Параметр | Значення | Опис |
|----------|----------|------|
| `max_fails=3` | 3 | Після 3 невдалих з'єднань — сервер вважається недоступним |
| `fail_timeout=30s` | 30 секунд | На 30 секунд виключити з ротації; потім спробувати знову |

```bash
sudo nano /etc/nginx/sites-available/lb.conf
```

```nginx
upstream web_backends {
    server 11.203.X.30:8080 max_fails=3 fail_timeout=30s;
    server 11.203.X.31:8080 max_fails=3 fail_timeout=30s;
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### Тест пасивного health check:

```bash
# Зупинити backend-01
# На Backend-01 VM (11.203.X.30):
sudo systemctl stop nginx
```

```bash
# На Nginx VM (11.203.X.12) — спостерігати за поведінкою
# Перші 3 запити до backend-01 провалюються, далі Nginx виключає його
for i in {1..8}; do
    curl -s --max-time 3 http://11.203.X.12/ | grep -o 'BACKEND-[0-9]*'
done
```

> На відміну від HAProxy, Nginx не проводить окремих перевірок. Він дізнається про відмову лише коли реальний запит клієнта не проходить. Тому перші 1-3 запити можуть повернути помилку або затримку перед тим як backend виключиться.

```bash
# Відновити backend-01
# На Backend-01 VM (11.203.X.30):
sudo systemctl start nginx
```

Після `fail_timeout` (30 секунд) Nginx автоматично повернe backend-01 у ротацію.

### Порівняння з HAProxy:

| Критерій | Nginx (пасивний) | HAProxy (активний) |
|----------|------------------|--------------------|
| Як дізнається про відмову | Реальний запит клієнта провалюється | Окремий health check запит |
| Перші помилки | Клієнт може отримати помилку | Клієнт не отримує помилки |
| Налаштування | `max_fails`, `fail_timeout` | `fall`, `rise`, `inter` |
| Швидкість реакції | Залежить від трафіку | Фіксований інтервал (напр. 2с) |

---

## Крок 7 — Резервний сервер

Параметр `backup` позначає сервер як резервний — він отримує трафік лише коли всі основні сервери недоступні.

```bash
sudo nano /etc/nginx/sites-available/lb.conf
```

```nginx
upstream web_backends {
    server 11.203.X.30:8080 max_fails=3 fail_timeout=30s;
    server 11.203.X.31:8080 max_fails=3 fail_timeout=30s;
    server 11.203.X.32:8080 backup;    # резервний (якщо .32 існує)
}
```

> Якщо VM на `.32` відсутня — залиште рядок з `backup` закоментованим (`#`). Nginx ігнорує недоступний backup при наявності хоча б одного робочого основного сервера.

---

## Крок 8 — Маршрутизація за URL (розподіл по location)

Nginx може направляти різні URL до різних груп backend-ів безпосередньо через блоки `location`, без ACL:

```bash
sudo nano /etc/nginx/sites-available/lb.conf
```

```nginx
# API-backend — лише backend-01 (наприклад, там є БД)
upstream api_backends {
    server 11.203.X.30:8080;
}

# Статичний контент — лише backend-02
upstream static_backends {
    server 11.203.X.31:8080;
}

# Основний пул — обидва
upstream web_backends {
    server 11.203.X.30:8080;
    server 11.203.X.31:8080;
}

server {
    listen 80;
    server_name surname.tsa243.lab;

    server_tokens off;

    access_log /var/log/nginx/lb.access.log;
    error_log  /var/log/nginx/lb.error.log;

    # /api/ → тільки backend-01
    location /api/ {
        proxy_pass       http://api_backends;
        proxy_set_header Host            $host;
        proxy_set_header X-Real-IP       $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # /static/ → обслуговуємо безпосередньо з диску
    location /static/ {
        root /var/www/surname;
        expires 7d;
    }

    # Решта → балансувати між обома
    location / {
        proxy_pass         http://web_backends;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;

        proxy_connect_timeout  5s;
        proxy_read_timeout     30s;
    }
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### Перевірка маршрутизації:

```bash
# Запит до /api/ — завжди backend-01
for i in {1..4}; do
    curl -s http://11.203.X.12/api/ | grep -o 'BACKEND-[0-9]*'
done
```

Очікуваний вивід (тільки backend-01):
```
BACKEND-01
BACKEND-01
BACKEND-01
BACKEND-01
```

```bash
# Запит до / — чергуються обидва
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

---

## Крок 9 — Кешування відповідей backend

Nginx може кешувати відповіді backend-серверів і віддавати їх клієнтам без звернення до backend. Це знижує навантаження на backend і прискорює відповідь.

```bash
sudo nano /etc/nginx/sites-available/lb.conf
```

Додайте директиву `proxy_cache_path` **перед** блоком `server` (в контексті `http` — тобто на початку файлу):

```nginx
# Оголошення кеш-зони (розміщується перед блоком server)
proxy_cache_path /var/cache/nginx/lb
    levels=1:2
    keys_zone=lb_cache:10m
    max_size=100m
    inactive=10m
    use_temp_path=off;

upstream web_backends {
    server 11.203.X.30:8080 max_fails=3 fail_timeout=30s;
    server 11.203.X.31:8080 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name surname.tsa243.lab;

    server_tokens off;

    access_log /var/log/nginx/lb.access.log;
    error_log  /var/log/nginx/lb.error.log;

    location / {
        proxy_pass         http://web_backends;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;

        # Кешування
        proxy_cache        lb_cache;
        proxy_cache_valid  200 1m;     # Кешувати 200-відповіді на 1 хвилину
        proxy_cache_valid  404 10s;    # Кешувати 404 на 10 секунд
        proxy_cache_use_stale error timeout updating;  # Відповідати з кешу при помилці backend

        # Додати заголовок, щоб бачити HIT або MISS
        add_header X-Cache-Status $upstream_cache_status;

        proxy_connect_timeout  5s;
        proxy_read_timeout     30s;
    }
}
```

Створіть директорію кешу:

```bash
sudo mkdir -p /var/cache/nginx/lb
sudo chown www-data:www-data /var/cache/nginx/lb

sudo nginx -t && sudo systemctl reload nginx
```

### Перевірка кешування:

```bash
# Перший запит — MISS (кешу ще немає)
curl -s -I http://11.203.X.12/ | grep -i "x-cache"
```

Очікуваний вивід:
```
X-Cache-Status: MISS
```

```bash
# Другий запит — HIT (відповідь з кешу, backend не звертається)
curl -s -I http://11.203.X.12/ | grep -i "x-cache"
```

Очікуваний вивід:
```
X-Cache-Status: HIT
```

```bash
# При HIT — обидва запити повертають той самий backend (кеш однієї відповіді)
for i in {1..4}; do
    curl -s http://11.203.X.12/ | grep -o 'BACKEND-[0-9]*'
    sleep 0.2
done
```

> Зверніть увагу: при кешуванні балансування зупиняється — клієнт отримує одну й ту саму закешовану відповідь. Кешування застосовують лише для статичного або повільно змінного контенту.

---

## Крок 10 — Підсумкова конфігурація без кешу

Для фінального варіанту заняття поверніть конфіг без кешування — чистий балансувальник з маршрутизацією:

```bash
sudo nano /etc/nginx/sites-available/lb.conf
```

```nginx
upstream web_backends {
    server 11.203.X.30:8080 max_fails=3 fail_timeout=30s;
    server 11.203.X.31:8080 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name surname.tsa243.lab;

    server_tokens off;

    access_log /var/log/nginx/lb.access.log;
    error_log  /var/log/nginx/lb.error.log;

    location / {
        proxy_pass         http://web_backends;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;

        proxy_connect_timeout  5s;
        proxy_read_timeout     30s;
    }

    location /static/ {
        root /var/www/surname;
        expires 7d;
    }

    location /health {
        return 200 "surname.tsa243.lab OK\n";
        add_header Content-Type text/plain;
    }
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### Підсумкова перевірка:

```bash
# Балансування між backend-ами
for i in {1..6}; do
    curl -s http://11.203.X.12/ | grep -o 'BACKEND-[0-9]*'
done

# Health check самого Nginx
curl -s http://11.203.X.12/health
```

---

## Звіт про виконання роботи

| № | Команда / дія | Що демонструє |
|---|--------------|---------------|
| 1 | `sudo nginx -t` | Конфіг валідний |
| 2 | `for i in {1..6}; do curl -s http://11.203.X.12/ \| grep -o 'BACKEND-[0-9]*'; done` | Round Robin між двома backend-ами |
| 3 | Змінити на `weight=2 / weight=1`, 9 запитів + `sort \| uniq -c` | Weighted: 6 vs 3 |
| 4 | Змінити на `ip_hash`, 6 запитів | Sticky: завжди один backend |
| 5 | `sudo systemctl stop nginx` на backend-01 → 6 запитів → `start` | Пасивний health check: перемикання на backend-02 |
| 6 | `curl -s -I http://11.203.X.12/ \| grep X-Cache` (MISS потім HIT) | Кешування відповідей |

---

## Порівняння: Nginx vs HAProxy як балансувальник

| Критерій | Nginx | HAProxy |
|----------|-------|---------|
| Алгоритми | round robin, weighted, least_conn, ip_hash | round robin, weighted, least conn, source, uri |
| Health check | Пасивний (без Nginx Plus) | Активний HTTP/TCP з перевіркою тіла |
| Статистика | Відсутня (тільки `stub_status` — лічильники) | Повна панель `/stats` |
| Кешування | Так (`proxy_cache`) | Ні |
| Static files | Так | Ні |
| Маршрутизація | `location` блоки | ACL |
| URL hash | `hash $uri consistent` | `balance uri` |
| Підходить для | Веб-сервер + базове балансування | Dedicated L7 балансувальник |

---

## Типові помилки та вирішення

| Помилка | Причина | Вирішення |
|---------|---------|-----------|
| `upstream` не знайдено | Блок `upstream` у неправильному місці | `upstream` має бути в контексті `http`, не всередині `server` |
| `502 Bad Gateway` | Backend не запущено або неправильна адреса | `curl http://11.203.X.30:8080/` з Nginx VM |
| `connect() failed (111: Connection refused)` у логах | Backend відхиляє з'єднання | Перевірити порт: `sudo ss -tulnp \| grep 8080` на backend VM |
| `proxy_cache_path` — директива в `server` | `proxy_cache_path` тільки в `http` контексті | Перемістити директиву перед блок `server` |
| Після `fail_timeout` backend не повертається | Ще не минуло 30 секунд | Зменшити `fail_timeout=10s` для тестування |
| `ip_hash` — всі запити на один backend | Це нормально, якщо ваш IP завжди один | Перевірити з іншого IP |

---

## Корисні команди — шпаргалка

```bash
sudo nginx -t                                 # Перевірити синтаксис (завжди перед reload!)
sudo systemctl reload nginx                   # Застосувати зміни без downtime
sudo nginx -T | grep -A5 "upstream"          # Переглянути всі upstream-групи

# Логи в реальному часі
sudo tail -f /var/log/nginx/lb.access.log

# Перевірити розподіл запитів
for i in {1..10}; do curl -s http://11.203.X.12/ | grep -o 'BACKEND-[0-9]*'; done | sort | uniq -c

# Моніторинг з оновленням
watch -n 1 'for i in {1..3}; do curl -s http://11.203.X.12/ | grep -o "BACKEND-[0-9]*"; done'
```

---

## Структура проєкту на GitHub

```
lesson7_11/
└── README.md       ← Ця методичка
```

---

> Матеріал підготовлено для навчальних занять ВІТІ.  
> Дисципліна: Технології Системного Адміністрування | Курс 2-й | 2026
