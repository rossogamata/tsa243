# Infrastructure — tsa243.lab

**Мережа:** `192.168.177.0/24`  
**Домен:** `tsa243.lab`

---

## Спільні VM (instructor managed)

| IP | Hostname | Сервіси | ОС |
|----|----------|---------|-----|
| 192.168.177.1 | `gateway.tsa243.lab` | routing, NAT | — |
| 192.168.177.10 | `ns1.tsa243.lab` | BIND9 | Ubuntu 24.04 |
| 192.168.177.11 | `mail.tsa243.lab` | Postfix, Dovecot | Ubuntu 24.04 |
| 192.168.177.12 | `proxy.tsa243.lab` | Nginx | Ubuntu 24.04 |
| 192.168.177.13 | `mon.tsa243.lab` | Prometheus, Grafana | Ubuntu 24.04 |

---

## Індивідуальні VM курсантів

| IP | Hostname | Курсант |
|----|----------|---------|
| 192.168.177.101 | `__.tsa243.lab` | |
| 192.168.177.102 | `__.tsa243.lab` | |
| 192.168.177.103 | `__.tsa243.lab` | |
| 192.168.177.104 | `__.tsa243.lab` | |
| 192.168.177.105 | `__.tsa243.lab` | |
| 192.168.177.106 | `__.tsa243.lab` | |
| 192.168.177.107 | `__.tsa243.lab` | |
| 192.168.177.108 | `__.tsa243.lab` | |
| 192.168.177.109 | `__.tsa243.lab` | |
| 192.168.177.110 | `__.tsa243.lab` | |
| 192.168.177.111 | `__.tsa243.lab` | |
| 192.168.177.112 | `__.tsa243.lab` | |
| 192.168.177.113 | `__.tsa243.lab` | |
| 192.168.177.114 | `__.tsa243.lab` | |
| 192.168.177.115 | `__.tsa243.lab` | |
| 192.168.177.116 | `__.tsa243.lab` | |
| 192.168.177.117 | `__.tsa243.lab` | |
| 192.168.177.118 | `__.tsa243.lab` | |
| 192.168.177.119 | `__.tsa243.lab` | |
| 192.168.177.120 | `__.tsa243.lab` | |
| 192.168.177.121 | `__.tsa243.lab` | |
| 192.168.177.122 | `__.tsa243.lab` | |
| 192.168.177.123 | `__.tsa243.lab` | |
| 192.168.177.124 | `__.tsa243.lab` | |
| 192.168.177.125 | `__.tsa243.lab` | |
| 192.168.177.126 | `__.tsa243.lab` | |
| 192.168.177.127 | `__.tsa243.lab` | |
| 192.168.177.128 | `__.tsa243.lab` | |
| 192.168.177.129 | `__.tsa243.lab` | |

---

## Сервісна карта

```
Internet
    │
    ▼
gateway.tsa243.lab (.1)
    │
    ├── ns1.tsa243.lab (.10)      BIND9
    │       └── зона tsa243.lab
    │           ├── A-записи спільних VM
    │           └── A-записи курсантів (surname → .10X)
    │
    ├── mail.tsa243.lab (.11)     Postfix (SMTP) + Dovecot (IMAP)
    │       └── скриньки surname@tsa243.lab
    │
    ├── proxy.tsa243.lab (.12)    Nginx reverse proxy
    │       └── virtual hosts surname.tsa243.lab → VM курсанта
    │
    ├── mon.tsa243.lab (.13)      Prometheus + Grafana
    │       └── node_exporter на кожній VM → метрики
    │
    └── .101 – .129               Індивідуальні VM курсантів
            ├── Web-сервіс / API
            ├── WireGuard peer
            └── node_exporter :9100
```

---

## Детальніше

- [DNS](dns/README.md)
- [Mail](mail/README.md)
- [Nginx](nginx/README.md)
- [Monitoring](monitoring/README.md)
- [VPN](vpn/README.md)
