# ЗАЛІК — ПРАКТИЧНІ ЗАВДАННЯ
## Технології системного адміністрування | Курс 2-й | ВІТІ

> **Оцінювання:** 40 балів  
> **Час виконання:** 40 хвилин  
> **Середовище:** Ubuntu Server 24.04 LTS · Proxmox VE · підмережа `11.203.X.0/25`  
> Замінюйте `X` на номер вашого варіанта, `surname` — на ваше прізвище латинкою.

---

## ВАРІАНТ 1 — SSH: ключова автентифікація та захист сервера

Вам потрібно забезпечити безпечний SSH-доступ до сервера `11.203.X.12` та автоматизувати резервне копіювання конфігурацій.

1. На робочій станції (`11.203.X.20`) згенеруйте ключ Ed25519 з коментарем `zalik`:
   ```bash
   ssh-keygen -t ed25519 -C "zalik"
   ```

2. Скопіюйте публічний ключ на сервер `11.203.X.12`:
   ```bash
   ssh-copy-id user@11.203.X.12
   ```
   Переконайтеся, що вхід за ключем працює без введення пароля.

3. На сервері `11.203.X.12` відредагуйте `/etc/ssh/sshd_config` — встановіть:
   - `PasswordAuthentication no`
   - `PermitRootLogin no`
   - `MaxAuthTries 3`

4. Перевірте синтаксис: `sudo sshd -t` та перезавантажте сервіс `sudo systemctl reload ssh`.

5. Створіть файл `~/.ssh/config` на робочій станції з псевдонімом для сервера:
   ```
   Host web
       HostName 11.203.X.12
       User user
       IdentityFile ~/.ssh/id_ed25519
   ```
   Переконайтеся, що `ssh web` підключається без додаткових аргументів.

6. Напишіть скрипт `/opt/backup.sh`, який:
   - Архівує `/etc` у файл `/backup/etc-$(date +%Y-%m-%d).tar.gz`
   - Створює `/backup` якщо її не існує
   - Записує результат у syslog командою `logger -t backup`
   - Перевіряє код завершення `tar` та виходить з кодом `1` при помилці

   Зробіть скрипт виконуваним та запустіть вручну. Покажіть: `ls -lh /backup/` та `journalctl -t backup -n 3`.

---

## ВАРІАНТ 2 — Apache: virtual hosts та HTTPS

Вам потрібно налаштувати веб-сервер Apache з двома virtual hosts та увімкнути безпечне HTTPS-підключення.

1. На VM `11.203.X.30` встановіть Apache2, увімкніть модулі `ssl`, `headers`, `rewrite`:
   ```bash
   sudo apt install apache2
   sudo a2enmod ssl headers rewrite
   ```

2. Створіть директорії `/var/www/main` та `/var/www/dev`. Помістіть у кожну `index.html` з різним текстом — наприклад, "Головний сайт — surname" та "Dev-сервер — surname".

3. Налаштуйте два virtual host файли у `/etc/apache2/sites-available/`:
   - `surname.conf` — порт `*:80`, DocumentRoot `/var/www/main`, ServerName `surname.tsa243.lab`
   - `dev.surname.conf` — порт `*:80`, DocumentRoot `/var/www/dev`, ServerName `dev.surname.tsa243.lab`

   Активуйте через `a2ensite`, перевірте `apache2ctl configtest`, перезавантажте.

4. Згенеруйте self-signed сертифікат для `surname.tsa243.lab`:
   ```bash
   sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout /etc/ssl/private/surname.key \
     -out /etc/ssl/certs/surname.crt \
     -subj "/CN=surname.tsa243.lab"
   ```

5. Створіть HTTPS virtual host на `*:443` для `surname.tsa243.lab` з директивами `SSLEngine on`, `SSLCertificateFile`, `SSLCertificateKeyFile` та обмеженням версій TLS: `SSLProtocol -all +TLSv1.2 +TLSv1.3`.

6. У HTTP virtual host (порт 80) для `surname.tsa243.lab` налаштуйте постійний redirect:
   ```apacheconf
   Redirect permanent / https://surname.tsa243.lab/
   ```
   Додайте у HTTPS vhost заголовок HSTS: `Header always set Strict-Transport-Security "max-age=31536000"`.

   Перевірте:
   - `curl -k -I https://surname.tsa243.lab/` → `200 OK` зі заголовком `Strict-Transport-Security`
   - `curl -I http://surname.tsa243.lab/` → `301 Moved Permanently`
   - `curl -H "Host: dev.surname.tsa243.lab" http://localhost/` → сторінка Dev-сервера

---

## ВАРІАНТ 3 — HAProxy: балансування та відмовостійкість

Вам потрібно розгорнути балансувальник навантаження та перевірити автоматичне виключення недоступного backend.

1. На VM `11.203.X.30` та `11.203.X.31` встановіть Nginx та налаштуйте на порту `8080`. Кожен backend повинен:
   - Повертати сторінку з унікальним текстом `BACKEND-01` або `BACKEND-02`
   - Мати файл зі змістом `OK` за адресою `http://IP:8080/health`

   Перевірте: `curl http://11.203.X.30:8080/health` та `curl http://11.203.X.31:8080/health` — обидва повертають `OK`.

2. На VM `11.203.X.13` встановіть HAProxy та налаштуйте `/etc/haproxy/haproxy.cfg`:
   - `frontend http_front` на порту `80`, `default_backend web_backends`
   - `backend web_backends` з `balance roundrobin`
   - HTTP health check: `option httpchk GET /health` та `http-check expect string OK`
   - Для кожного сервера: `check inter 2s fall 3 rise 2`
   - `listen stats` на порту `8404` з `stats enable` та `stats uri /stats`

3. Перевірте синтаксис: `sudo haproxy -c -f /etc/haproxy/haproxy.cfg`. Запустіть HAProxy.

4. Перевірте балансування round-robin:
   ```bash
   for i in {1..6}; do curl -s http://11.203.X.13/ | grep -o 'BACKEND-[0-9]*'; done
   ```
   Відповіді мають чергуватись між `BACKEND-01` та `BACKEND-02`.

5. Перевірте відмовостійкість:
   - Зупиніть Nginx на `11.203.X.30`: `sudo systemctl stop nginx`
   - Зачекайте 6 секунд та виконайте 4 запити — всі мають відповідати тільки `BACKEND-02`
   - Запустіть Nginx знову, зачекайте 4 секунди та переконайтеся, що балансування відновилося

   Покажіть панель `http://11.203.X.13:8404/stats` зі статусом `DOWN` під час відмови та поверненням до `UP`.

---

## ВАРІАНТ 4 — Bash: скрипт моніторингу та планування

Вам потрібно написати скрипт системного моніторингу, налаштувати його автоматичний запуск і перевірити результати в журналі.

1. Напишіть скрипт `/opt/sysmon.sh`:
   - Отримує відсоток використання диску `/` (через `df`)
   - Отримує кількість вільної RAM у MB (через `free`)
   - Отримує load average за 1 хвилину (через `uptime` або `/proc/loadavg`)
   - Формує рядок та записує у файл `/var/log/sysmon.log` і в syslog через `logger -t sysmon`:
     ```
     [2026-05-26 14:30:00] host=vm01 disk=/=45% ram_free=1024MB load=0.25
     ```
   - Якщо диск `/` заповнений більше ніж на 80% — додатково записує `ALERT: disk > 80%` у syslog з пріоритетом `local0.warn` та виходить з кодом `1`

2. Перевірте синтаксис скрипту без виконання: `bash -n /opt/sysmon.sh`. Зробіть скрипт виконуваним та запустіть кілька разів:
   ```bash
   /opt/sysmon.sh; echo "exit code: $?"
   ```

3. Перевірте результати: `cat /var/log/sysmon.log` та `journalctl -t sysmon -n 5`.

4. Налаштуйте запуск через cron кожні 5 хвилин. Перевірте: `crontab -l`.

5. Налаштуйте ротацію `/var/log/sysmon.log` у `/etc/logrotate.d/sysmon`:
   ```
   /var/log/sysmon.log {
       daily
       rotate 7
       compress
       missingok
       notifempty
   }
   ```
   Запустіть примусово: `sudo logrotate --force /etc/logrotate.d/sysmon`. Перевірте, що з'явився `sysmon.log.1.gz`.

---

## ВАРІАНТ 5 — Nginx: reverse proxy та аналіз логів

Вам потрібно налаштувати Nginx як reverse proxy та проаналізувати логи запитів.

1. На VM `11.203.X.30` запустіть простий Python HTTP-сервер на порту `8080`:
   ```bash
   mkdir -p /tmp/backend
   echo "backend-01 response — surname" > /tmp/backend/index.html
   cd /tmp/backend && python3 -m http.server 8080 &
   ```
   Перевірте: `curl http://11.203.X.30:8080/`.

2. На VM `11.203.X.12` встановіть Nginx та налаштуйте reverse proxy у `/etc/nginx/sites-available/proxy.conf`:
   ```nginx
   server {
       listen 80;
       server_name surname.tsa243.lab;

       access_log /var/log/nginx/surname.access.log;

       location / {
           proxy_pass         http://11.203.X.30:8080;
           proxy_set_header   Host              $host;
           proxy_set_header   X-Real-IP         $remote_addr;
           proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
       }

       location /health {
           access_log off;
           return 200 "OK\n";
           add_header Content-Type text/plain;
       }
   }
   ```
   Активуйте конфіг, перевірте `nginx -t`, перезавантажте.

3. Надішліть 20 тестових запитів через проксі та кілька до `/health`:
   ```bash
   for i in {1..20}; do curl -s http://11.203.X.12/ > /dev/null; done
   for i in {1..5}; do curl -s http://11.203.X.12/health > /dev/null; done
   ```

4. Перевірте логи — рядки `/health` не повинні там з'являтися:
   ```bash
   tail -10 /var/log/nginx/surname.access.log
   grep "/health" /var/log/nginx/surname.access.log | wc -l   # має бути 0
   ```

5. Напишіть bash-команду в одному рядку, яка аналізує лог та виводить кількість запитів по HTTP-кодах відповіді. Використайте `awk`, `sort` та `uniq -c`:
   ```bash
   awk '{print $9}' /var/log/nginx/surname.access.log | sort | uniq -c | sort -rn
   ```
   Поясніть, що означає кожен з отриманих кодів.

---

## ВАРІАНТ 6 — Prometheus: розгортання та PromQL-запити

Вам потрібно розгорнути систему моніторингу, підключити кілька VM та виконати PromQL-запити для аналізу стану інфраструктури.

1. На VM `11.203.X.14` встановіть Prometheus:
   ```bash
   sudo apt install prometheus
   sudo systemctl status prometheus
   sudo ss -tlnp | grep 9090
   ```

2. На VM `11.203.X.10`, `11.203.X.12` та `11.203.X.14` встановіть `prometheus-node-exporter`:
   ```bash
   sudo apt install prometheus-node-exporter
   ```
   На кожній VM перевірте: `curl -s http://localhost:9100/metrics | grep "^node_load1"`.

3. На VM `11.203.X.14` відредагуйте `/etc/prometheus/prometheus.yml` — додайте job `node`:
   ```yaml
   - job_name: 'node'
     static_configs:
       - targets:
           - '11.203.X.10:9100'
           - '11.203.X.12:9100'
           - '11.203.X.14:9100'
   ```
   Перевірте синтаксис: `sudo promtool check config /etc/prometheus/prometheus.yml`.  
   Перезавантажте: `sudo systemctl reload prometheus`.

4. Відкрийте `http://11.203.X.14:9090/targets` — всі три цілі мають статус `UP`.

5. У вікні `http://11.203.X.14:9090/graph` виконайте та поясніть результат трьох запитів:

   **Запит A** — CPU utilization (%) по кожній VM:
   ```promql
   (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) * 100
   ```

   **Запит B** — відсоток використання RAM по кожній VM:
   ```promql
   (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100
   ```

   **Запит C** — статус доступності всіх цілей:
   ```promql
   up{job="node"}
   ```

   Покажіть результат у вкладці **Table** та поясніть, що означає отримане значення для кожного запиту.

---

*Технології системного адміністрування · Курс 2-й · ВІТІ · 2026*
