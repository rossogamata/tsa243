# Monitoring — mon.tsa243.lab

**VM:** `mon.tsa243.lab` · `192.168.177.13`  
**Сервіси:** Prometheus (:9090) · Grafana (:3000)

---

## Що керує викладач

- Встановлення Prometheus і Grafana
- Базовий дашборд для всієї мережі `tsa243.lab`
- Конфігурація `prometheus.yml` зі scrape targets

## Що робить кожен курсант

1. Встановлює `node_exporter` на власній VM:
   ```bash
   sudo apt install prometheus-node-exporter
   sudo systemctl enable --now prometheus-node-exporter
   ```
2. Перевіряє метрики локально: `curl http://localhost:9100/metrics`
3. Повідомляє викладача — його VM додається в `prometheus.yml` як scrape target
4. Відкриває Grafana `http://mon.tsa243.lab:3000` і знаходить свій хост на дашборді

## Scrape target у prometheus.yml

```yaml
- job_name: 'node'
  static_configs:
    - targets:
      - '192.168.177.101:9100'  # surname01
      - '192.168.177.102:9100'  # surname02
      # ...
```

## Навчальний момент

Моніторинг як інфраструктурна практика, а не теорія.
Курсант бачить власні метрики CPU/RAM/диску в реальному часі.
На наступному курсі — автоматичне додавання targets через Ansible.
