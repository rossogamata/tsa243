# Nginx — дворівнева архітектура

---

## Рівень 1 — Центральний reverse proxy викладача `11.203.0.12`

Єдина точка входу для всієї мережі `tsa243.lab`.
Приймає HTTP/HTTPS запити і проксує їх до Nginx відповідного курсанта.

### Vhost для кожного курсанта

```nginx
# /etc/nginx/sites-available/surname.tsa243.lab
server {
    listen 80;
    server_name surname.tsa243.lab www.surname.tsa243.lab;

    location / {
        proxy_pass         http://11.203.X.12;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    }
}
```

Викладач додає цей блок для кожного курсанта після того як курсант:
1. Налаштував свій DNS (A-запис вказує на `11.203.0.12`)
2. Підняв свій Nginx на `11.203.X.12`

---

## Рівень 2 — Nginx курсанта `11.203.X.12`

Приймає трафік від proxy викладача і передає до HAProxy.

```nginx
# /etc/nginx/sites-available/default
server {
    listen 80;
    server_name surname.tsa243.lab;

    # Проксуємо до HAProxy
    location / {
        proxy_pass         http://11.203.X.13;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    }

    # Статичний контент — обслуговуємо безпосередньо
    location /static/ {
        root /var/www/surname;
    }

    # Сторінка-заглушка до налаштування HAProxy
    location /health {
        return 200 "surname.tsa243.lab is alive\n";
        add_header Content-Type text/plain;
    }
}
```

---

## Повний потік

```
Client
  │  HTTP GET surname.tsa243.lab/
  ▼
proxy.tsa243.lab : 11.203.0.12   (Nginx викладача)
  │  proxy_pass → 11.203.X.12
  ▼
www.surname.tsa243.lab : 11.203.X.12   (Nginx курсанта)
  │  proxy_pass → 11.203.X.13
  ▼
lb.surname.tsa243.lab : 11.203.X.13    (HAProxy)
  │  balance roundrobin
  ├─▶ backend-01 : 11.203.X.30:8080
  └─▶ backend-02 : 11.203.X.31:8080
```

---

## Перевірка

```bash
# З workstation курсанта
curl -v http://surname.tsa243.lab/
curl -v http://surname.tsa243.lab/health

# Перевірити заголовки (X-Forwarded-For має показати реальний IP клієнта)
curl -s http://surname.tsa243.lab/ -D -

# Журнал доступу
sudo tail -f /var/log/nginx/access.log
```
