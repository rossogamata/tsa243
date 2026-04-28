# DNS — ієрархія та делегування

---

## Архітектура

```
Кореневий сервер викладача: ns1.tsa243.lab · 11.203.0.10
Авторитативний для: tsa243.lab

    └── делегує surname1.tsa243.lab → ns1.surname1.tsa243.lab (11.203.1.10)
    └── делегує surname2.tsa243.lab → ns1.surname2.tsa243.lab (11.203.2.10)
    └── ...

Сервер курсанта: ns1.surname.tsa243.lab · 11.203.X.10
Авторитативний для: surname.tsa243.lab
```

---

## Конфігурація на сервері викладача

### Зона `tsa243.lab` — запис делегування для кожного курсанта

```bind
; /etc/bind/db.tsa243.lab

; === Записи серверів викладача ===
@           IN  SOA   ns1.tsa243.lab. admin.tsa243.lab. (...)
@           IN  NS    ns1.tsa243.lab.
ns1         IN  A     11.203.0.10
mail        IN  A     11.203.0.11
proxy       IN  A     11.203.0.12

; === Делегування субдоменів курсантів ===
; NS-запис вказує на DNS курсанта
; Glue-запис (A) потрібен бо ns1 знаходиться всередині делегованої зони

surname1    IN  NS    ns1.surname1.tsa243.lab.
ns1.surname1 IN A    11.203.1.10

surname2    IN  NS    ns1.surname2.tsa243.lab.
ns1.surname2 IN A    11.203.2.10
```

---

## Конфігурація на сервері курсанта

### Зона `surname.tsa243.lab`

```bind
; /etc/bind/db.surname.tsa243.lab

$TTL 3600
@   IN  SOA  ns1.surname.tsa243.lab. admin.surname.tsa243.lab. (
                2024010101  ; Serial
                3600        ; Refresh
                900         ; Retry
                604800      ; Expire
                300 )       ; Negative TTL

; Name servers
@       IN  NS    ns1.surname.tsa243.lab.

; Glue і сервіси — вказують на proxy викладача як точку входу
@           IN  A     11.203.0.12   ; ← proxy викладача!
www         IN  A     11.203.0.12   ; ← proxy викладача!
ns1         IN  A     11.203.X.10
mail        IN  A     11.203.X.11
lb          IN  A     11.203.X.13
mon         IN  A     11.203.X.14

; MX
@       IN  MX    10  mail.surname.tsa243.lab.
```

**Чому A-запис `surname.tsa243.lab` вказує на proxy викладача?**
Весь зовнішній HTTP-трафік іде через центральний Nginx (11.203.0.12).
Nginx знає куди перенаправити запит по `Host:` заголовку.
Курсант керує своєю зоною DNS, але точка входу — одна на всю мережу.

---

## Перевірка делегування

```bash
# З будь-якої VM — перевірити делегування
dig surname.tsa243.lab NS @11.203.0.10

# Перевірити що курсантовий DNS відповідає
dig www.surname.tsa243.lab @11.203.X.10

# Повний ланцюг резолвінгу
dig +trace www.surname.tsa243.lab
```

---

## Навчальний момент

DNS delegation — ключовий enterprise-патерн.
Великі організації тримають кореневий DNS і делегують субзони командам/підрозділам.
Курсант бачить і впроваджує обидва боки: як викладач (делегує) і як курсант (отримує делегування).
