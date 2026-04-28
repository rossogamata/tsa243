# Monitoring — Prometheus + Grafana

**VM:** `mon.surname.tsa243.lab` · `11.203.X.14`  
**Prometheus:** `:9090`  
**Grafana:** `:3000`

---

## Архітектура

Кожен курсант має **власний** Prometheus і Grafana.
Моніторить виключно свою підмережу `11.203.X.0/25`.

```
Prometheus (11.203.X.14:9090)
  scrape кожні 15s
  │
  ├─▶ node_exporter  11.203.X.10:9100   (DNS VM)
  ├─▶ node_exporter  11.203.X.11:9100   (SMTP VM)
  ├─▶ node_exporter  11.203.X.12:9100   (Nginx VM)
  ├─▶ node_exporter  11.203.X.13:9100   (HAProxy VM)
  ├─▶ node_exporter  11.203.X.20:9100   (Workstation)
  ├─▶ node_exporter  11.203.X.30:9100   (backend-01)
  └─▶ node_exporter  11.203.X.31:9100   (backend-02)

HAProxy Exporter (11.203.X.13:8405) → Prometheus
Nginx Exporter   (11.203.X.12:9113) → Prometheus
```

---

## Node exporter — встановлення на кожній VM

```bash
sudo apt install prometheus-node-exporter
sudo systemctl enable --now prometheus-node-exporter
# Перевірка: curl http://localhost:9100/metrics | head -20
```

---

## Конфігурація Prometheus `/etc/prometheus/prometheus.yml`

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets:
          - '11.203.X.10:9100'   # dns
          - '11.203.X.11:9100'   # mail
          - '11.203.X.12:9100'   # nginx
          - '11.203.X.13:9100'   # haproxy
          - '11.203.X.14:9100'   # monitoring itself
          - '11.203.X.20:9100'   # workstation
        labels:
          env: 'surname'

  - job_name: 'haproxy'
    static_configs:
      - targets: ['11.203.X.13:8405']
```

---

## Grafana — базові дашборди

| Dashboard ID | Назва | Що показує |
|-------------|-------|------------|
| 1860 | Node Exporter Full | CPU, RAM, диск, мережа по кожній VM |
| 367 | HAProxy | Backend статус, RPS, latency |
| 12708 | Nginx | Запити, помилки, upstream час відповіді |

Імпорт: **Dashboards → Import → вставити ID → Load**

---

## Що курсант бачить у Grafana

- Які VM живі, які ні
- CPU/RAM spike коли запускає навантажувальний тест
- HAProxy routing — рівномірний розподіл між backend-ами
- Disk usage — момент коли `/var/log` починає займати місце

---

## Навчальний момент

Моніторинг власної інфраструктури в реальному часі.
Курсант бачить наслідки своїх дій — запустив важкий процес → бачить spike на графіку.
На наступному курсі: той самий Prometheus scrape Docker-контейнери автоматично через service discovery.
