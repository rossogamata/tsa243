# Змістовний модуль 7. Адміністрування серверів та балансування навантаження
## ЗАНЯТТЯ 7_13 (Практичне) — Розгортання системи моніторингу Prometheus & Grafana

> **Дисципліна:** Технології Системного Адміністрування | **Курс:** 2-й  
> **ОС:** Ubuntu Server 24.04 LTS | **Тип заняття:** Практичне  
> **Середовище:** Proxmox VE · підмережа курсанта `11.203.X.0/25`  
> **Час виконання:** ~90 хвилин  
> **Попередні заняття:** lesson7_12 (Лекція: системи моніторингу)

---

## Навчальні питання

1. [Розгортання Prometheus & Grafana](#питання-1--розгортання-prometheus--grafana)
2. [Встановлення exporters на хостах (DNS, Apache, Postfix)](#питання-2--встановлення-exporters)
3. [Scrape config & dashboarding — збирання даних та візуалізація](#питання-3--scrape-config--dashboarding)

---

## Середовище заняття

| VM | Адреса | Роль | Що робимо |
|----|--------|------|-----------|
| mon VM | `11.203.X.14` | Prometheus + Grafana | Питання 1 |
| DNS VM | `11.203.X.10` | BIND9 + node_exporter + bind_exporter | Питання 2 |
| SMTP VM | `11.203.X.11` | Postfix + node_exporter + postfix_exporter | Питання 2 |
| Apache VM | `11.203.X.30` | Apache2 + node_exporter + apache_exporter | Питання 2 |
| Nginx VM | `11.203.X.12` | Nginx + node_exporter | Питання 2 |

> Замінюйте `X` на номер вашого варіанта, `surname` — на ваше прізвище латинкою.

**Загальна схема:**

```
Prometheus (11.203.X.14:9090)    scrape кожні 15 секунд
          │
          ├──── node_exporter   :9100   ← всі VM (системні метрики)
          ├──── bind_exporter   :9119   ← 11.203.X.10 (DNS зони, запити)
          ├──── postfix_exporter:9154   ← 11.203.X.11 (черга, доставка)
          └──── apache_exporter :9117   ← 11.203.X.30 (з'єднання, RPS)

Grafana (11.203.X.14:3000)
          └──── Data Source: Prometheus
          └──── Dashboards: Node / Apache / DNS / Postfix
```

> **Примітка щодо backend-01 (.30):** у lesson7_10–7_11 на `.30` працював Nginx як backend. На цьому занятті замінюємо його на Apache2 — щоб продемонструвати apache_exporter і mod_status. Nginx на `.12` залишається незмінним.

---

# Питання 1 — Розгортання Prometheus & Grafana

> Всі команди Питання 1 виконуються на **mon VM (11.203.X.14)**

Відкрийте термінал і підключіться до mon VM:

```bash
ssh user@11.203.X.14
```

---

## Крок 1 — Встановлення Prometheus

Ubuntu 24.04 LTS містить Prometheus у стандартних репозиторіях:

```bash
sudo apt update
sudo apt install -y prometheus
```

Prometheus встановлюється як systemd-сервіс і запускається автоматично.

### Перевірка:

```bash
sudo systemctl status prometheus
```

Очікуваний вивід:
```
● prometheus.service - Monitoring system and time series database
     Loaded: loaded (/lib/systemd/system/prometheus.service; enabled)
     Active: active (running) since ...
```

```bash
# Перевірити що prometheus слухає на порту 9090
sudo ss -tlnp | grep 9090
```

Очікуваний вивід:
```
LISTEN  0  128  0.0.0.0:9090  0.0.0.0:*  users:(("prometheus",pid=...,fd=...))
```

```bash
# Перевірити /metrics самого prometheus
curl -s http://localhost:9090/metrics | head -5
```

> Prometheus за замовчуванням моніторить тільки себе. Конфігурацію цілей зробимо у Питанні 3.

---

## Крок 2 — Встановлення Grafana

Grafana не входить у стандартні репозиторії Ubuntu — підключаємо офіційний репозиторій Grafana Labs:

```bash
# Встановити залежності та GPG-ключ
sudo apt install -y apt-transport-https software-properties-common wget
sudo mkdir -p /etc/apt/keyrings

wget -q -O - https://apt.grafana.com/gpg.key | \
    gpg --dearmor | \
    sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null

# Додати репозиторій
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | \
    sudo tee /etc/apt/sources.list.d/grafana.list

# Встановити
sudo apt update
sudo apt install -y grafana
```

```bash
# Запустити та увімкнути автозапуск
sudo systemctl enable --now grafana-server

sudo systemctl status grafana-server
```

Очікуваний вивід:
```
● grafana-server.service - Grafana instance
     Active: active (running)
```

```bash
sudo ss -tlnp | grep 3000
```

Очікуваний вивід:
```
LISTEN  0  128  0.0.0.0:3000  0.0.0.0:*  users:(("grafana",pid=...,fd=...))
```

---

## Крок 3 — Перша вхід у Grafana

Відкрийте браузер на **робочій станції (11.203.X.20)** та перейдіть за адресою:

```
http://11.203.X.14:3000
```

Дані для першого входу:
```
Login:    admin
Password: admin
```

Grafana запропонує змінити пароль — встановіть `Admin1234` (або будь-який надійний).

---

## Крок 4 — Підключення Prometheus як Data Source

У Grafana:

1. Ліве меню → **Connections** → **Data sources** → **Add data source**
2. Оберіть **Prometheus**
3. У полі **Prometheus server URL** введіть:
   ```
   http://localhost:9090
   ```
4. Прокрутіть вниз → **Save & test**

Очікуваний результат:
```
✅ Successfully queried the Prometheus API.
```

> Grafana і Prometheus на одній VM → `localhost:9090` працює. Якщо б вони були на різних VM — треба вказати IP.

---

# Питання 2 — Встановлення Exporters

## 2.1 Node Exporter — на всіх VM

**node_exporter** встановлюється на кожну VM і збирає системні метрики ОС (CPU, RAM, диск, мережа).

> Виконайте на **кожній VM**: `.10`, `.11`, `.12`, `.14`, `.30`

```bash
sudo apt update
sudo apt install -y prometheus-node-exporter
```

Сервіс запускається та вмикається автоматично:

```bash
sudo systemctl status prometheus-node-exporter
```

```bash
# Перевірка — метрики доступні
curl -s http://localhost:9100/metrics | grep "^node_load1"
```

Очікуваний вивід:
```
node_load1 0.08
```

> Виконайте цей крок на всіх п'яти VM перед тим, як переходити далі. node_exporter встановлюється однаково на кожній.

---

## 2.2 Bind Exporter — на DNS VM (11.203.X.10)

> Виконується на **DNS VM (11.203.X.10)**

**bind_exporter** зчитує статистику BIND9 через його Statistics Channel і перетворює на метрики Prometheus.

### Крок 2.2.1 — Увімкнути Statistics Channel у BIND9

BIND9 має вбудований HTTP-інтерфейс для статистики, який треба увімкнути:

```bash
sudo nano /etc/bind/named.conf.options
```

Додайте блок `statistics-channels` всередині `options { ... }` або після нього:

```
options {
    directory "/var/cache/bind";
    // ... інші налаштування ...
};

statistics-channels {
    inet 127.0.0.1 port 8080 allow { 127.0.0.1; };
};
```

```bash
sudo named-checkconf
sudo systemctl restart bind9
```

### Перевірка Statistics Channel:

```bash
curl -s http://127.0.0.1:8080/json/v1 | python3 -m json.tool | head -20
```

Очікуваний вивід (фрагмент JSON):
```json
{
    "json-stats-version": "1.5",
    "boot-time": "2026-05-25T...",
    "views": {
        "_default": {
            "resolver": {
                "stats": {
                    "QueryV4": 1024,
```

### Крок 2.2.2 — Встановлення bind_exporter

```bash
sudo apt install -y prometheus-bind-exporter
```

Перевіримо конфігурацію unit-файлу:

```bash
cat /lib/systemd/system/prometheus-bind-exporter.service
```

Exporter має запускатись з параметром, що вказує на Statistics Channel BIND9:

```bash
sudo nano /etc/default/prometheus-bind-exporter
```

Переконайтесь що рядок `ARGS` виглядає так:

```
ARGS="--bind.stats-url=http://127.0.0.1:8080/"
```

```bash
sudo systemctl enable --now prometheus-bind-exporter

sudo systemctl status prometheus-bind-exporter
```

### Перевірка bind_exporter:

```bash
curl -s http://localhost:9119/metrics | grep "^bind_"
```

Очікуваний вивід (фрагмент):
```
bind_incoming_queries_total{type="A"} 1024
bind_incoming_queries_total{type="AAAA"} 312
bind_incoming_queries_total{type="MX"} 45
bind_resolver_cache_hit_ratio 0.87
bind_zone_serial{view="_default",zone="surname.tsa243.lab"} 2026052501
```

**Основні метрики bind_exporter:**

| Метрика | Опис |
|---------|------|
| `bind_incoming_queries_total{type="A"}` | DNS запити типу A (IPv4) |
| `bind_incoming_queries_total{type="MX"}` | DNS запити типу MX (пошта) |
| `bind_resolver_cache_hit_ratio` | Відсоток запитів з кешу |
| `bind_zone_serial` | Серійний номер зони |
| `bind_up` | 1 якщо BIND9 відповідає |

---

## 2.3 Apache Exporter — на Apache VM (11.203.X.30)

> Виконується на **Apache VM (11.203.X.30)**

У попередніх заняттях (7_10, 7_11) на цій VM стояв Nginx-backend. Для цього заняття замінюємо його на **Apache2** — щоб показати моніторинг ще одного типу веб-сервера через `mod_status`.

### Крок 2.3.1 — Встановлення та налаштування Apache2

```bash
# Видалити Nginx (якщо стояв)
sudo systemctl stop nginx 2>/dev/null
sudo apt remove -y nginx nginx-common

# Встановити Apache2
sudo apt install -y apache2

sudo systemctl enable --now apache2
sudo systemctl status apache2
```

### Крок 2.3.2 — Увімкнути mod_status

`mod_status` — стандартний модуль Apache, який надає сторінку зі статистикою роботи сервера. Це аналог `stub_status` у Nginx.

```bash
# Увімкнути модуль
sudo a2enmod status

# Переконатись що модуль активний
apache2ctl -M | grep status
```

Очікуваний вивід:
```
 status_module (shared)
```

Налаштуємо доступ до статусної сторінки:

```bash
sudo nano /etc/apache2/mods-enabled/status.conf
```

Замініть вміст файлу на:

```apache
<IfModule mod_status.c>
    ExtendedStatus On

    <Location /server-status>
        SetHandler server-status
        Require ip 127.0.0.1
    </Location>
</IfModule>
```

> `ExtendedStatus On` — обов'язковий для apache_exporter: включає детальну статистику (час обробки запитів, Worker статус).

```bash
sudo apache2ctl configtest
sudo systemctl reload apache2
```

### Перевірка mod_status:

```bash
curl -s http://127.0.0.1/server-status?auto
```

Очікуваний вивід:
```
ServerVersion: Apache/2.4.58 (Ubuntu)
ServerMPM: event
Server Built: ...
CurrentTime: Sunday, 25-May-2026 ...
RestartTime: ...
ParentServerConfigGeneration: 1
ParentServerMPMGeneration: 0
ServerUptimeSeconds: 42
ServerUptime: 42 seconds
Load1: 0.00
Load5: 0.01
Load15: 0.05
Total Accesses: 3
Total kBytes: 2
Total Duration: 1
CPULoad: .00238095
Uptime: 42
ReqPerSec: .0714286
BytesPerSec: 48.7619
BytesPerReq: 682.667
DurationPerReq: .333333
BusyWorkers: 1
IdleWorkers: 4
ConnsTotal: 0
ConnsAsyncWriting: 0
ConnsAsyncKeepAlive: 0
ConnsAsyncClosing: 0
Scoreboard: _W___...
```

> Параметр `?auto` повертає plain-text формат — саме його читає apache_exporter.

### Крок 2.3.3 — Встановлення apache_exporter

apache_exporter відсутній у стандартних репозиторіях Ubuntu 24.04 — завантажуємо з GitHub:

```bash
# Завантажити актуальну версію
wget https://github.com/Lusitaniae/apache_exporter/releases/download/v1.0.8/apache_exporter-1.0.8.linux-amd64.tar.gz

tar xvf apache_exporter-1.0.8.linux-amd64.tar.gz
sudo cp apache_exporter-1.0.8.linux-amd64/apache_exporter /usr/local/bin/
sudo chmod +x /usr/local/bin/apache_exporter
```

Створіть системного користувача та systemd unit:

```bash
sudo useradd -rs /bin/false apache_exporter
```

```bash
sudo nano /etc/systemd/system/apache_exporter.service
```

```ini
[Unit]
Description=Apache Exporter for Prometheus
After=network.target apache2.service

[Service]
Type=simple
User=apache_exporter
ExecStart=/usr/local/bin/apache_exporter \
    --scrape_uri=http://127.0.0.1/server-status?auto \
    --telemetry.address=:9117
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now apache_exporter

sudo systemctl status apache_exporter
```

### Перевірка apache_exporter:

```bash
curl -s http://localhost:9117/metrics | grep "^apache_"
```

Очікуваний вивід (фрагмент):
```
apache_accesses_total 3
apache_duration_ms_total 1
apache_sent_kilobytes_total 2
apache_workers{state="busy"} 1
apache_workers{state="idle"} 4
apache_scoreboard{state="waiting"} 4
apache_scoreboard{state="open"} 246
apache_cpuload 0.00238
apache_up 1
```

**Основні метрики apache_exporter:**

| Метрика | Тип | Опис |
|---------|-----|------|
| `apache_accesses_total` | Counter | Загальна кількість запитів |
| `apache_duration_ms_total` | Counter | Загальний час обробки запитів (мс) |
| `apache_sent_kilobytes_total` | Counter | Надіслано даних (KiB) |
| `apache_workers{state="busy"}` | Gauge | Зайняті воркери |
| `apache_workers{state="idle"}` | Gauge | Вільні воркери |
| `apache_cpuload` | Gauge | Поточне навантаження CPU від Apache |
| `apache_up` | Gauge | 1 якщо Apache відповідає |

### Тестове навантаження на Apache:

Щоб метрики стали цікавішими — згенеруємо кілька запитів:

```bash
# З цієї ж VM або з workstation (.20)
for i in {1..50}; do curl -s http://11.203.X.30/ > /dev/null; done

# Перевірити зростання лічильника
curl -s http://11.203.X.30:9117/metrics | grep "apache_accesses_total"
```

---

## 2.4 Postfix Exporter — на SMTP VM (11.203.X.11)

> Виконується на **SMTP VM (11.203.X.11)**

**postfix_exporter** зчитує лог Postfix (`/var/log/mail.log`) та журнал systemd і перетворює на метрики Prometheus.

### Встановлення:

```bash
sudo apt install -y prometheus-postfix-exporter
```

Перевіримо конфігурацію:

```bash
cat /lib/systemd/system/prometheus-postfix-exporter.service
```

За замовчуванням exporter читає `/var/log/mail.log`. Переконайтесь, що сервіс може читати цей файл:

```bash
# Postfix exporter запускається від імені prometheus-postfix-exporter
# Перевіримо права на лог
ls -la /var/log/mail.log
```

```bash
sudo systemctl enable --now prometheus-postfix-exporter

sudo systemctl status prometheus-postfix-exporter
```

### Перевірка postfix_exporter:

```bash
curl -s http://localhost:9154/metrics | grep "^postfix_"
```

Очікуваний вивід:
```
postfix_up 1
postfix_smtpd_connects_total 42
postfix_smtpd_disconnects_total 42
postfix_smtpd_messages_processed_total{status="accepted"} 28
postfix_smtpd_messages_processed_total{status="rejected"} 3
postfix_cleanup_messages_processed_total 28
postfix_qmgr_messages_active 0
postfix_qmgr_messages_held 0
postfix_smtp_delivery_delay_seconds_bucket{le="0.1"} 12
postfix_smtp_delivery_delay_seconds_bucket{le="1"} 26
postfix_smtp_delivery_delay_seconds_bucket{le="+Inf"} 28
```

**Основні метрики postfix_exporter:**

| Метрика | Тип | Опис |
|---------|-----|------|
| `postfix_up` | Gauge | 1 якщо Postfix запущений |
| `postfix_smtpd_connects_total` | Counter | Кількість SMTP підключень |
| `postfix_smtpd_messages_processed_total{status="accepted"}` | Counter | Прийнятих листів |
| `postfix_smtpd_messages_processed_total{status="rejected"}` | Counter | Відхилених листів (spam/relay) |
| `postfix_qmgr_messages_active` | Gauge | Листів у черзі активних |
| `postfix_smtp_delivery_delay_seconds` | Histogram | Час доставки листів |

### Тест відправки листа (щоб з'явились метрики):

```bash
# З SMTP VM відправити тестовий лист
echo "Test from lesson7_13" | mail -s "Monitoring test" user@surname.tsa243.lab

# Перевірити чергу
mailq

# Подивитись метрики
curl -s http://localhost:9154/metrics | grep "postfix_smtpd_messages"
```

---

## Підсумок Питання 2: відкриті порти на VM

Після всіх встановлень:

```
11.203.X.10 (DNS VM):
  :9100  ← node_exporter (системні метрики)
  :9119  ← bind_exporter (DNS статистика)

11.203.X.11 (SMTP VM):
  :9100  ← node_exporter
  :9154  ← postfix_exporter (пошта)

11.203.X.12 (Nginx VM):
  :9100  ← node_exporter

11.203.X.14 (mon VM):
  :9090  ← Prometheus
  :3000  ← Grafana
  :9100  ← node_exporter

11.203.X.30 (Apache VM):
  :9100  ← node_exporter
  :9117  ← apache_exporter (Apache статистика)
```

Перевірте доступність кожного порту з **mon VM (11.203.X.14)**:

```bash
# Перевірити всі endpoints одночасно
for target in \
    "11.203.X.10:9100" \
    "11.203.X.10:9119" \
    "11.203.X.11:9100" \
    "11.203.X.11:9154" \
    "11.203.X.12:9100" \
    "11.203.X.14:9100" \
    "11.203.X.30:9100" \
    "11.203.X.30:9117"; do
        status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://$target/metrics")
        echo "$status  http://$target/metrics"
done
```

Очікуваний вивід (всі `200`):
```
200  http://11.203.X.10:9100/metrics
200  http://11.203.X.10:9119/metrics
200  http://11.203.X.11:9100/metrics
200  http://11.203.X.11:9154/metrics
200  http://11.203.X.12:9100/metrics
200  http://11.203.X.14:9100/metrics
200  http://11.203.X.30:9100/metrics
200  http://11.203.X.30:9117/metrics
```

> Якщо якийсь endpoint повертає не `200` — поверніться до відповідного кроку і перевірте статус сервісу через `systemctl status <назва>`.

---

# Питання 3 — Scrape Config & Dashboarding

> Всі команди Питання 3 виконуються на **mon VM (11.203.X.14)**

## Крок 3.1 — Повна конфігурація Prometheus

Замінимо стандартний конфіг Prometheus на повну конфігурацію з усіма цілями:

```bash
sudo nano /etc/prometheus/prometheus.yml
```

```yaml
global:
  scrape_interval:     15s
  evaluation_interval: 15s
  # Глобальні мітки — додаються до всіх метрик цього Prometheus
  external_labels:
    student: 'surname'         # ← замініть на своє прізвище
    subnet:  '11.203.X.0/25'  # ← замініть X на номер варіанта

# --- Системні метрики (node_exporter) ---
scrape_configs:

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          host: 'mon'

  - job_name: 'node'
    static_configs:
      - targets:
          - '11.203.X.10:9100'
          - '11.203.X.11:9100'
          - '11.203.X.12:9100'
          - '11.203.X.14:9100'
          - '11.203.X.30:9100'
        labels:
          job: 'node'

  # --- Сервісні метрики ---

  - job_name: 'bind'
    static_configs:
      - targets: ['11.203.X.10:9119']
        labels:
          host: 'dns'

  - job_name: 'postfix'
    static_configs:
      - targets: ['11.203.X.11:9154']
        labels:
          host: 'smtp'

  - job_name: 'apache'
    static_configs:
      - targets: ['11.203.X.30:9117']
        labels:
          host: 'apache'
```

Перевірте синтаксис та перезавантажте:

```bash
sudo promtool check config /etc/prometheus/prometheus.yml
```

Очікуваний вивід:
```
Checking /etc/prometheus/prometheus.yml
  SUCCESS: /etc/prometheus/prometheus.yml is valid prometheus config file syntax
```

```bash
sudo systemctl reload prometheus
```

> `reload` (не `restart`) — Prometheus підхоплює конфіг без downtime і збереження даних TSDB.

---

## Крок 3.2 — Перевірка цілей у Prometheus UI

Відкрийте у браузері:

```
http://11.203.X.14:9090/targets
```

Всі цілі повинні мати статус `UP`:

```
State  Labels                         Last Scrape   Scrape Duration   Error
─────────────────────────────────────────────────────────────────────────────
UP     job="apache" host="apache"     12.3s ago     4.2ms
UP     job="bind" host="dns"          8.1s ago      3.1ms
UP     job="node" instance="...10"    5.4s ago      12.7ms
UP     job="node" instance="...11"    5.4s ago      11.2ms
UP     job="node" instance="...12"    5.4s ago      13.1ms
UP     job="node" instance="...14"    5.4s ago      10.5ms
UP     job="node" instance="...30"    5.4s ago      9.8ms
UP     job="postfix" host="smtp"      14.7s ago     5.3ms
UP     job="prometheus"               2.1s ago      2.3ms
```

> Якщо ціль у стані `DOWN` — натисніть на неї і прочитайте текст помилки. Найчастіша причина: exporter не запущений або firewall блокує порт.

---

## Крок 3.3 — Перші запити у Prometheus Expression Browser

Відкрийте:

```
http://11.203.X.14:9090/graph
```

У рядку запиту введіть PromQL-вирази та натискайте **Execute**:

```promql
# Список всіх VM та їх uptime
node_time_seconds - node_boot_time_seconds
```

```promql
# CPU utilization по кожній VM (0 = 0%, 1 = 100%)
1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))
```

```promql
# RAM використана у відсотках
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100
```

```promql
# DNS запити по типах за хвилину
rate(bind_incoming_queries_total[1m]) * 60
```

```promql
# Apache: запити на секунду
rate(apache_accesses_total[5m])
```

```promql
# Apache: зайняті воркери
apache_workers{state="busy"}
```

```promql
# Postfix: прийняті листи (загальна кількість)
postfix_smtpd_messages_processed_total{status="accepted"}
```

```promql
# Чи всі VM живі?
up
```

Перемкніться на вкладку **Graph** (замість Table) — побачите часовий ряд.

---

## Крок 3.4 — Імпорт готових дашбордів у Grafana

Grafana Labs публікує готові дашборди з ID. Імпортуємо по одному:

### Node Exporter Full (ID: 1860)

1. Grafana → ліве меню → **Dashboards** → **New** → **Import**
2. У полі **Import via grafana.com** введіть `1860` → **Load**
3. У полі **Prometheus** оберіть `Prometheus` (data source що додали у Кроці 4)
4. **Import**

Дашборд містить:
- CPU utilization з розбивкою по режимах (user/system/iowait)
- Memory: total / used / cached / buffered
- Disk I/O: read/write bytes per second
- Network: rx/tx bytes per second
- Uptime, load average

У верхній частині є фільтр `$node` — оберіть потрібну VM зі списку.

### Apache Overview (ID: 3894)

1. **Dashboards** → **New** → **Import** → введіть `3894` → **Load**
2. Оберіть data source Prometheus → **Import**

Дашборд показує:
- Requests per second
- Bytes per second
- Workers: busy / idle
- Scoreboard (стан воркерів)

---

## Крок 3.5 — Власний дашборд: Infrastructure Overview

Створимо дашборд, який показує стан всієї підмережі на одному екрані.

1. **Dashboards** → **New** → **New dashboard** → **Add visualization**

### Панель 1: Статус VM (таблиця)

- Тип: **Table**
- PromQL запит:
  ```promql
  up
  ```
- **Transform** → **Organize fields**: залишити лише `instance` та `Value`
- **Field override** для `Value`: Unit = `On/Off`
- Назва панелі: `VM Status`

### Панель 2: CPU по VM (часовий ряд)

- Тип: **Time series**
- PromQL запит (Label: `{{instance}}`):
  ```promql
  (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) * 100
  ```
- **Standard options** → Unit: `Percent (0-100)`
- Назва панелі: `CPU Utilization %`

### Панель 3: RAM по VM

- Тип: **Time series**
- PromQL запит (Label: `{{instance}}`):
  ```promql
  (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100
  ```
- Unit: `Percent (0-100)`
- Назва: `RAM Usage %`

### Панель 4: Apache RPS + Workers (дві метрики на одному графіку)

- Тип: **Time series**
- Запит A (Label: `RPS`):
  ```promql
  rate(apache_accesses_total[5m])
  ```
- Запит B (Label: `Busy Workers`):
  ```promql
  apache_workers{state="busy"}
  ```
- Назва: `Apache — Requests & Workers`

### Панель 5: DNS Query Rate

- Тип: **Time series**
- PromQL запит (Label: `{{type}}`):
  ```promql
  rate(bind_incoming_queries_total[5m])
  ```
- Unit: `Queries/sec`
- Назва: `DNS Query Rate by Type`

### Панель 6: Postfix — статус доставки

- Тип: **Stat**
- Запит A (Label: `Accepted`):
  ```promql
  postfix_smtpd_messages_processed_total{status="accepted"}
  ```
- Запит B (Label: `Rejected`):
  ```promql
  postfix_smtpd_messages_processed_total{status="rejected"}
  ```
- Назва: `Postfix — Message Totals`

### Збережіть дашборд:

- Натисніть іконку дискети (💾) вгорі праворуч
- Назва: `surname — Infrastructure Overview`
- Folder: `General`
- **Save**

---

## Крок 3.6 — Перевірка реакції системи на навантаження

Тест показує, як Grafana відображає реальні події в інфраструктурі.

### Тест 1: CPU spike на Apache VM

```bash
# На Apache VM (11.203.X.30) — запустити навантаження на 30 секунд
stress-ng --cpu 2 --timeout 30s &

# АБО без stress-ng:
for i in {1..4}; do
    yes > /dev/null &
done
sleep 30
kill %1 %2 %3 %4 2>/dev/null
```

У Grafana → дашборд CPU Utilization — побачите spike на `.30` через 15-30 секунд.

### Тест 2: HTTP навантаження на Apache

```bash
# З workstation (11.203.X.20) або mon VM (11.203.X.14)
sudo apt install -y apache2-utils   # для утиліти ab

ab -n 1000 -c 10 http://11.203.X.30/
```

У Grafana → Apache панель → бачите зростання RPS і Busy Workers під час тесту.

### Тест 3: DNS запити

```bash
# З будь-якої VM — надіслати DNS запити
for i in {1..100}; do
    dig @11.203.X.10 surname.tsa243.lab > /dev/null
done
```

Grafana → DNS панель → зростання `type="A"` запитів.

---

## Звіт про виконання роботи

| № | Що перевіряємо | Команда / дія | Очікуваний результат |
|---|---------------|--------------|----------------------|
| 1 | Prometheus запущений | `systemctl status prometheus` | `active (running)` |
| 2 | Grafana запущена | `http://11.203.X.14:3000` | Сторінка входу |
| 3 | Всі цілі UP | `http://11.203.X.14:9090/targets` | Усі зелені `UP` |
| 4 | node_exporter на DNS VM | `curl http://11.203.X.10:9100/metrics \| grep node_load1` | Числове значення |
| 5 | bind_exporter | `curl http://11.203.X.10:9119/metrics \| grep bind_incoming` | Лічильники DNS типів |
| 6 | apache_exporter | `curl http://11.203.X.30:9117/metrics \| grep apache_up` | `apache_up 1` |
| 7 | postfix_exporter | `curl http://11.203.X.11:9154/metrics \| grep postfix_up` | `postfix_up 1` |
| 8 | Дашборд Node Exporter Full | Grafana, ID 1860 | Графіки CPU/RAM по VM |
| 9 | Власний дашборд | Grafana, `surname — Infrastructure Overview` | 6 панелей, дані є |
| 10 | CPU spike видно | `stress-ng` → Grafana CPU панель | Spike на `.30` |

---

## Типові помилки та вирішення

| Помилка | Причина | Вирішення |
|---------|---------|-----------|
| Ціль в стані `DOWN` у Prometheus | Exporter не запущений або неправильний порт | `systemctl status <exporter>`, перевірити порт |
| `bind_exporter: connection refused` | Statistics Channel не увімкнено в BIND | Перевірити `named.conf.options`, рестарт `bind9` |
| `apache_exporter: no metrics` | `mod_status` не увімкнено або `ExtendedStatus Off` | `a2enmod status`, перевірити `status.conf` |
| `postfix_exporter: permission denied` | Немає прав читати `/var/log/mail.log` | `sudo usermod -aG adm prometheus-postfix-exporter` |
| Grafana: `No data` на панелі | Неправильний PromQL або data source | Перевірити запит в Prometheus Expression Browser |
| `promtool check config` — помилка | Помилка відступів у YAML | YAML чутливий до відступів; не використовувати Tab |

---

## Корисні команди — шпаргалка

```bash
# Перевірка конфігу Prometheus
sudo promtool check config /etc/prometheus/prometheus.yml

# Перезавантажити конфіг без рестарту
sudo systemctl reload prometheus

# Подивитись всі targets через API
curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool | grep '"health"'

# Перевірити що конкретна метрика є
curl -s http://localhost:9090/api/v1/query?query=up | python3 -m json.tool

# Статус всіх exporter-сервісів одразу
for svc in prometheus-node-exporter prometheus-bind-exporter \
           prometheus-postfix-exporter apache_exporter grafana-server prometheus; do
    state=$(systemctl is-active $svc 2>/dev/null || echo "not-found")
    printf "%-40s %s\n" "$svc" "$state"
done
```

---

## Структура проєкту на GitHub

```
lesson7_13/
└── README.md       ← Ця методичка
```

---

> Матеріал підготовлено для навчальних занять ВІТІ.  
> Дисципліна: Технології Системного Адміністрування | Курс 2-й | 2026
