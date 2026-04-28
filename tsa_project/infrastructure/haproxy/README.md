# HAProxy — lb.surname.tsa243.lab

**VM:** `lb.surname.tsa243.lab` · `11.203.X.13`  
**Порт:** 80 (HTTP frontend)  
**Роль:** балансувальник навантаження між backend VM

---

## Потік трафіку

```
Nginx курсанта (11.203.X.12)
        │
        ▼ proxy_pass http://11.203.X.13
HAProxy (11.203.X.13:80)
        │
        ├─▶ backend-01 (11.203.X.30:8080)
        └─▶ backend-02 (11.203.X.31:8080)
```

Nginx виступає як TLS-термінатор і фронтенд.
HAProxy розподіляє HTTP-трафік між backend-серверами.

---

## Базова конфігурація `/etc/haproxy/haproxy.cfg`

```
global
    log /dev/log local0
    maxconn 1024

defaults
    log     global
    mode    http
    option  httplog
    timeout connect 5s
    timeout client  30s
    timeout server  30s

frontend http_front
    bind *:80
    default_backend web_backends

backend web_backends
    balance roundrobin
    option httpchk GET /health
    server backend01 11.203.X.30:8080 check
    server backend02 11.203.X.31:8080 check

listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
```

---

## Алгоритми балансування (вивчаємо на практиці)

| Алгоритм | `balance` параметр | Коли використовувати |
|----------|--------------------|----------------------|
| Round Robin | `roundrobin` | Рівномірне розподілення, однакові сервери |
| Least Connections | `leastconn` | Різне навантаження на запит |
| Source IP Hash | `source` | Sticky sessions (той самий клієнт → той самий backend) |

---

## Перевірка стану (health check)

```bash
# Статистика HAProxy
curl http://11.203.X.13:8404/stats

# Переконатись що балансування працює (різні відповіді від backend-ів)
for i in {1..6}; do curl -s http://11.203.X.13/; echo; done
```

---

## Навчальний момент

HAProxy + два backend — перший реальний приклад горизонтального масштабування.
На наступному курсі: ті самі backend-и в Docker-контейнерах, HAProxy як точка входу.
