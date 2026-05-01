# Змістовний модуль 7. Адміністрування серверів та балансування навантаження
## ЗАНЯТТЯ 4 (Групове) — Основи налаштування веб-сервера Apache

> **Дисципліна:** Технології Системного Адміністрування | **Курс:** 2-й  
> **ОС:** Ubuntu Server 24.04 LTS | **Тип заняття:** Групове  
> **Середовище:** Proxmox VE · підмережа курсанта `11.203.X.0/25`

---

## Навчальні питання

1. [Типи серверів](#1-типи-серверів)
2. [Огляд веб-сервера Apache та його конфігураційних файлів](#2-огляд-apache-та-конфігураційних-файлів)
3. [Налаштування віртуальних хостів в Apache](#3-налаштування-віртуальних-хостів)

---

## 1. Типи серверів

**Сервер** — програмне або апаратне забезпечення, що надає сервіси клієнтам за моделлю клієнт-сервер.

### Класифікація за призначенням

| Тип сервера | Призначення | Приклади ПЗ |
|-------------|-------------|-------------|
| **Веб-сервер** | Обслуговує HTTP/HTTPS запити, роздає статичний контент | Apache, Nginx, IIS |
| **Сервер застосунків** | Виконує бізнес-логіку, динамічний контент | Tomcat, Gunicorn, uWSGI |
| **Файловий сервер** | Спільний доступ до файлів у мережі | Samba, NFS, FTP |
| **Поштовий сервер** | Приймання та відправлення електронної пошти | Postfix, Dovecot, Exim |
| **DNS-сервер** | Перетворення доменних імен на IP-адреси | BIND9, Unbound |
| **Проксі-сервер** | Посередник між клієнтом і сервером, кешування | Nginx, Squid, HAProxy |
| **Сервер баз даних** | Зберігання та обробка структурованих даних | PostgreSQL, MySQL, SQLite |

### Веб-сервер vs Сервер застосунків

```
Клієнт (браузер)
      │
      ▼ HTTP запит
 Веб-сервер (Apache/Nginx)
      │
      ├── Статичний файл (HTML, CSS, JS, зображення)?
      │   └── Відповідь одразу ──────────────────────► Клієнт
      │
      └── Динамічний запит (PHP, Python...)?
          └──► Сервер застосунків (PHP-FPM, Gunicorn)
                    └── Відповідь ──► Веб-сервер ──► Клієнт
```

> Apache може бути одночасно веб-сервером і сервером застосунків — через модулі
> `mod_php`, `mod_wsgi`. Nginx — виключно веб-сервер та проксі.

---

## 2. Огляд Apache та конфігураційних файлів

**Apache HTTP Server (httpd)** — найпоширеніший веб-сервер у світі з 1996 року.
Модульна архітектура дозволяє вмикати та вимикати функціональність без перекомпіляції.

### Архітектура Apache

```
                    ┌──────────────────────────────┐
                    │          Apache httpd         │
                    │                              │
  HTTP запит ──────►│  MPM (Multi-Processing Module)│
                    │  ┌──────────┐ ┌────────────┐ │
                    │  │ prefork  │ │   worker   │ │
                    │  │(процеси) │ │ (потоки)   │ │
                    │  └──────────┘ └────────────┘ │
                    │                              │
                    │  Модулі: mod_rewrite,        │
                    │  mod_ssl, mod_proxy,         │
                    │  mod_php, mod_headers...     │
                    └──────────────────────────────┘
```

### Структура конфігураційних файлів

```
/etc/apache2/
├── apache2.conf            ← головний конфіг (глобальні параметри)
├── ports.conf              ← порти прослуховування (Listen 80, Listen 443)
├── envvars                 ← змінні середовища (APACHE_RUN_USER тощо)
│
├── mods-available/         ← всі доступні модулі
│   ├── rewrite.load
│   ├── ssl.load
│   └── ...
├── mods-enabled/           ← символічні посилання на увімкнені модулі
│   └── rewrite.load -> ../mods-available/rewrite.load
│
├── sites-available/        ← всі описані віртуальні хости
│   ├── 000-default.conf    ← дефолтний vhost (port 80)
│   └── default-ssl.conf    ← дефолтний vhost (port 443)
├── sites-enabled/          ← символічні посилання на активні vhost
│   └── 000-default.conf -> ../sites-available/000-default.conf
│
└── conf-available/         ← додаткові конфіги
    └── conf-enabled/
```

> Принцип `*-available` / `*-enabled` — конфіг є, але не активний доки немає
> символічного посилання у `*-enabled`. Утиліти `a2ensite`, `a2dissite`,
> `a2enmod`, `a2dismod` керують цими посиланнями автоматично.

### Ключові директиви apache2.conf

| Директива | Призначення | Приклад |
|-----------|-------------|---------|
| `ServerName` | Ім'я сервера за замовчуванням | `ServerName tsa243.lab` |
| `ServerAdmin` | Email адміністратора | `ServerAdmin admin@tsa243.lab` |
| `DocumentRoot` | Директорія з файлами сайту | `DocumentRoot /var/www/html` |
| `ErrorLog` | Файл журналу помилок | `ErrorLog ${APACHE_LOG_DIR}/error.log` |
| `CustomLog` | Файл журналу доступу | `CustomLog ... combined` |
| `Directory` | Налаштування для директорії | `<Directory /var/www/html>` |
| `AllowOverride` | Чи дозволено `.htaccess` | `AllowOverride All` |

---

## 3. Налаштування віртуальних хостів

**Virtual Host (vhost)** — механізм, що дозволяє одному Apache-серверу обслуговувати
кілька доменів з одної IP-адреси. Сервер розрізняє сайти за заголовком `Host:` у HTTP-запиті.

### Топологія заняття

```
┌─────────────────────────────────────────────────────┐
│           Середовище курсанта  11.203.X.0/25         │
│                                                     │
│   11.203.X.20  ← Workstation (Apache httpd)         │
│                   surname.tsa243.lab     → /var/www/main
│                   dev.surname.tsa243.lab → /var/www/dev
│                                                     │
│   11.203.X.10  ← DNS курсанта (BIND9)               │
│                   A-записи для обох доменів         │
└─────────────────────────────────────────────────────┘
```

---

### Крок 1 — Встановлення Apache

```bash
sudo apt update
sudo apt install apache2 -y

# Перевірити статус
sudo systemctl status apache2

# Переконатись що відповідає
curl http://localhost
```

Відкрити у браузері: `http://11.203.X.20` — має з'явитись сторінка "Apache2 Ubuntu Default Page".

---

### Крок 2 — Огляд конфігурації

```bash
# Переглянути головний конфіг
cat /etc/apache2/apache2.conf

# Які модулі увімкнено
ls /etc/apache2/mods-enabled/

# Які порти прослуховуються
cat /etc/apache2/ports.conf

# Дефолтний vhost
cat /etc/apache2/sites-available/000-default.conf

# Де зберігаються логи
ls /var/log/apache2/
tail -20 /var/log/apache2/access.log
tail -20 /var/log/apache2/error.log
```

---

### Крок 3 — Перший віртуальний хост: `surname.tsa243.lab`

#### 3.1 Створити директорію і тестову сторінку

```bash
# Замінити surname на своє прізвище
sudo mkdir -p /var/www/main
sudo chown -R $USER:$USER /var/www/main

cat <<EOF | sudo tee /var/www/main/index.html
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>surname.tsa243.lab</title></head>
<body>
  <h1>surname.tsa243.lab</h1>
  <p>Основний сайт курсанта. Apache Virtual Host.</p>
  <p>Сервер: <strong>11.203.X.20</strong></p>
</body>
</html>
EOF
```

#### 3.2 Створити конфіг віртуального хосту

```bash
sudo nano /etc/apache2/sites-available/surname.tsa243.lab.conf
```

```apacheconf
<VirtualHost *:80>
    ServerName   surname.tsa243.lab
    ServerAlias  www.surname.tsa243.lab
    ServerAdmin  surname@tsa243.lab

    DocumentRoot /var/www/main

    <Directory /var/www/main>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog  ${APACHE_LOG_DIR}/surname-error.log
    CustomLog ${APACHE_LOG_DIR}/surname-access.log combined
</VirtualHost>
```

#### 3.3 Увімкнути сайт

```bash
sudo a2ensite surname.tsa243.lab.conf
sudo apache2ctl configtest          # має вивести: Syntax OK
sudo systemctl reload apache2
```

---

### Крок 4 — Другий віртуальний хост: `dev.surname.tsa243.lab`

#### 4.1 Створити директорію і сторінку

```bash
sudo mkdir -p /var/www/dev
sudo chown -R $USER:$USER /var/www/dev

cat <<EOF | sudo tee /var/www/dev/index.html
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>DEV — surname.tsa243.lab</title></head>
<body style="background:#1a1a2e; color:#eee; font-family:monospace; padding:2rem">
  <h1>dev.surname.tsa243.lab</h1>
  <p>Тестове середовище. Не для production.</p>
</body>
</html>
EOF
```

#### 4.2 Створити конфіг

```bash
sudo nano /etc/apache2/sites-available/dev.surname.tsa243.lab.conf
```

```apacheconf
<VirtualHost *:80>
    ServerName  dev.surname.tsa243.lab
    ServerAdmin surname@tsa243.lab

    DocumentRoot /var/www/dev

    <Directory /var/www/dev>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog  ${APACHE_LOG_DIR}/dev-surname-error.log
    CustomLog ${APACHE_LOG_DIR}/dev-surname-access.log combined
</VirtualHost>
```

#### 4.3 Увімкнути сайт

```bash
sudo a2ensite dev.surname.tsa243.lab.conf
sudo apache2ctl configtest
sudo systemctl reload apache2
```

---

### Крок 5 — Додати DNS-записи

На VM з DNS курсанта (`11.203.X.10`) додати A-записи у зону `surname.tsa243.lab`:

```bash
sudo nano /etc/bind/db.surname.tsa243.lab
```

```bind
; Додати рядки:
dev     IN  A  11.203.X.20
www     IN  A  11.203.0.12   ; через proxy викладача
```

```bash
sudo named-checkzone surname.tsa243.lab /etc/bind/db.surname.tsa243.lab
sudo rndc reload surname.tsa243.lab
```

---

### Крок 6 — Перевірка роботи

```bash
# З workstation курсанта
curl -H "Host: surname.tsa243.lab" http://11.203.X.20
curl -H "Host: dev.surname.tsa243.lab" http://11.203.X.20

# Через DNS (якщо записи налаштовані)
curl http://surname.tsa243.lab
curl http://dev.surname.tsa243.lab

# Переконатись що обидва vhost активні
sudo apache2ctl -S

# Журнали в реальному часі
sudo tail -f /var/log/apache2/surname-access.log
```

Очікуваний вивід `apache2ctl -S`:
```
VirtualHost configuration:
*:80   surname.tsa243.lab (/etc/apache2/sites-enabled/surname.tsa243.lab.conf)
*:80   dev.surname.tsa243.lab (/etc/apache2/sites-enabled/dev.surname.tsa243.lab.conf)
```

---

## Завдання на самопідготовку

1. Вимкнути дефолтний vhost `000-default` і переконатись що відкривається твій основний сайт.
2. Налаштувати сторінку помилки 404 для свого vhost:
   ```apacheconf
   ErrorDocument 404 /404.html
   ```
3. Увімкнути модуль `mod_rewrite` і додати редирект з `http://` на `https://` (підготовка до TLS).
4. Додати заголовок `X-Powered-By: surname` до відповідей через `mod_headers`.
5. Обмежити доступ до `dev.surname.tsa243.lab` тільки з підмережі `11.203.X.0/25`.

---

## Корисні команди

```bash
# Керування сервісом
sudo systemctl start|stop|restart|reload apache2
sudo systemctl enable apache2           # автозапуск

# Управління сайтами та модулями
sudo a2ensite  <конфіг>                 # увімкнути vhost
sudo a2dissite <конфіг>                 # вимкнути vhost
sudo a2enmod   <модуль>                 # увімкнути модуль
sudo a2dismod  <модуль>                 # вимкнути модуль

# Перевірка
sudo apache2ctl configtest              # перевірити синтаксис конфігів
sudo apache2ctl -S                      # список активних vhost і портів
sudo apache2ctl -M                      # список увімкнених модулів

# Логи
tail -f /var/log/apache2/error.log
tail -f /var/log/apache2/access.log
journalctl -u apache2 -f

# Діагностика
curl -I http://surname.tsa243.lab       # заголовки відповіді
curl -v http://surname.tsa243.lab       # детальний вивід
ss -tlnp | grep apache2                 # який порт слухає
```
