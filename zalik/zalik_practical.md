# ЗАЛІК — ПРАКТИЧНІ ЗАВДАННЯ (6 варіантів)
## Технології системного адміністрування | Курс 2-й | ВІТІ

> **Оцінювання:** 40 балів за практичне завдання  
> **Час виконання:** ~90 хвилин  
> **Середовище:** Ubuntu Server 24.04 LTS | Proxmox VE | підмережа `11.203.X.0/25`  
> Замінюйте `X` на номер вашого варіанта, `surname` — на ваше прізвище латинкою.

---

## ВАРІАНТ 1 — Мережева конфігурація та SSH-безпека

**Сценарій:** Потрібно налаштувати стійку мережеву конфігурацію та безпечний SSH-доступ між VM у підмережі курсанта.

---

### Завдання 1 — Налаштування статичної IP через Netplan (10 балів)

На VM `11.203.X.12`:

1. Відредагуйте конфігурацію Netplan (`/etc/netplan/*.yaml`) — налаштуйте статичну IP-адресу `11.203.X.12/25`, шлюз `11.203.X.1`, DNS-сервер `11.203.X.10`.
2. Застосуйте конфігурацію командою `sudo netplan apply`.
3. Перевірте: `ip a` показує задану адресу, `ip route` показує шлюз, `resolvectl status` показує DNS.

**Демонстрація:** виведіть результат `ip a`, `ip route`, `ping -c 3 11.203.X.10`.

---

### Завдання 2 — SSH-автентифікація за ключами (10 балів)

1. На робочій станції (`11.203.X.20`) згенеруйте ключ Ed25519: `ssh-keygen -t ed25519 -C "zalik"`.
2. Скопіюйте публічний ключ на `11.203.X.12`: `ssh-copy-id user@11.203.X.12`.
3. У файлі `/etc/ssh/sshd_config` на `11.203.X.12` вимкніть автентифікацію за паролем (`PasswordAuthentication no`) та забороніть вхід root (`PermitRootLogin no`).
4. Перевірте синтаксис конфігурації: `sudo sshd -t` (має бути без помилок).
5. Перезавантажте сервіс: `sudo systemctl reload ssh`.
6. Переконайтеся, що підключення за ключем працює, а підключення за паролем відхиляється.

**Демонстрація:** `ssh -i ~/.ssh/id_ed25519 user@11.203.X.12 "hostname && id"`.

---

### Завдання 3 — Скрипт резервного копіювання (12 балів)

Напишіть скрипт `/opt/backup.sh`, який:

1. Архівує директорію `/etc` у файл `/backup/etc-$(date +%Y-%m-%d).tar.gz`.
2. Створює директорію `/backup` якщо вона не існує.
3. Записує в syslog (`logger`) повідомлення про успіх або помилку.
4. Перевіряє код завершення `tar` (`$?`) і виходить з кодом 1 при помилці.
5. Видаляє архіви старші за 7 днів командою `find`.

Зробіть скрипт виконуваним: `chmod +x /opt/backup.sh`.  
Запустіть вручну та перевірте: `ls -lh /backup/` та `journalctl -t backup --since "1 min ago"`.

---

### Завдання 4 — Планування через cron (8 балів)

1. Налаштуйте cron для root: `sudo crontab -e` — додайте запис для запуску `/opt/backup.sh` щодня о `02:30`.
2. Перевірте через `sudo crontab -l`.
3. Налаштуйте також запис для логування аптайму системи (`uptime >> /var/log/uptime.log`) кожні 15 хвилин.

**Демонстрація:** покажіть `sudo crontab -l` з обома записами.

---

## ВАРІАНТ 2 — Apache та HTTPS

**Сценарій:** Розгорнути виробничий веб-сервер Apache з двома virtual hosts та налаштувати безпечне HTTPS-підключення.

---

### Завдання 1 — Два Apache Virtual Hosts (12 балів)

На VM `11.203.X.30`:

1. Встановіть Apache2: `sudo apt install apache2`.
2. Створіть директорії `/var/www/main` та `/var/www/dev` з різними `index.html` (наприклад, "Main Site" та "Dev Site").
3. Налаштуйте два vhost-файли в `/etc/apache2/sites-available/`:
   - `surname.tsa243.lab.conf` → DocumentRoot `/var/www/main`
   - `dev.surname.tsa243.lab.conf` → DocumentRoot `/var/www/dev`
4. Активуйте обидва: `sudo a2ensite surname.tsa243.lab.conf dev.surname.tsa243.lab.conf`.
5. Перевірте синтаксис: `sudo apache2ctl configtest`.
6. Перезавантажте: `sudo systemctl reload apache2`.

**Демонстрація:** `curl -H "Host: surname.tsa243.lab" http://localhost/` та `curl -H "Host: dev.surname.tsa243.lab" http://localhost/` — відповіді мають відрізнятися.

---

### Завдання 2 — Self-signed TLS сертифікат та HTTPS (16 балів)

1. Увімкніть SSL-модуль: `sudo a2enmod ssl headers rewrite`.
2. Згенеруйте самопідписаний сертифікат:
   ```bash
   sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout /etc/ssl/private/surname.key \
     -out /etc/ssl/certs/surname.crt \
     -subj "/CN=surname.tsa243.lab"
   ```
3. Створіть HTTPS vhost (`*:443`) для `surname.tsa243.lab` з директивами `SSLEngine on`, `SSLCertificateFile`, `SSLCertificateKeyFile`.
4. Налаштуйте HTTP→HTTPS redirect у vhost на порту `*:80`:
   ```apacheconf
   Redirect permanent / https://surname.tsa243.lab/
   ```
5. Додайте заголовки безпеки у HTTPS-vhost:
   ```apacheconf
   Header always set Strict-Transport-Security "max-age=31536000"
   Header always set X-Frame-Options DENY
   Header always set X-Content-Type-Options nosniff
   ```
6. Вкажіть мінімальну версію TLS: `SSLProtocol -all +TLSv1.2 +TLSv1.3`.

**Демонстрація:**
- `curl -k -I https://surname.tsa243.lab/` — має показати `200 OK` та заголовки безпеки.
- `openssl s_client -connect localhost:443 2>/dev/null | grep -E "Protocol|Cipher"`.
- `curl -I http://localhost/` — має показати `301`.

---

### Завдання 3 — mod_status (12 балів)

1. Увімкніть `mod_status`: `sudo a2enmod status`.
2. Налаштуйте `ExtendedStatus On` та доступ до `/server-status` тільки з localhost.
3. Перезавантажте Apache та перевірте: `curl http://127.0.0.1/server-status?auto` — повинна повернути статистику.

**Демонстрація:** вивід `curl http://127.0.0.1/server-status?auto` із рядками `BusyWorkers`, `IdleWorkers`.

---

## ВАРІАНТ 3 — HAProxy балансування навантаження

**Сценарій:** Побудувати повний ланцюжок балансування: Nginx (reverse proxy) → HAProxy → два backend-сервери.

---

### Завдання 1 — Backend-сервери (10 балів)

На VM `11.203.X.30` та `11.203.X.31`:

1. Встановіть Nginx та налаштуйте кожен на порту `8080`.
2. Створіть сторінки, що чітко ідентифікують backend (наприклад, "BACKEND-01" та "BACKEND-02").
3. Створіть endpoint `/health` з вмістом `OK` у кожного.
4. Перевірте: `curl http://11.203.X.30:8080/health` та `curl http://11.203.X.31:8080/health` — обидва повертають `OK`.

---

### Завдання 2 — HAProxy конфігурація (14 балів)

На VM `11.203.X.13`:

1. Встановіть HAProxy: `sudo apt install haproxy`.
2. Налаштуйте `/etc/haproxy/haproxy.cfg`:
   - `frontend` на порту `80`, `default_backend web_backends`
   - `backend web_backends` з `balance roundrobin`
   - HTTP health check: `option httpchk GET /health` та `http-check expect string OK`
   - Обидва backend: `check inter 2s fall 3 rise 2`
   - Stats panel: `listen stats` на порту `8404`
3. Перевірте конфіг: `sudo haproxy -c -f /etc/haproxy/haproxy.cfg`.
4. Запустіть та перевірте: `sudo systemctl enable --now haproxy`.

**Демонстрація:** `for i in {1..6}; do curl -s http://11.203.X.13/ | grep -o 'BACKEND-[0-9]*'; done` — відповіді чергуються.

---

### Завдання 3 — Тест відмовостійкості (10 балів)

1. Зупиніть Nginx на `backend-01`: `sudo systemctl stop nginx` (на `11.203.X.30`).
2. Зачекайте 6 секунд (`fall 3` × `inter 2s`).
3. Надішліть 6 запитів до HAProxy — всі мають відповідати тільки `BACKEND-02`.
4. Запустіть Nginx знову, зачекайте 4 секунди (`rise 2`), переконайтеся, що балансування відновилося.

**Демонстрація:** вивід запитів та панель `http://11.203.X.13:8404/stats` зі статусом `DOWN` та відновленим `UP`.

---

### Завдання 4 — Nginx проксі до HAProxy (6 балів)

На VM `11.203.X.12`:

1. Налаштуйте Nginx для проксювання всього трафіку на `11.203.X.13`:
   ```nginx
   location / {
       proxy_pass http://11.203.X.13;
       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
   }
   ```
2. Перевірте: `for i in {1..4}; do curl -s http://11.203.X.12/ | grep -o 'BACKEND-[0-9]*'; done`.

---

## ВАРІАНТ 4 — Система моніторингу Prometheus & Grafana

**Сценарій:** Розгорнути повноцінну систему моніторингу для підмережі курсанта.

---

### Завдання 1 — Prometheus та Grafana (12 балів)

На VM `11.203.X.14`:

1. Встановіть Prometheus: `sudo apt install prometheus` — перевірте що слухає на `:9090`.
2. Встановіть Grafana з офіційного репозиторію Grafana Labs (додайте GPG-ключ та репозиторій, потім `apt install grafana`).
3. Запустіть та увімкніть автозапуск обидва сервіси.
4. Підключіть Prometheus як Data Source в Grafana (URL: `http://localhost:9090`).

**Демонстрація:** `sudo systemctl status prometheus grafana-server` — обидва `active (running)`.

---

### Завдання 2 — node_exporter на всіх VM (12 балів)

На VM `11.203.X.10`, `11.203.X.12`, `11.203.X.14`:

1. Встановіть `prometheus-node-exporter` на кожній VM.
2. Перевірте: `curl -s http://localhost:9100/metrics | grep "^node_load1"`.
3. На `mon VM (11.203.X.14)` відредагуйте `/etc/prometheus/prometheus.yml` — додайте job `node` з усіма трьома VM як targets.
4. Перезавантажте: `sudo systemctl reload prometheus`.
5. Перевірте: `http://11.203.X.14:9090/targets` — всі цілі мають бути `UP`.

**Демонстрація:** скриншот або вивід `curl -s http://11.203.X.14:9090/api/v1/targets | python3 -m json.tool | grep '"health"'` — всі `"up"`.

---

### Завдання 3 — PromQL запити (8 балів)

У браузері відкрийте `http://11.203.X.14:9090/graph` та виконайте і поясніть такі запити:

1. CPU utilization по кожній VM:
   ```promql
   (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) * 100
   ```
2. Відсоток використання RAM:
   ```promql
   (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100
   ```
3. Перевірка що всі VM живі:
   ```promql
   up
   ```

**Демонстрація:** покажіть результат кожного запиту (Table або Graph).

---

### Завдання 4 — Grafana Dashboard (8 балів)

1. Імпортуйте готовий дашборд Node Exporter Full (ID: `1860`) з grafana.com.
2. Оберіть одну з VM у фільтрі `$node` та покажіть графіки CPU і RAM.

**Демонстрація:** скриншот або живий показ дашборду з даними.

---

## ВАРІАНТ 5 — Bash-скрипти та система логування

**Сценарій:** Автоматизувати моніторинг системи та налаштувати централізований збір логів.

---

### Завдання 1 — Скрипт системного моніторингу (14 балів)

Напишіть скрипт `/opt/sysmon.sh`, який:

1. Збирає поточні показники:
   - CPU% (через `top -bn1` або `/proc/stat`)
   - RAM% (через `free`)
   - Дискове використання `/` у % (через `df`)
2. Формує рядок виду: `hostname | CPU:42% | RAM:68% | DISK:55%`
3. Записує рядок у файл `/var/log/sysmon.log` та надсилає через `logger -t sysmon`.
4. Якщо використання диску > 80% — виводить попередження `ALERT: disk > 80%` та записує його у syslog з пріоритетом `local0.warn`.
5. Виходить з кодом 0 при нормальному стані, кодом 1 при Alert.

Зробіть скрипт виконуваним і запустіть: `./opt/sysmon.sh` — покажіть вміст `/var/log/sysmon.log` та `journalctl -t sysmon --since "2 min ago"`.

---

### Завдання 2 — Планування через cron (6 балів)

1. Додайте до crontab запис для запуску `/opt/sysmon.sh` кожні 5 хвилин.
2. Перевірте через `crontab -l`.
3. Почекайте 5 хвилин або виконайте вручну кілька разів, перевірте що `/var/log/sysmon.log` поповнюється.

---

### Завдання 3 — Централізований rsyslog (12 балів)

**На VM `11.203.X.11` (SMTP VM) — сервер логів:**

1. Увімкніть прийом по UDP в `/etc/rsyslog.conf`:
   ```
   module(load="imudp")
   input(type="imudp" port="514")
   ```
2. Додайте шаблон зберігання: логи від клієнтів зберігаються у `/var/log/remote/%HOSTNAME%.log`.
3. Перезапустіть: `sudo systemctl restart rsyslog`.
4. Перевірте: `sudo ss -ulnp | grep 514`.

**На VM `11.203.X.12` (Nginx VM) — клієнт:**

1. Додайте до `/etc/rsyslog.conf` пересилання всіх логів:
   ```
   *.* @11.203.X.11:514
   ```
2. Перезапустіть rsyslog.
3. Надішліть тестове повідомлення: `logger -t test "hello from client"`.
4. Перевірте на сервері: `cat /var/log/remote/*.log | grep test`.

**Демонстрація:** тестове повідомлення видно у лог-файлі на `11.203.X.11`.

---

### Завдання 4 — logrotate (8 балів)

Налаштуйте ротацію `/var/log/sysmon.log` у файлі `/etc/logrotate.d/sysmon`:

```
/var/log/sysmon.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 0640 root adm
}
```

Запустіть примусово: `sudo logrotate --force /etc/logrotate.d/sysmon` та перевірте що з'явився `sysmon.log.1.gz`.

---

## ВАРІАНТ 6 — Системне адміністрування Linux

**Сценарій:** Виконати комплекс завдань системного адміністратора: управління користувачами, дисками, пакетами та аналіз безпеки.

---

### Завдання 1 — Управління користувачами та групами (10 балів)

1. Створіть двох користувачів: `developer1` та `developer2` з домашніми директоріями та shell `/bin/bash`.
2. Встановіть пароль для кожного: `sudo passwd developer1`.
3. Створіть групу `devteam`: `sudo groupadd devteam`.
4. Додайте обох до групи: `sudo usermod -aG devteam developer1 developer2`.
5. Налаштуйте через `visudo` (у файлі `/etc/sudoers.d/devteam`) право запускати `apt` без пароля:
   ```
   %devteam ALL=(ALL) NOPASSWD: /usr/bin/apt
   ```
6. Перевірте: `sudo -u developer1 -l` — у списку має бути `apt`.

**Демонстрація:** `id developer1`, `groups developer2`, `sudo -u developer1 -l`.

---

### Завдання 2 — Робота з дисками та файловою системою (12 балів)

На VM, де є додатковий диск `/dev/sdb`:

1. Перевірте наявність диску: `lsblk`.
2. Розбийте диск за GPT-схемою через `gdisk /dev/sdb`: створіть один основний розділ на весь диск.
3. Відформатуйте у ext4: `sudo mkfs.ext4 /dev/sdb1`.
4. Отримайте UUID: `sudo blkid /dev/sdb1`.
5. Створіть точку монтування `/data` та змонтуйте: `sudo mount /dev/sdb1 /data`.
6. Додайте запис до `/etc/fstab` для постійного монтування за UUID.
7. Перевірте: `sudo umount /data && sudo mount -a && df -h /data`.

**Демонстрація:** `df -h /data`, `cat /etc/fstab | grep sdb`.

---

### Завдання 3 — Збірка програми з вихідного коду (8 балів)

1. Встановіть залежності для збірки: `sudo apt install -y build-essential autoconf libtool`.
2. Завантажте вихідний код `jq` або іншого невеликого інструменту.
   ```bash
   sudo apt install -y git
   git clone https://github.com/jqlang/jq.git /tmp/jq-src
   ```
3. Зберіть та встановіть:
   ```bash
   cd /tmp/jq-src
   git submodule update --init
   autoreconf -i
   ./configure --prefix=/usr/local
   make -j$(nproc)
   sudo make install
   ```
4. Перевірте: `jq --version` та `ldd $(which jq)`.

**Демонстрація:** `jq --version`, `echo '{"key":"value"}' | jq .key`.

---

### Завдання 4 — Аналіз безпеки SSH (10 балів)

1. Перегляньте журнал невдалих спроб SSH: `sudo grep "Failed password" /var/log/auth.log | head -20`.
2. Напишіть однорядковий скрипт, який виводить топ-5 IP-адрес, що намагалися підключитися по SSH та отримали відмову:
   ```bash
   sudo grep "Failed password" /var/log/auth.log \
     | awk '{print $(NF-3)}' \
     | sort | uniq -c | sort -rn | head -5
   ```
3. Перегляньте успішні входи: `last | head -10`.
4. Налаштуйте у `/etc/ssh/sshd_config` обмеження:
   - `MaxAuthTries 3`
   - `LoginGraceTime 30`
5. Перевірте синтаксис і перезавантажте: `sudo sshd -t && sudo systemctl reload ssh`.

**Демонстрація:** вивід топ-5 IP та `sudo sshd -t` без помилок.

---

## КРИТЕРІЇ ОЦІНЮВАННЯ ПРАКТИЧНИХ ЗАВДАНЬ

| Критерій | Опис |
|----------|------|
| **Виконання завдання** | Команди виконані правильно, результат відповідає очікуваному |
| **Демонстрація** | Курсант може показати і пояснити результат |
| **Розуміння** | Курсант відповідає на уточнюючі питання щодо виконаних кроків |
| **Конфігурація** | Файли конфігурації коректні та зберігаються після перезавантаження |

**Часткове виконання:** якщо курсант виконав частину підзавдання правильно — нараховується пропорційна частина балів.

---

*Технології системного адміністрування · Курс 2-й · ВІТІ · 2026*
