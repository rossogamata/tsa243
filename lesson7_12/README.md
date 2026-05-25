# Змістовний модуль 7. Адміністрування серверів та балансування навантаження
## ЗАНЯТТЯ 7_12 (Групове) — Системи моніторингу ІТ-інфраструктури

> **Дисципліна:** Технології Системного Адміністрування | **Курс:** 2-й  
> **ОС:** Ubuntu Server 24.04 LTS | **Тип заняття:** Групове  
> **Середовище:** Proxmox VE · підмережа курсанта `11.203.X.0/25`  
> **Час:** ~90 хвилин  
> **Попередні заняття:** lesson7_11 (Nginx LB), lesson7_10 (HAProxy)

---

## Навчальні питання

1. [Архітектура систем моніторингу. Pull vs Push](#питання-1--архітектура-систем-моніторингу-pull-vs-push)
2. [Система моніторингу на базі Prometheus & Grafana](#питання-2--prometheus--grafana)
3. [Prometheus exporters](#питання-3--prometheus-exporters)

---

## Місце заняття в архітектурі курсу

До цього заняття ланцюжок обробки трафіку в проекті `tsa243.lab` повністю побудований: DNS → SMTP → Nginx → HAProxy → backends. Тепер постає питання: **як дізнатися, що все це працює нормально?**

```
Інфраструктура tsa243.lab (курсанта X)

┌────────────────────────────────────────────────────────┐
│                  11.203.X.0/25                         │
│                                                        │
│  .10 — DNS (BIND9)         .12 — Nginx (reverse proxy) │
│  .11 — SMTP (Postfix)      .13 — HAProxy (LB)          │
│  .30 — backend-01          .31 — backend-02            │
│                                                        │
│  .20 — Prometheus + Grafana  ← ЦЕ ЗАНЯТТЯ             │
│          │                                             │
│          │  scrape metrics                             │
│          ├──────────────── .10 (node_exporter)         │
│          ├──────────────── .11 (node_exporter)         │
│          ├──────────────── .12 (nginx_exporter)        │
│          ├──────────────── .13 (haproxy_exporter)      │
│          ├──────────────── .30 (node_exporter)         │
│          └──────────────── .31 (node_exporter)         │
└────────────────────────────────────────────────────────┘
```

Система моніторингу — це не «бонус», а обов'язковий елемент будь-якої виробничої інфраструктури. Без неї адміністратор дізнається про відмову лише від користувача, а не від системи.

---

# Питання 1 — Архітектура систем моніторингу. Pull vs Push

## 1.1 Навіщо моніторинг?

**Три класи подій, які треба виявляти:**

| Клас | Приклад | Наслідок без моніторингу |
|------|---------|--------------------------|
| **Відмова сервісу** | Nginx перестав відповідати | Простій до моменту скарги користувача |
| **Деградація** | Диск заповнений на 95% | Сервіс впаде через годину |
| **Аномалія** | CPU 100% опівночі | Можлива атака або витік пам'яті |

**Ключова концепція:** система моніторингу повинна **завчасно попереджати** про проблему — не фіксувати факт відмови, а виявляти тренд, що до неї веде.

```
Без моніторингу:
  Диск заповнився → Сервіс впав → Користувач подзвонив → Адмін почав розбиратись

З моніторингом:
  Диск 80% → Алерт → Адмін розчистив → Сервіс не падав
```

## 1.2 Що збирає система моніторингу?

**Чотири типи телеметричних даних (4 стовпи спостережуваності):**

```
┌────────────────────────────────────────────────────────────┐
│              Спостережуваність (Observability)             │
│                                                            │
│  Metrics    Logs      Traces     Events                    │
│  ─────────  ────────  ─────────  ──────────                │
│  CPU 82%    [ERROR]   req→svc→   config                    │
│  RAM 4.2GB  404 /api  db→cache   changed                   │
│  rps: 1200  timeout   15ms       deploy v2                 │
│                                                            │
│  ↑ числові  ↑ текст   ↑ шлях     ↑ разові                  │
│  в часі     події     запиту     зміни                     │
└────────────────────────────────────────────────────────────┘
```

| Тип | Що це | Інструменти |
|-----|-------|-------------|
| **Metrics** | Числові показники в часі (CPU%, rps, latency) | Prometheus, InfluxDB, Graphite |
| **Logs** | Текстові записи подій | ELK Stack, Loki, Graylog |
| **Traces** | Шлях запиту між мікросервісами | Jaeger, Zipkin, Tempo |
| **Events** | Разові зміни стану | PagerDuty, OpsGenie |

> На цьому занятті фокус на **Metrics** — числових показниках, які збирає Prometheus.

## 1.3 Архітектура: Pull vs Push

Це фундаментальний вибір архітектури — **хто ініціює збір даних:**

```
PULL (витягування)                   PUSH (проштовхування)
─────────────────────────────────    ──────────────────────────────────

  Моніторинг сервер                    Агент на VM
      │                                    │
      │  GET /metrics (кожні 15с)          │  надсилає метрики
      ▼                                    ▼
    VM з exporter                       Моніторинг сервер
    (пасивно чекає)                     (пасивно приймає)

  Ініціатор: сервер моніторингу        Ініціатор: агент на VM
  Приклади: Prometheus                 Приклади: Graphite, InfluxDB,
                                                 Zabbix (агент)
```

### Pull-модель (Prometheus)

```
Prometheus Server
┌──────────────────────────────────┐
│  Scheduler                       │
│  ┌─────────────────────────────┐ │
│  │ targets:                    │ │
│  │  - 11.203.X.10:9100         │ │
│  │  - 11.203.X.12:9113         │ │
│  │  - 11.203.X.13:9101         │ │
│  └──────────────┬──────────────┘ │
│                 │ кожні 15с      │
│  ┌──────────────▼──────────────┐ │
│  │ HTTP GET /metrics           │ │
│  └──────────────┬──────────────┘ │
│                 │                │
│  ┌──────────────▼──────────────┐ │
│  │ TSDB (time series database) │ │
│  └─────────────────────────────┘ │
└──────────────────────────────────┘
         │                │
         ▼                ▼
      Grafana          Alertmanager
   (візуалізація)      (сповіщення)
```

**Переваги Pull:**
- Конфігурація централізована — список цілей в одному місці (сервер знає, що моніторити)
- Легко перевірити: `curl http://11.203.X.10:9100/metrics` — бачиш те, що бачить Prometheus
- Автоматична перевірка доступності: якщо ціль не відповіла — вже є алерт
- Не потрібно налаштовувати мережевий доступ від кожної VM до сервера

**Недоліки Pull:**
- Складно збирати метрики за NAT (сервер не може дотягнутись до VM)
- Не підходить для короткоживучих задач (batch job завершився до scrape)
- Потрібен відкритий порт на кожній VM (exporter слухає HTTP)

### Push-модель (StatsD / Graphite / Telegraf)

```
VM-01    VM-02    VM-03   (короткоживучий batch job)
  │        │        │               │
  │UDP     │UDP     │UDP            │ (надсилає перед завершенням)
  ▼        ▼        ▼               ▼
┌─────────────────────────────────────┐
│         Statsd / Graphite           │
│         (колектор)                  │
│         Приймає UDP метрики         │
│         Агрегує                     │
│         Зберігає                    │
└─────────────────────────────────────┘
```

**Переваги Push:**
- Працює за NAT і firewall (VM сама ініціює з'єднання)
- Підходить для batch jobs (надсилає перед завершенням)
- Низька затримка (UDP, без очікування scrape-інтервалу)

**Недоліки Push:**
- Конфігурація розподілена: адреса колектора на кожній VM
- Якщо VM впала — ніяких даних та ніякого алерту (на відміну від Pull)
- Складніше масштабувати (колектор — єдина точка прийому)

### Порівняльна таблиця

| Критерій | Pull (Prometheus) | Push (Graphite/InfluxDB) |
|----------|-------------------|--------------------------|
| **Ініціатор** | Сервер моніторингу | Агент на VM |
| **Конфігурація** | Централізована (сервер) | Розподілена (кожна VM) |
| **NAT / Firewall** | Проблема (сервер не дістане) | Немає проблем |
| **Короткі задачі** | Проблема (job завершиться до scrape) | Підходить |
| **Виявлення відмови** | Автоматично (ціль не відповіла) | Ні (просто немає даних) |
| **Протокол** | HTTP GET | UDP або TCP |
| **Перевірка** | `curl /metrics` | Складніше |

### Рішення для короткоживучих задач у Prometheus

Prometheus вирішує проблему batch jobs через **Pushgateway** — проміжний компонент:

```
Batch job (завершується за 10с)
    │
    │  POST /metrics (перед завершенням)
    ▼
 Pushgateway             ← зберігає метрики
    │
    │  GET /metrics (кожні 15с)
    ▼
 Prometheus Server
```

> Pushgateway — виняток із правил, не архітектурний елемент. Використовується лише для batch jobs, не для постійних сервісів.

---

# Питання 2 — Prometheus & Grafana

## 2.1 Prometheus — що це?

**Prometheus** — open-source система моніторингу та збору метрик, розроблена у SoundCloud (2012), переданий у CNCF (2016). Стандарт у хмарній інфраструктурі та Kubernetes-оточеннях.

**Ключові характеристики:**
- Pull-архітектура: сам збирає метрики з цілей кожні N секунд
- Власна база даних часових рядів (TSDB) — оптимізована для метрик
- Мова запитів **PromQL** — потужна, але потребує вивчення
- Вбудований HTTP UI для перевірки запитів
- Підтримка **alerting rules** та інтеграція з Alertmanager

## 2.2 Компоненти екосистеми Prometheus

```
┌──────────────────────────────────────────────────────────────────┐
│                      Prometheus Ecosystem                        │
│                                                                  │
│  ┌──────────────┐    scrape     ┌────────────────────────────┐   │
│  │  Exporters   │◄──────────────│                            │   │
│  │              │               │   Prometheus Server        │   │
│  │ node_exporter│               │                            │   │
│  │ nginx_exporter│              │  ┌──────┐  ┌───────────┐  │   │
│  │ haproxy_exp. │               │  │ TSDB │  │  PromQL   │  │   │
│  │ blackbox_exp.│               │  │      │  │  engine   │  │   │
│  │ custom_exp.  │               │  └──────┘  └───────────┘  │   │
│  └──────────────┘               │       │           │        │   │
│                                 │  ┌────▼───────────▼────┐  │   │
│  ┌──────────────┐               │  │   Alerting Rules    │  │   │
│  │  Pushgateway │◄──────────────│  └─────────┬───────────┘  │   │
│  │  (batch jobs)│    scrape     │            │              │   │
│  └──────────────┘               └────────────┼─────────────┘   │
│                                              │                  │
│  ┌──────────────┐               ┌────────────▼─────────────┐   │
│  │   Grafana    │◄──────────────│     Alertmanager          │   │
│  │ (дашборди)   │    PromQL     │  (email/Slack/PagerDuty)  │   │
│  └──────────────┘               └──────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

## 2.3 Типи метрик у Prometheus

Prometheus визначає **4 типи метрик:**

### Counter (лічильник)

```
Монотонно зростає. Ніколи не зменшується. Скидається лише при рестарті.

http_requests_total{method="GET", status="200"} 1028349
http_requests_total{method="POST", status="404"} 342

Використовується для:
  - Кількість запитів
  - Кількість помилок
  - Кількість байт переданих
```

> В PromQL для Counter використовують `rate()` або `increase()` — не саме значення.

### Gauge (вимірювач)

```
Довільне число: може зростати та зменшуватись.

node_memory_MemAvailable_bytes 2147483648
node_load1 0.75
nginx_connections_active 42

Використовується для:
  - CPU%, RAM%
  - Кількість активних з'єднань
  - Температура
  - Розмір черги
```

### Histogram (гістограма)

```
Розподіл значень за бакетами. Автоматично генерує три метрики:
  _bucket{le="0.1"}   — скільки запитів < 100ms
  _bucket{le="0.5"}   — скільки запитів < 500ms
  _bucket{le="1"}     — скільки запитів < 1s
  _bucket{le="+Inf"}  — всі запити
  _count              — загальна кількість
  _sum                — сума всіх значень

http_request_duration_seconds_bucket{le="0.1"} 8324
http_request_duration_seconds_bucket{le="0.5"} 9876
http_request_duration_seconds_bucket{le="1"}   9999
http_request_duration_seconds_count            10000
http_request_duration_seconds_sum              487.3

Використовується для: latency, розмір запитів/відповідей
```

### Summary (зведення)

```
Подібний до Histogram, але обчислює квантилі на стороні клієнта:

go_gc_duration_seconds{quantile="0.5"}  0.000123
go_gc_duration_seconds{quantile="0.9"}  0.000456
go_gc_duration_seconds{quantile="0.99"} 0.001234
go_gc_duration_seconds_count            42
go_gc_duration_seconds_sum              0.0152

Недолік: квантилі не можна агрегувати між інстансами.
Перевага Histogram: квантилі обчислюються на Prometheus → можна агрегувати.
```

## 2.4 Формат метрик (text exposition format)

Кожен exporter відповідає на `GET /metrics` у текстовому форматі:

```
# HELP node_cpu_seconds_total Seconds the CPUs spent in each mode.
# TYPE node_cpu_seconds_total counter
node_cpu_seconds_total{cpu="0",mode="idle"}    12345.67
node_cpu_seconds_total{cpu="0",mode="system"}  234.56
node_cpu_seconds_total{cpu="0",mode="user"}    567.89
node_cpu_seconds_total{cpu="1",mode="idle"}    12100.11
node_cpu_seconds_total{cpu="1",mode="system"}  198.43
node_cpu_seconds_total{cpu="1",mode="user"}    612.04

# HELP node_memory_MemTotal_bytes Memory information field MemTotal.
# TYPE node_memory_MemTotal_bytes gauge
node_memory_MemTotal_bytes 8589934592

# HELP node_disk_read_bytes_total The total number of bytes read successfully.
# TYPE node_disk_read_bytes_total counter
node_disk_read_bytes_total{device="sda"} 1.073741824e+10
```

**Структура рядка метрики:**
```
metric_name{label1="value1", label2="value2"} numeric_value [timestamp]
    │              │                                │
    │              │                                └── float64 або int
    │              └── довільні пари ключ-значення (мета)
    └── snake_case, літери/цифри/підкреслення
```

> Мітки (labels) — потужний механізм. Одна метрика `http_requests_total` з мітками `{method, status, endpoint}` замінює десятки окремих лічильників.

## 2.5 Конфігурація Prometheus

Основний файл `/etc/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval:     15s   # як часто збирати метрики
  evaluation_interval: 15s   # як часто обчислювати правила алертів

# Правила алертів (файли з .rules.yml)
rule_files:
  - "/etc/prometheus/rules/*.yml"

# Куди надсилати алерти
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

# Список цілей для scrape
scrape_configs:

  # Сам Prometheus моніторить себе
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node exporter на всіх VM
  - job_name: 'node'
    static_configs:
      - targets:
          - '11.203.X.10:9100'   # DNS VM
          - '11.203.X.11:9100'   # SMTP VM
          - '11.203.X.12:9100'   # Nginx VM
          - '11.203.X.13:9100'   # HAProxy VM
          - '11.203.X.30:9100'   # backend-01
          - '11.203.X.31:9100'   # backend-02
        labels:
          student: 'surname'     # ваше прізвище

  # Nginx exporter
  - job_name: 'nginx'
    static_configs:
      - targets: ['11.203.X.12:9113']

  # HAProxy exporter
  - job_name: 'haproxy'
    static_configs:
      - targets: ['11.203.X.13:9101']
```

## 2.6 PromQL — мова запитів

**PromQL (Prometheus Query Language)** — функціональна мова для роботи з часовими рядами.

### Базові запити

```promql
# Всі метрики з ім'ям node_load1
node_load1

# Фільтр за міткою
node_load1{job="node"}
node_cpu_seconds_total{mode="idle", cpu="0"}

# Регулярний вираз у мітці
node_cpu_seconds_total{mode=~"user|system"}

# Виключення
node_cpu_seconds_total{mode!="idle"}
```

### Функції для Counter

```promql
# Швидкість зростання за останні 5 хвилин (rate/s)
rate(http_requests_total[5m])

# Збільшення за останній час
increase(http_requests_total[1h])

# Кількість запитів за хвилину
rate(http_requests_total[5m]) * 60
```

### Агрегація

```promql
# Сумарне навантаження по всіх CPU
sum(rate(node_cpu_seconds_total{mode!="idle"}[5m]))

# По кожному хосту окремо
sum by (instance) (rate(node_cpu_seconds_total{mode!="idle"}[5m]))

# CPU% (нормований від 0 до 1)
1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))

# RAM% використана
1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)

# Вільний диск у відсотках
node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}
```

### Корисні алертинг-запити

```promql
# VM недоступна більше 1 хвилини
up == 0

# CPU > 80% протягом 5 хвилин
(1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) > 0.8

# Диск заповнений > 90%
(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) > 0.9

# RAM > 85%
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 0.85
```

## 2.7 Grafana — візуалізація

**Grafana** — open-source платформа для візуалізації метрик, логів та трейсів. Підключається до Prometheus як **Data Source** і будує дашборди.

```
┌─────────────────────────────────────────────────────────┐
│                    Grafana Dashboard                     │
│                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │   CPU %     │  │   RAM %     │  │  Network I/O    │  │
│  │  ▂▃▅▇▆▄▃▂  │  │  ▄▄▅▅▆▆▅▄  │  │  ↑ ▂▃▃▄▄▃▂▂    │  │
│  │   42%       │  │   68%       │  │  ↓ ▁▂▂▃▃▂▁▁    │  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
│                                                          │
│  ┌─────────────────────────────────────────────────────┐ │
│  │   HTTP Requests per second (by backend)             │ │
│  │  3000 ┤                                              │ │
│  │  2000 ┤    ╭──╮  ╭──╮                               │ │
│  │  1000 ┤────╯  ╰──╯  ╰─────────────────              │ │
│  │     0 └────────────────────────────────             │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌──────────────────┐  ┌──────────────────────────────┐  │
│  │  Disk Usage      │  │  Active HTTP Connections     │  │
│  │  /: 34%  ███░░░ │  │  backend-01: 127             │  │
│  │  /var: 67% █████ │  │  backend-02: 134             │  │
│  └──────────────────┘  └──────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Ключові концепції Grafana:**

| Поняття | Опис |
|---------|------|
| **Data Source** | Підключення до бази метрик (Prometheus, InfluxDB, Loki) |
| **Dashboard** | Набір панелей на одній сторінці |
| **Panel** | Окремий графік або таблиця; містить PromQL-запит |
| **Variable** | Динамічний фільтр: `$instance`, `$job` — змінює всі панелі разом |
| **Alert** | Правило в Grafana, яке спрацьовує при перевищенні порогу |
| **Provisioning** | Автоматичне підключення Data Source та дашбордів через YAML |

**Потік даних:**

```
Browser → Grafana UI
              │
              │  PromQL query (через API)
              ▼
         Prometheus
              │
              │  результат (масив time series)
              ▼
         Grafana Panel
              │
              │  renderує графік
              ▼
         Browser (відображення)
```

## 2.8 Алертинг: Prometheus Alertmanager

**Alertmanager** приймає алерти від Prometheus і надсилає сповіщення:

```yaml
# /etc/prometheus/rules/node.yml

groups:
  - name: node_alerts
    rules:

      # VM недоступна
      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "VM {{ $labels.instance }} недоступна"
          description: "{{ $labels.instance }} не відповідає більше 1 хвилини"

      # Диск > 90%
      - alert: DiskAlmostFull
        expr: >
          (1 - node_filesystem_avail_bytes{mountpoint="/"} /
               node_filesystem_size_bytes{mountpoint="/"}) > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Диск майже заповнений на {{ $labels.instance }}"

      # CPU > 80%
      - alert: HighCPU
        expr: >
          (1 - avg by (instance) (
            rate(node_cpu_seconds_total{mode="idle"}[5m])
          )) > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Високе навантаження CPU на {{ $labels.instance }}"
```

**Стани алерту:**

```
INACTIVE → PENDING → FIRING
              │
              └─ for: 5m — якщо умова виконується 5 хвилин підряд
                           → переходить у FIRING → Alertmanager надсилає
```

---

# Питання 3 — Prometheus Exporters

## 3.1 Що таке exporter?

**Exporter** — програма, яка:
1. Зчитує стан системи або застосунку (з файлів, сокетів, API)
2. Перетворює в формат Prometheus метрик
3. Відповідає на `GET /metrics` по HTTP

```
┌────────────────────────────────────────────────────┐
│  VM з Node Exporter (11.203.X.10:9100)             │
│                                                    │
│  /proc/stat          ┌──────────────┐              │
│  /proc/meminfo  ───► │              │  GET /metrics │
│  /sys/block/sda │    │ node_exporter│◄─────────────┼──── Prometheus
│  /sys/class/net │    │              │              │
│  /proc/net/     ───► │              │  text/plain   │
│                      └──────────────┘  (метрики)   │
└────────────────────────────────────────────────────┘
```

## 3.2 Node Exporter — системні метрики

**node_exporter** — стандартний exporter для Linux/Unix систем. Збирає сотні метрик ОС.

**Встановлення:**

```bash
# Завантажити останню версію
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz

tar xvf node_exporter-1.8.2.linux-amd64.tar.gz
sudo cp node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/
```

**Systemd unit (`/etc/systemd/system/node_exporter.service`):**

```ini
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=node_exporter
ExecStart=/usr/local/bin/node_exporter \
    --collector.systemd \
    --collector.processes
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```bash
sudo useradd -rs /bin/false node_exporter
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter

# Перевірка
curl -s http://localhost:9100/metrics | head -20
```

**Основні метрики node_exporter:**

| Метрика | Тип | Опис |
|---------|-----|------|
| `node_cpu_seconds_total` | Counter | Час CPU в кожному режимі (idle/user/system) |
| `node_memory_MemTotal_bytes` | Gauge | Загальна RAM |
| `node_memory_MemAvailable_bytes` | Gauge | Доступна RAM |
| `node_filesystem_avail_bytes` | Gauge | Вільний простір на диску |
| `node_filesystem_size_bytes` | Gauge | Загальний розмір диску |
| `node_network_receive_bytes_total` | Counter | Байт отримано на мережевому інтерфейсі |
| `node_network_transmit_bytes_total` | Counter | Байт надіслано |
| `node_load1` / `node_load5` / `node_load15` | Gauge | Load average (1/5/15 хв) |
| `node_disk_read_bytes_total` | Counter | Байт прочитано з диску |
| `node_disk_written_bytes_total` | Counter | Байт записано на диск |
| `node_systemd_unit_state` | Gauge | Стан systemd-сервісу (1=active) |
| `node_time_seconds` | Gauge | Поточний час (для перевірки NTP) |

**Корисні PromQL-запити для node_exporter:**

```promql
# CPU utilization (без idle), нормований 0..1
1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))

# RAM використання в %
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# Мережевий трафік (байт/с на eth0)
rate(node_network_receive_bytes_total{device="eth0"}[5m])
rate(node_network_transmit_bytes_total{device="eth0"}[5m])

# Диск заповнений у відсотках
(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100

# Стан сервісу nginx
node_systemd_unit_state{name="nginx.service", state="active"}
```

## 3.3 Nginx Exporter

**nginx-prometheus-exporter** читає статистику зі сторінки `stub_status` Nginx.

**Передумова — увімкнути stub_status в Nginx:**

```nginx
# /etc/nginx/conf.d/stub_status.conf
server {
    listen 127.0.0.1:8080;

    location /stub_status {
        stub_status;
        allow 127.0.0.1;
        deny all;
    }
}
```

```bash
# Перевірка stub_status
curl http://127.0.0.1:8080/stub_status
```

Очікуваний вивід:
```
Active connections: 42
server accepts handled requests
 18350 18350 73867
Reading: 0 Writing: 1 Waiting: 41
```

**Встановлення nginx-prometheus-exporter:**

```bash
wget https://github.com/nginxinc/nginx-prometheus-exporter/releases/download/v1.3.0/nginx-prometheus-exporter_1.3.0_linux_amd64.tar.gz
tar xvf nginx-prometheus-exporter_1.3.0_linux_amd64.tar.gz
sudo cp nginx-prometheus-exporter /usr/local/bin/
```

**Systemd unit:**

```ini
[Unit]
Description=Nginx Prometheus Exporter
After=network.target nginx.service

[Service]
Type=simple
User=www-data
ExecStart=/usr/local/bin/nginx-prometheus-exporter \
    --nginx.scrape-uri=http://127.0.0.1:8080/stub_status \
    --web.listen-address=:9113
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

**Метрики nginx_exporter:**

| Метрика | Тип | Опис |
|---------|-----|------|
| `nginx_connections_active` | Gauge | Активні з'єднання |
| `nginx_connections_accepted_total` | Counter | Прийнято з'єднань всього |
| `nginx_connections_handled_total` | Counter | Оброблено з'єднань |
| `nginx_http_requests_total` | Counter | Запити всього |
| `nginx_connections_reading` | Gauge | З'єднань у стані читання |
| `nginx_connections_writing` | Gauge | З'єднань у стані запису |
| `nginx_connections_waiting` | Gauge | З'єднань у стані очікування (keep-alive) |
| `nginx_up` | Gauge | 1 якщо Nginx доступний |

```promql
# Запити на секунду через Nginx
rate(nginx_http_requests_total[5m])

# Поточне навантаження (активні з'єднання)
nginx_connections_active

# Nginx впав?
nginx_up == 0
```

## 3.4 HAProxy Exporter

**haproxy_exporter** читає статистику з HAProxy Stats socket або Stats page.

**Передумова — увімкнути stats у HAProxy:**

```
# /etc/haproxy/haproxy.cfg — додати секцію:
listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
    stats admin if LOCALHOST
```

**Встановлення:**

```bash
wget https://github.com/prometheus/haproxy_exporter/releases/download/v0.15.0/haproxy_exporter-0.15.0.linux-amd64.tar.gz
tar xvf haproxy_exporter-0.15.0.linux-amd64.tar.gz
sudo cp haproxy_exporter-0.15.0.linux-amd64/haproxy_exporter /usr/local/bin/
```

**Systemd unit:**

```ini
[Unit]
Description=HAProxy Exporter
After=haproxy.service

[Service]
Type=simple
ExecStart=/usr/local/bin/haproxy_exporter \
    --haproxy.scrape-uri=http://localhost:8404/stats?stats;csv \
    --web.listen-address=:9101
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

**Ключові метрики haproxy_exporter:**

| Метрика | Тип | Опис |
|---------|-----|------|
| `haproxy_backend_current_sessions` | Gauge | Активні сесії на backend |
| `haproxy_backend_http_requests_total` | Counter | HTTP запити на backend |
| `haproxy_backend_response_errors_total` | Counter | Помилки відповіді backend |
| `haproxy_backend_up` | Gauge | 1 якщо backend доступний |
| `haproxy_server_up` | Gauge | 1 якщо конкретний server доступний |
| `haproxy_frontend_bytes_in_total` | Counter | Байт отримано на frontend |
| `haproxy_frontend_bytes_out_total` | Counter | Байт надіслано з frontend |
| `haproxy_server_current_sessions` | Gauge | Активні сесії на конкретному server |

```promql
# Який backend отримує більше трафіку?
rate(haproxy_backend_http_requests_total[5m])

# Backend недоступний
haproxy_backend_up == 0

# Рівень помилок > 1%
rate(haproxy_backend_response_errors_total[5m])
  / rate(haproxy_backend_http_requests_total[5m]) > 0.01
```

## 3.5 Blackbox Exporter — перевірка доступності

**blackbox_exporter** перевіряє доступність зовнішніх ендпоінтів (HTTP, HTTPS, DNS, TCP, ICMP) — тобто те, що бачить користувач, а не самі сервери.

```
Prometheus → blackbox_exporter → http://surname.tsa243.lab
                                 (перевірка ззовні)
```

**Конфігурація `/etc/prometheus/blackbox.yml`:**

```yaml
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
      valid_status_codes: [200]
      method: GET
      follow_redirects: true
      tls_config:
        insecure_skip_verify: false

  http_post_2xx:
    prober: http
    http:
      method: POST

  tcp_connect:
    prober: tcp
    timeout: 5s

  dns_check:
    prober: dns
    dns:
      query_name: "surname.tsa243.lab"
      query_type: "A"

  icmp_ping:
    prober: icmp
    timeout: 5s
```

**Scrape config у Prometheus для blackbox:**

```yaml
scrape_configs:
  - job_name: 'blackbox_http'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - http://surname.tsa243.lab
          - http://surname.tsa243.lab/health
          - https://surname.tsa243.lab
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 11.203.X.20:9115    # адреса blackbox_exporter
```

**Ключові метрики blackbox_exporter:**

| Метрика | Тип | Опис |
|---------|-----|------|
| `probe_success` | Gauge | 1 = успіх, 0 = невдача |
| `probe_duration_seconds` | Gauge | Час перевірки |
| `probe_http_status_code` | Gauge | HTTP статус-код відповіді |
| `probe_http_ssl` | Gauge | 1 якщо використано SSL |
| `probe_ssl_earliest_cert_expiry` | Gauge | Unix timestamp закінчення сертифікату |
| `probe_dns_lookup_time_seconds` | Gauge | Час DNS-розв'язання |

```promql
# Сервіс недоступний
probe_success{job="blackbox_http"} == 0

# Час відповіді > 1 секунда
probe_duration_seconds > 1

# Сертифікат закінчується менш ніж через 7 днів
probe_ssl_earliest_cert_expiry - time() < 7 * 24 * 3600
```

## 3.6 Порівняльна таблиця exporters

| Exporter | Порт | Що моніторить | Де встановлювати |
|----------|------|---------------|-----------------|
| **node_exporter** | 9100 | CPU, RAM, диск, мережа, ОС | На кожній VM |
| **nginx-prometheus-exporter** | 9113 | Nginx connections, requests | На Nginx VM |
| **haproxy_exporter** | 9101 | HAProxy backends, sessions | На HAProxy VM |
| **blackbox_exporter** | 9115 | HTTP/TCP/DNS/ICMP ендпоінти | На Prometheus VM |
| **process-exporter** | 9256 | Конкретні процеси | На будь-якій VM |
| **postgres_exporter** | 9187 | PostgreSQL | На DB VM |
| **redis_exporter** | 9121 | Redis | На Redis VM |
| **mysqld_exporter** | 9104 | MySQL/MariaDB | На DB VM |

## 3.7 Власний (custom) exporter

Якщо стандартного exporter немає — написати свій просто. Ось мінімальний приклад на Python:

```python
#!/usr/bin/env python3
"""
Приклад custom exporter: перевіряє кількість записів у файлі.
Відповідає на GET /metrics у форматі Prometheus.
"""

from prometheus_client import start_http_server, Gauge
import time, subprocess

# Оголошення метрики
MAIL_QUEUE_SIZE = Gauge(
    'postfix_queue_size',
    'Кількість листів у черзі Postfix'
)

def collect_metrics():
    """Збирає дані і оновлює метрики."""
    result = subprocess.run(
        ['mailq'],
        capture_output=True, text=True
    )
    # Підрахунок рядків у черзі
    lines = [l for l in result.stdout.split('\n') if l.startswith('-')]
    MAIL_QUEUE_SIZE.set(len(lines))

if __name__ == '__main__':
    start_http_server(9199)    # слухати на порту 9199
    print("Custom exporter запущено на :9199")
    while True:
        collect_metrics()
        time.sleep(15)         # оновлювати кожні 15 секунд
```

```bash
pip3 install prometheus_client
python3 custom_exporter.py &

# Перевірка
curl http://localhost:9199/metrics | grep postfix
```

---

## Підсумкова схема заняття

```
Архітектура моніторингу проекту tsa243.lab (курсанта X)

  ┌─────────────────────────────────────────────────────────────┐
  │                 Prometheus (11.203.X.20:9090)               │
  │   prometheus.yml                                            │
  │   scrape_interval: 15s                                      │
  └──────────────────────────────────────────────────────────── ┘
         │            │           │           │           │
         │scrape       │scrape     │scrape     │scrape     │scrape
         ▼            ▼           ▼           ▼           ▼
  .10:9100      .11:9100    .12:9100    .12:9113    .13:9101
  node_exp.     node_exp.   node_exp.   nginx_exp.  haproxy_exp.
  (DNS VM)      (SMTP VM)   (Nginx VM)  (Nginx VM)  (HAProxy VM)

         │            │           │
         │scrape       │scrape     │ blackbox probe
         ▼            ▼           ▼
  .30:9100      .31:9100    http://surname.tsa243.lab
  node_exp.     node_exp.   (перевірка ззовні)
  (backend01)   (backend02)


  Grafana (11.203.X.20:3000)
  └── Data Source: Prometheus → http://localhost:9090
  └── Dashboard: Node Overview (CPU/RAM/Disk/Network)
  └── Dashboard: Nginx & HAProxy
  └── Alerts: InstanceDown, DiskFull, HighCPU

  Alertmanager (11.203.X.20:9093)
  └── email → rossogamata@gmail.com (або ваша пошта)
```

---

## Запитання для самоперевірки

1. У чому принципова різниця між Pull і Push моделями збору метрик? Наведіть по одному прикладу кожної.

2. Яка з моделей (Pull/Push) краще виявляє відмову VM, і чому?

3. Перелічіть чотири типи метрик Prometheus. Для якого типу не можна використовувати саме значення, а потрібна функція `rate()`?

4. Чому Counter ніколи не зменшується? Що відбувається при рестарті сервісу з метрикою типу Counter?

5. Який exporter встановлюється на кожну VM? На якому порту він слухає?

6. Чим blackbox_exporter відрізняється від node_exporter архітектурно? (підказка: де ініціюється перевірка)

7. Запишіть PromQL-запит для обчислення CPU utilization у відсотках по кожному хосту.

8. Що таке алерт у стані `PENDING`? Навіщо потрібна затримка `for: 5m`?

---

## Корисні посилання

- Prometheus документація: [prometheus.io/docs](https://prometheus.io/docs)
- Список офіційних exporters: [prometheus.io/docs/instrumenting/exporters](https://prometheus.io/docs/instrumenting/exporters/)
- Grafana Dashboard для node_exporter: ID `1860` (Node Exporter Full) на grafana.com/dashboards
- PromQL cheatsheet: [promlabs.com/promql-cheat-sheet](https://promlabs.com/promql-cheat-sheet/)

---

## Структура проєкту на GitHub

```
lesson7_12/
└── README.md       ← Ця методичка
```

---

> Матеріал підготовлено для навчальних занять ВІТІ.  
> Дисципліна: Технології Системного Адміністрування | Курс 2-й | 2026
