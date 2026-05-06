# Змістовний модуль 7. Адміністрування серверів та балансування навантаження
## ЗАНЯТТЯ 1 (Лекція) — Протоколи HTTP та TLS/SSL

> **Дисципліна:** Технології Системного Адміністрування | **Курс:** 2-й  
> **ОС:** Ubuntu Server 24.04 LTS | **Тип заняття:** Лекція  
> **Середовище:** Proxmox VE · підмережа курсанта `11.203.X.0/25`  
> **Відео:** [HTTP та HTTPS — як це працює](https://www.youtube.com/watch?v=TlDBIDlCQVM)

---

## Навчальні питання

1. [Протокол HTTP](#1-протокол-http)
   - [1.1 Загальна архітектура та еволюція](#11-загальна-архітектура-та-еволюція)
   - [1.2 Структура HTTP-повідомлення](#12-структура-http-повідомлення)
   - [1.3 Методи HTTP](#13-методи-http)
   - [1.4 Коди стану](#14-коди-стану)
   - [1.5 Заголовки HTTP](#15-заголовки-http)
   - [1.6 Стан сесії: cookies та авторизація](#16-стан-сесії-cookies-та-авторизація)
   - [1.7 HTTP/2 та HTTP/3](#17-http2-та-http3)
2. [Протоколи TLS/SSL](#2-протоколи-tlsssl)
   - [2.1 Навіщо TLS: загрози в незашифрованому HTTP](#21-навіщо-tls-загрози-в-незашифрованому-http)
   - [2.2 Еволюція: від SSL до TLS 1.3](#22-еволюція-від-ssl-до-tls-13)
   - [2.3 TLS Handshake — встановлення з'єднання](#23-tls-handshake--встановлення-зєднання)
   - [2.4 Набори шифрів (Cipher Suites)](#24-набори-шифрів-cipher-suites)
   - [2.5 Сертифікати X.509 та PKI у HTTPS](#25-сертифікати-x509-та-pki-у-https)
   - [2.6 HTTPS на практиці](#26-https-на-практиці)
   - [2.7 Сучасні вимоги до безпеки TLS](#27-сучасні-вимоги-до-безпеки-tls)

---

## 1. Протокол HTTP

### 1.1 Загальна архітектура та еволюція

**HTTP (HyperText Transfer Protocol)** — прикладний протокол передачі даних, основа WWW. Працює за моделлю **клієнт-сервер**: клієнт надсилає **запит (request)**, сервер відповідає **відповіддю (response)**.

```
Клієнт (браузер, curl, застосунок)
        │
        │  TCP з'єднання (порт 80 або 443)
        │
        ▼
  Веб-сервер (Apache, Nginx)
        │
        ├── Статичний файл → повертає одразу
        │
        └── Динамічний запит → передає PHP-FPM / Gunicorn / uWSGI → відповідь
```

**Ключові характеристики HTTP:**
- **Протокол прикладного рівня** — працює поверх TCP (або QUIC у HTTP/3)
- **Текстовий формат** (HTTP/1.x) — повідомлення можна читати у wireshark/tcpdump
- **Stateless (без стану)** — кожен запит незалежний; сервер не пам'ятає попередніх

**Еволюція версій:**

| Версія | Рік | Ключові зміни |
|--------|-----|---------------|
| **HTTP/0.9** | 1991 | Тільки GET, тільки HTML, без заголовків |
| **HTTP/1.0** | 1996 | Заголовки, методи POST/HEAD, статус-коди |
| **HTTP/1.1** | 1997 | Persistent connections, chunked transfer, Host-заголовок (обов'язковий) |
| **HTTP/2** | 2015 | Мультиплексування, стиснення заголовків, бінарний фрейм |
| **HTTP/3** | 2022 | Поверх QUIC/UDP, усунення head-of-line blocking |

---

### 1.2 Структура HTTP-повідомлення

#### Запит (Request)

```
GET / HTTP/1.1                               ← Рядок запиту (метод + URI + версія)
Host: example.com                            ┐
User-Agent: Mozilla/5.0 (X11; Linux x86_64) │
Accept: text/html,application/xhtml+xml     │ Заголовки
Accept-Language: uk,en;q=0.9               │
Connection: keep-alive                       ┘
                                             ← Порожній рядок (обов'язковий роздільник)
                                             ← Тіло запиту (у GET — відсутнє)
```

#### Відповідь (Response)

```
HTTP/1.1 200 OK                              ← Рядок статусу (версія + код + фраза)
Date: Tue, 06 May 2026 10:00:00 GMT         ┐
Server: Apache/2.4.58 (Ubuntu)              │
Content-Type: text/html; charset=UTF-8      │ Заголовки
Content-Length: 2048                        │
Last-Modified: Mon, 05 May 2026 08:30:00 GMT┘
                                             ← Порожній рядок
<!DOCTYPE html>                             ┐
<html>...                                   │ Тіло відповіді
</html>                                     ┘
```

#### Структура URL

```
https://example.com:8443/courses/linux?topic=http&page=2#section1
│       │           │    │             │                  │
│       │           │    │             │                  └─ Fragment (обробляється браузером, серверу не надсилається)
│       │           │    │             └─ Query string (?key=value&key2=value2)
│       │           │    └─ Path (/courses/linux)
│       │           └─ Port (:8443, необов'язковий — за замовчуванням 80/443)
│       └─ Host (example.com)
└─ Scheme (https://)
```

**Практика — побачити «сирий» HTTP-запит:**

```bash
# Підключитись по TCP і надіслати запит вручну
# (HTTP/1.1 вимагає заголовок Host)
printf "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n" \
    | nc example.com 80

# Те саме через curl із відображенням заголовків
curl -v http://example.com/

# Тільки заголовки відповіді (без тіла)
curl -I http://example.com/

# Детальний вивід: що надіслав curl і що отримав
curl -v --trace-ascii /dev/stdout http://example.com/ 2>&1 | head -40
```

---

### 1.3 Методи HTTP

| Метод | Призначення | Тіло запиту | Ідемпотентний | Безпечний |
|-------|-------------|-------------|---------------|-----------|
| **GET** | Отримати ресурс | Ні | Так | Так |
| **POST** | Створити ресурс / надіслати дані | Так | Ні | Ні |
| **PUT** | Замінити ресурс повністю | Так | Так | Ні |
| **PATCH** | Оновити ресурс частково | Так | Ні | Ні |
| **DELETE** | Видалити ресурс | Ні | Так | Ні |
| **HEAD** | Отримати тільки заголовки (як GET без тіла) | Ні | Так | Так |
| **OPTIONS** | Дізнатись дозволені методи | Ні | Так | Так |

> **Ідемпотентний** — повторний виклик дає той самий результат (5× DELETE = те саме що 1× DELETE).  
> **Безпечний** — не змінює стан сервера.

```bash
# GET — отримати ресурс (httpbin.org повертає деталі запиту у JSON)
curl -X GET https://httpbin.org/get?id=5

# POST — надіслати дані
curl -X POST https://httpbin.org/post \
    -H "Content-Type: application/json" \
    -d '{"name": "Іванченко", "rank": "курсант"}'

# PUT — повна заміна
curl -X PUT https://httpbin.org/put \
    -H "Content-Type: application/json" \
    -d '{"name": "Іванченко", "rank": "молодший сержант"}'

# DELETE — видалити
curl -X DELETE https://httpbin.org/delete

# HEAD — перевірити чи існує ресурс і коли змінено
curl -I https://example.com/

# OPTIONS — що дозволено
curl -X OPTIONS https://httpbin.org/ -v 2>&1 | grep "Allow:"
```

---

### 1.4 Коди стану

HTTP-відповіді мають тризначний код, згрупований за сотнями:

| Діапазон | Клас | Значення |
|----------|------|---------|
| **1xx** | Інформаційні | Запит прийнято, обробка триває |
| **2xx** | Успіх | Запит виконано успішно |
| **3xx** | Перенаправлення | Потрібні додаткові дії |
| **4xx** | Помилка клієнта | Неправильний запит |
| **5xx** | Помилка сервера | Сервер не зміг виконати запит |

**Найважливіші коди:**

```
200 OK                   — стандартна успішна відповідь
201 Created              — ресурс створено (відповідь на POST)
204 No Content           — успіх, але тіло відповіді порожнє (DELETE)
301 Moved Permanently    — постійне перенаправлення (змінити в закладках)
302 Found                — тимчасове перенаправлення
304 Not Modified         — кешована версія актуальна (умовний GET)
400 Bad Request          — неправильний синтаксис запиту
401 Unauthorized         — потрібна автентифікація
403 Forbidden            — автентифіковано, але доступ заборонено
404 Not Found            — ресурс не знайдено
405 Method Not Allowed   — метод не дозволено для цього URI
408 Request Timeout      — клієнт надто довго надсилав запит
429 Too Many Requests    — перевищено ліміт запитів (rate limiting)
500 Internal Server Error — внутрішня помилка сервера
502 Bad Gateway          — проксі отримав невалідну відповідь від бекенду
503 Service Unavailable  — сервер тимчасово недоступний (перевантаження/обслуговування)
504 Gateway Timeout      — проксі не отримав відповідь від бекенду вчасно
```

```bash
# Побачити код стану в curl
curl -o /dev/null -s -w "%{http_code}\n" https://example.com/

# Слідувати за перенаправленнями (-L)
# httpbin.org/redirect/1 робить рівно одне перенаправлення — ідеально для демонстрації
curl -L https://httpbin.org/redirect/1

# Побачити всі кроки перенаправлення
curl -v -L https://httpbin.org/redirect/1 2>&1 | grep -E "^[<>]|HTTP/"
```

---

### 1.5 Заголовки HTTP

Заголовки — це пари **ім'я: значення**, що передаються в запиті або відповіді. Регістр імені заголовка не має значення (`Content-Type` = `content-type`).

#### Заголовки запиту (клієнт → сервер)

| Заголовок | Призначення | Приклад |
|-----------|-------------|---------|
| `Host` | Ім'я хоста (обов'язковий у HTTP/1.1) | `Host: example.com` |
| `User-Agent` | Ідентифікатор клієнта | `User-Agent: Mozilla/5.0...` |
| `Accept` | MIME-типи, які клієнт розуміє | `Accept: text/html,application/json` |
| `Accept-Language` | Мовні переваги | `Accept-Language: uk,en;q=0.9` |
| `Accept-Encoding` | Алгоритми стиснення | `Accept-Encoding: gzip, deflate, br` |
| `Authorization` | Дані автентифікації | `Authorization: Bearer eyJhbG...` |
| `Content-Type` | MIME-тип тіла запиту | `Content-Type: application/json` |
| `Content-Length` | Розмір тіла в байтах | `Content-Length: 348` |
| `Cookie` | Надіслати cookies | `Cookie: session=abc123` |
| `If-None-Match` | Умовний GET (ETag) | `If-None-Match: "abc123"` |
| `If-Modified-Since` | Умовний GET (час) | `If-Modified-Since: Sat, 01 Jan 2026...` |

#### Заголовки відповіді (сервер → клієнт)

| Заголовок | Призначення | Приклад |
|-----------|-------------|---------|
| `Content-Type` | MIME-тип тіла відповіді | `Content-Type: text/html; charset=UTF-8` |
| `Content-Length` | Розмір тіла | `Content-Length: 2048` |
| `Content-Encoding` | Спосіб стиснення | `Content-Encoding: gzip` |
| `Location` | URI для перенаправлення (3xx) | `Location: https://example.com/new` |
| `Set-Cookie` | Встановити cookie | `Set-Cookie: session=abc; HttpOnly` |
| `Cache-Control` | Керування кешем | `Cache-Control: max-age=3600` |
| `ETag` | Ідентифікатор версії ресурсу | `ETag: "abc123def"` |
| `Server` | ПЗ веб-сервера | `Server: Apache/2.4.58` |
| `Strict-Transport-Security` | Вимагати HTTPS | `Strict-Transport-Security: max-age=31536000` |
| `X-Frame-Options` | Захист від clickjacking | `X-Frame-Options: DENY` |

```bash
# Переглянути всі заголовки запиту і відповіді
curl -v https://example.com/ 2>&1 | grep -E "^[<>] "

# Надіслати власний заголовок (httpbin.org повертає їх у відповіді — зручно для перевірки)
curl -H "Accept-Language: uk" \
     -H "X-Request-ID: test-001" \
     https://httpbin.org/headers

# Переглянути стиснення
curl -H "Accept-Encoding: gzip" -I https://example.com/ | grep Content-Encoding
```

---

### 1.6 Стан сесії: cookies та авторизація

HTTP — stateless. Але додаткам потрібно «пам'ятати» користувача. Механізми збереження стану:

#### Cookies

```
                    Сервер                           Клієнт
                       │
1. POST /login         │◄── username=admin&password=...
                       │
2. 200 OK              │──► Set-Cookie: session=eyJh...; Path=/; HttpOnly; Secure
                       │                                      ↑           ↑
                       │                               не доступний   тільки HTTPS
                       │                               через JS
                       │
3. GET /dashboard      │◄── Cookie: session=eyJh...
                       │
4. 200 OK              │──► <dashboard content>
```

**Атрибути cookie:**

| Атрибут | Призначення |
|---------|-------------|
| `HttpOnly` | Недоступний через JavaScript → захист від XSS |
| `Secure` | Надсилається тільки по HTTPS |
| `SameSite=Strict` | Не надсилається при cross-site запитах → захист від CSRF |
| `Max-Age=3600` | Час життя в секундах |
| `Path=/api` | Для яких шляхів діє |
| `Domain=.example.com` | Для яких субдоменів діє |

#### Схеми автентифікації

```
Basic Auth (небезпечна без HTTPS):
Authorization: Basic dXNlcjpwYXNz
                      └──────────── base64("user:pass") — НЕ шифрування!

Bearer Token (JWT, OAuth2):
Authorization: Bearer eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJ1c2VyMSJ9.signature
                      └─── Header.Payload.Signature (Base64url кожна частина)

Digest Auth (застаріла):
Authorization: Digest username="admin", realm="example.com", nonce="abc", ...
```

```bash
# Basic Auth через curl (httpbin.org/basic-auth перевіряє логін/пароль)
curl -u admin:password https://httpbin.org/basic-auth/admin/password

# Bearer Token (httpbin.org/bearer перевіряє наявність заголовка)
curl -H "Authorization: Bearer eyJhbGci..." https://httpbin.org/bearer

# Переглянути cookie які надсилає сервер
curl -c /tmp/cookies.txt -b /tmp/cookies.txt \
    https://httpbin.org/cookies/set?session=abc123

# Декодувати JWT вручну (payload = середня частина)
TOKEN="eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJ1c2VyMSIsImV4cCI6MTc0NjUzMTIwMH0.sig"
echo $TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | python3 -m json.tool
```

---

### 1.7 HTTP/2 та HTTP/3

#### Проблема HTTP/1.1: Head-of-Line Blocking

```
HTTP/1.1 — одна відповідь за раз на одному з'єднанні:

З'єднання 1:  [GET /style.css ──────────────► response]
З'єднання 2:  [GET /script.js ──────────────► response]
З'єднання 3:  [GET /logo.png  ──────────────► response]
              │← Браузер відкриває до 6 паралельних TCP-з'єднань →│
```

#### HTTP/2: мультиплексування

```
Одне TCP-з'єднання, декілька потоків (streams) одночасно:

TCP з'єднання:
  ├── Stream 1: [GET /style.css] ──► [response chunks]
  ├── Stream 3: [GET /script.js] ──► [response chunks]
  ├── Stream 5: [GET /logo.png]  ──► [response chunks]
  └── Stream 7: [GET /api/data]  ──► [response chunks]
                ↑
         Бінарні фрейми, перемежовуються у довільному порядку
```

**Переваги HTTP/2:**
- **Мультиплексування** — паралельні запити в одному TCP-з'єднанні
- **Стиснення заголовків** (HPACK) — заголовки передаються як різниця між запитами
- **Server Push** — сервер може надіслати ресурс до того, як клієнт попросить
- **Пріоритети потоків** — критичні ресурси першими

#### HTTP/3: поверх QUIC

```
HTTP/1.1 та HTTP/2:          HTTP/3:
┌─────────────┐              ┌─────────────┐
│    HTTP     │              │    HTTP/3   │
├─────────────┤              ├─────────────┤
│    TLS      │              │    QUIC     │ ← вбудований TLS 1.3
├─────────────┤              ├─────────────┤
│    TCP      │              │    UDP      │ ← без надійного потоку
└─────────────┘              └─────────────┘
```

QUIC вирішує head-of-line blocking на рівні транспорту: втрата одного UDP-пакету блокує тільки один потік, а не все з'єднання.

```bash
# Перевірити яку версію HTTP використовує сервер
# (example.com підтримує HTTP/2, більшість великих сайтів — HTTP/2 і HTTP/3)
curl -I --http2 https://example.com/
curl -I --http3 https://example.com/           # якщо підтримується

# Детальна інформація про версію протоколу
curl -v --http2 https://example.com/ 2>&1 | grep "Using HTTP"

# Або через openssl s_client + ALPN (Application-Layer Protocol Negotiation)
echo | openssl s_client -connect example.com:443 -alpn h2 2>/dev/null \
    | grep "ALPN protocol"
```

---

## 2. Протоколи TLS/SSL

### 2.1 Навіщо TLS: загрози в незашифрованому HTTP

**HTTP — відкритий текст.** Все, що передається між клієнтом і сервером, може бачити будь-хто на шляху:

```
Клієнт ──── WiFi роутер ──── ISP ──── Backbone ──── Сервер
                ↑
          Зловмисник у тій же мережі може:
          • Читати HTTP-запити і відповіді (tcpdump, Wireshark)
          • Підміняти відповіді (додавати рекламу, шкідливий JS)
          • Перехоплювати паролі, сесійні cookies
          • Атака MITM (Man-in-the-Middle)
```

**Що дає TLS:**

| Загроза | Засіб захисту TLS |
|---------|------------------|
| Перехоплення трафіку (prischluchennya) | **Шифрування** — трафік зашифрований |
| Підміна даних | **Цілісність** — MAC/AEAD виявляє зміни |
| Підміна сервера (MITM) | **Автентифікація** — сертифікат підтверджує особу сервера |
| Повторне відтворення | **Захист від replay** — session tickets, nonces |

---

### 2.2 Еволюція: від SSL до TLS 1.3

| Версія | Рік | Статус | Проблеми |
|--------|-----|--------|----------|
| **SSL 2.0** | 1995 | Заборонено (RFC 6176) | Критичні вразливості |
| **SSL 3.0** | 1996 | Заборонено (RFC 7568) | POODLE-атака (2014) |
| **TLS 1.0** | 1999 | Застаріло (2021) | BEAST, POODLE CBC |
| **TLS 1.1** | 2006 | Застаріло (2021) | Відсутні AEAD-шифри |
| **TLS 1.2** | 2008 | Підтримується | Складний, але безпечний при правильних налаштуваннях |
| **TLS 1.3** | 2018 | Рекомендовано | Швидший handshake, тільки сучасні шифри |

> Станом на 2026 рік: TLS 1.0 та 1.1 не підтримуються жодним сучасним браузером.  
> TLS 1.2 залишається широко розповсюдженим; TLS 1.3 — стандарт де-факто для нових систем.

---

### 2.3 TLS Handshake — встановлення з'єднання

**TLS 1.2 Handshake** (спрощено):

```
Клієнт                                              Сервер
   │                                                   │
   │──── ClientHello ────────────────────────────────► │
   │     (версії TLS, список cipher suites, random)    │
   │                                                   │
   │ ◄── ServerHello ──────────────────────────────── │
   │     (обрана версія TLS, обраний cipher suite,     │
   │      random, session ID)                          │
   │                                                   │
   │ ◄── Certificate ──────────────────────────────── │
   │     (сертифікат X.509 сервера, ланцюг до CA)      │
   │                                                   │
   │ ◄── ServerKeyExchange ────────────────────────── │
   │     (параметри Diffie-Hellman якщо потрібно)      │
   │                                                   │
   │ ◄── ServerHelloDone ──────────────────────────── │
   │                                                   │
   │ [Перевірка сертифіката: ланцюг довіри до Root CA] │
   │                                                   │
   │──── ClientKeyExchange ─────────────────────────► │
   │     (pre-master secret зашифрований відкр. ключем)│
   │                                                   │
   │ [Обидві сторони обчислюють master secret та       │
   │  session keys з: pre-master + client_random +     │
   │  server_random]                                   │
   │                                                   │
   │──── ChangeCipherSpec ──────────────────────────► │
   │──── Finished (HMAC всього handshake) ───────────► │
   │                                                   │
   │ ◄── ChangeCipherSpec ─────────────────────────── │
   │ ◄── Finished (HMAC всього handshake) ───────────  │
   │                                                   │
   │════ Зашифрований HTTP-трафік ═══════════════════► │
   │ ◄══ Зашифрована HTTP-відповідь ════════════════   │
```

**TLS 1.3 Handshake** — значно швидший:

```
Клієнт                                              Сервер
   │                                                   │
   │──── ClientHello ────────────────────────────────► │
   │     (TLS 1.3, key_share: публічна частина DH,     │
   │      supported_groups, підтримувані cipher suites)│
   │                                                   │
   │ ◄── ServerHello ──────────────────────────────── │
   │     (обраний group, key_share: публічна частина   │
   │      сервера — вже можна обчислити shared secret) │
   │                                                   │
   │ ◄── EncryptedExtensions ──────────────────────── │
   │ ◄── Certificate ──────────────────────────────── │ (вже зашифровано!)
   │ ◄── CertificateVerify ─────────────────────────  │
   │ ◄── Finished ─────────────────────────────────── │
   │                                                   │
   │──── Finished ──────────────────────────────────► │
   │                                                   │
   │════ Зашифрований HTTP-трафік ═══════════════════► │
```

**Ключові відмінності TLS 1.3:**
- **1-RTT** замість 2-RTT (менше затримки)
- **0-RTT** (early data) для повторних з'єднань
- Сертифікат і розширення **зашифровані** вже з першого кроку
- **Усунені слабкі алгоритми**: RSA key exchange, RC4, DES, 3DES, SHA-1

---

### 2.4 Набори шифрів (Cipher Suites)

Cipher suite — узгоджений набір алгоритмів для одного TLS-з'єднання:

```
TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
│    │     │   │    │   │   │
│    │     │   │    │   │   └── Хеш-функція MAC
│    │     │   │    │   └────── Режим шифрування (GCM = Galois/Counter Mode)
│    │     │   │    └────────── Розмір ключа (256 біт)
│    │     │   └─────────────── Симетричний шифр (AES)
│    │     └─────────────────── Алгоритм підпису сервера (RSA)
│    └───────────────────────── Алгоритм обміну ключами (ECDHE)
└────────────────────────────── Протокол (TLS)
```

**Алгоритми обміну ключами:**

| Алгоритм | PFS | Коментар |
|----------|-----|----------|
| **RSA** | Ні | Якщо privkey скомпрометовано — весь старий трафік розшифровується |
| **DHE** | Так | Diffie-Hellman Ephemeral — повільніший |
| **ECDHE** | Так | Elliptic Curve DHE — стандарт для TLS 1.2; єдиний варіант у TLS 1.3 |

**Perfect Forward Secrecy (PFS):** при ECDHE для кожного з'єднання генеруються нові тимчасові ключі. Навіть якщо приватний ключ сервера буде скомпрометовано через рік — минулий трафік залишиться зашифрованим.

**Cipher suites у TLS 1.3** (тільки 5, всі з AEAD):

```
TLS_AES_256_GCM_SHA384
TLS_CHACHA20_POLY1305_SHA256
TLS_AES_128_GCM_SHA256
TLS_AES_128_CCM_8_SHA256
TLS_AES_128_CCM_SHA256
```

```bash
# Переглянути cipher suites що підтримує сервер
nmap --script ssl-enum-ciphers -p 443 example.com

# Перевірити конкретний cipher
openssl s_client -connect example.com:443 -cipher AES256-GCM-SHA384

# Яка версія TLS та cipher suit використовується
openssl s_client -connect example.com:443 2>/dev/null \
    | grep -E "Protocol|Cipher"
```

---

### 2.5 Сертифікати X.509 та PKI у HTTPS

> Детально PKI розглянуто у занятті 6.5. Тут — у контексті HTTPS.

**Проблема:** клієнт отримав публічний ключ від сервера. Але звідки він знає, що цей ключ справді належить `example.com`, а не хакеру?

**Рішення:** Центр Сертифікації (CA) підписує сертифікат, підтверджуючи відповідність між доменним ім'ям та публічним ключем.

```
Браузер перевіряє сертифікат:

1. Чи дійсний підпис CA? ────────────► перевірка підпису сертифіката CA
2. Чи CN/SAN = запитаний домен? ────► example.com == CN=example.com? ✓
3. Чи не прострочений? ──────────────► Not Before ≤ сьогодні ≤ Not After
4. Чи не відкликаний? ───────────────► OCSP / CRL перевірка
5. Чи CA є довіреним? ───────────────► входить до системного сховища?

Якщо всі перевірки пройшли → 🔒 у браузері (HTTPS)
Якщо щось не так → ⚠️ попередження або блокування
```

**Типи сертифікатів за рівнем перевірки:**

| Тип | Скорочення | Що перевіряє CA | Термін видачі |
|-----|-----------|-----------------|---------------|
| Domain Validation | **DV** | Тільки контроль над доменом | Хвилини (автоматично) |
| Organization Validation | **OV** | Домен + існування організації | Кілька днів |
| Extended Validation | **EV** | Домен + юридична перевірка орг. | Тижні |

> Let's Encrypt видає безкоштовні DV-сертифікати автоматично (90 днів, auto-renewal).

**Subject Alternative Names (SAN):**

```bash
# Переглянути для яких доменів виданий сертифікат (SAN)
openssl s_client -connect example.com:443 2>/dev/null \
    | openssl x509 -noout -text \
    | grep -A1 "Subject Alternative Name"

# Термін дії сертифіката
openssl s_client -connect example.com:443 2>/dev/null \
    | openssl x509 -noout -dates

# Хто видав (Issuer) та кому (Subject)
openssl s_client -connect example.com:443 2>/dev/null \
    | openssl x509 -noout -issuer -subject

# Повний ланцюг сертифікатів
openssl s_client -connect example.com:443 -showcerts 2>/dev/null \
    | grep -E "^(subject|issuer)"
```

---

### 2.6 HTTPS на практиці

**HTTPS = HTTP + TLS.** Стандартний порт — **443**.

```
Клієнт                                   Сервер (:443)
   │                                         │
   │──── TCP SYN ────────────────────────► │
   │ ◄── TCP SYN-ACK ─────────────────── │
   │──── TCP ACK ────────────────────────► │
   │                                         │
   │        [TLS Handshake]                  │
   │                                         │
   │══════════════════════════════════════► │
   │ GET / HTTP/1.1 (зашифровано)            │
   │ ◄════════════════════════════════════  │
   │ HTTP/1.1 200 OK (зашифровано)           │
```

**SNI — Server Name Indication:**

Одна IP-адреса може обслуговувати кілька HTTPS-сайтів (як vhosts для HTTP/1.1). Клієнт надсилає ім'я хоста у ClientHello (ще до шифрування), щоб сервер знав який сертифікат підключити.

```
ClientHello:
  ...
  extension: server_name
    server_name: example.com    ← сервер бачить ще до TLS-шифрування
  ...
```

```bash
# Переглянути SNI та весь TLS handshake
openssl s_client -connect example.com:443 -servername example.com

# Перевірити HTTPS-сайт з ігноруванням помилок сертифіката
# badssl.com — спеціальний тестовий сайт з субдоменами для кожного TLS-сценарію
curl -k https://self-signed.badssl.com/        # self-signed сертифікат
curl -k https://expired.badssl.com/            # прострочений сертифікат
curl -k https://wrong.host.badssl.com/         # невідповідність домену

# Вказати власний CA для перевірки
curl --cacert ca.crt https://example.com/

# Примусово TLS 1.2 або 1.3
curl --tlsv1.2 https://example.com/
curl --tlsv1.3 https://example.com/

# Детальна інформація про TLS з'єднання
curl -v https://example.com/ 2>&1 | grep -E "SSL|TLS|cipher|certificate"
```

**HTTP → HTTPS перенаправлення (Apache):**

```apacheconf
<VirtualHost *:80>
    ServerName surname.tsa243.lab
    Redirect permanent / https://surname.tsa243.lab/
    # Або більш правильно:
    # RewriteEngine On
    # RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
</VirtualHost>

<VirtualHost *:443>
    ServerName surname.tsa243.lab

    SSLEngine on
    SSLCertificateFile    /etc/ssl/certs/surname.crt
    SSLCertificateKeyFile /etc/ssl/private/surname.key
    # Якщо є проміжні сертифікати:
    # SSLCertificateChainFile /etc/ssl/certs/chain.crt

    DocumentRoot /var/www/html
</VirtualHost>
```

**HSTS (HTTP Strict Transport Security):**

```apacheconf
# Після увімкнення HTTPS — додати заголовок HSTS
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
```

Браузер запам'ятає: цей сайт — тільки HTTPS, навіть якщо користувач введе `http://`. Захист від SSL-stripping атак.

---

### 2.7 Сучасні вимоги до безпеки TLS

**Мінімальна конфігурація Apache для безпечного HTTPS (2026):**

```apacheconf
<VirtualHost *:443>
    ServerName surname.tsa243.lab

    SSLEngine on
    SSLCertificateFile    /etc/ssl/certs/surname.crt
    SSLCertificateKeyFile /etc/ssl/private/surname.key

    # Тільки TLS 1.2 та 1.3 (1.0 і 1.1 — застаріли)
    SSLProtocol -all +TLSv1.2 +TLSv1.3

    # Тільки strong cipher suites з PFS
    SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:\
ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:\
ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305

    # Перевага шифрів сервера (для TLS 1.2)
    SSLHonorCipherOrder off   # для TLS 1.3 порядок не важливий

    # Заголовки безпеки
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set X-Frame-Options DENY
    Header always set X-Content-Type-Options nosniff
</VirtualHost>
```

**Перевірка конфігурації:**

```bash
# Перевірити версію TLS і cipher suite на прикладі реального сайту
openssl s_client -connect example.com:443 -tls1_2 2>/dev/null | grep Cipher
openssl s_client -connect example.com:443 -tls1_3 2>/dev/null | grep Cipher

# Переконатись що TLS 1.0 відхиляється (більшість сучасних серверів відхиляють)
openssl s_client -connect example.com:443 -tls1 2>&1 | grep -E "error|alert"

# Оцінка конфігурації TLS свого сервера
nmap --script ssl-enum-ciphers -p 443 11.203.X.20 | grep -E "TLSv|cipher|strength"
# Для будь-якого публічного сайту: https://www.ssllabs.com/ssltest/

# Перевірити HSTS на прикладі сайту що його використовує
curl -sI https://example.com/ | grep Strict

# Переглянути весь сертифікат
openssl s_client -connect example.com:443 2>/dev/null | openssl x509 -text -noout
```

**Швидкий тест HTTPS через openssl:**

```bash
# Підключитись як TLS-клієнт і надіслати HTTP-запит
openssl s_client -connect example.com:443 -quiet << 'EOF'
GET / HTTP/1.1
Host: example.com
Connection: close

EOF
```

---

## Зв'язок між заняттями

```
Заняття 6.5 (PKI)                     Заняття 7.1 (HTTP+TLS)
─────────────────────────────────────────────────────────────
Генерація RSA/ECDSA ключів         →  Ключі сервера у TLS Handshake

Самопідписаний сертифікат (CA)     →  SSLCertificateFile в Apache

CSR → підпис CA → сертифікат       →  Ланцюг довіри для HTTPS

openssl s_client                   →  Діагностика TLS-з'єднань

SHA-256, ECDHE, AES-GCM            →  Cipher Suite у TLS 1.3

                                      │
                                      ▼
                               Заняття 7.4 (Apache vhosts)
                               + наступне заняття: HTTPS vhost
```

---

## Корисні команди

```bash
# ═══════════════════════════════════════════════════════════
# HTTP — дослідження та діагностика
# ═══════════════════════════════════════════════════════════
curl -v https://example.com/           # детальний вивід (заголовки + тіло)
curl -I https://example.com/           # тільки заголовки відповіді
curl -L https://httpbin.org/redirect/1 # слідувати за редиректами
curl -o /dev/null -s -w "%{http_code}" https://example.com/  # тільки код стану
curl -H "Host: dev.surname.tsa243.lab" http://11.203.X.20/   # vhost курсанта
curl -X POST -d '{"key":"val"}' -H "Content-Type: application/json" https://httpbin.org/post

# Тест HTTP вручну через netcat
printf "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n" \
    | nc example.com 80

# ═══════════════════════════════════════════════════════════
# TLS — дослідження та діагностика
# ═══════════════════════════════════════════════════════════
openssl s_client -connect example.com:443         # TLS handshake + сертифікат
openssl s_client -connect example.com:443 -tls1_3 # Тільки TLS 1.3
openssl s_client -connect example.com:443 -showcerts # Весь ланцюг
openssl s_client -connect example.com:443 2>/dev/null | openssl x509 -text -noout

# Перевірити терміни дії
openssl s_client -connect example.com:443 2>/dev/null \
    | openssl x509 -noout -dates

# Переглянути всі SAN (домени у сертифікаті)
openssl s_client -connect example.com:443 2>/dev/null \
    | openssl x509 -noout -text | grep -A1 "Subject Alternative"

# HTTP-запит через TLS (ручний режим)
openssl s_client -connect example.com:443 -quiet << 'EOF'
GET / HTTP/1.1
Host: example.com
Connection: close

EOF

# ═══════════════════════════════════════════════════════════
# Apache — керування HTTPS
# ═══════════════════════════════════════════════════════════
sudo a2enmod ssl                                 # увімкнути SSL модуль
sudo a2enmod headers                             # увімкнути модуль заголовків
sudo a2enmod rewrite                             # для HTTP→HTTPS редиректу
sudo apache2ctl configtest                       # перевірити конфіги
sudo systemctl reload apache2

# Перевірити які порти слухаються
ss -tlnp | grep -E "80|443"

# Логи помилок TLS
sudo tail -f /var/log/apache2/error.log | grep -i ssl
```

---

## Питання для самоконтролю

1. У чому різниця між HTTP/1.1 та HTTP/2 з точки зору мережевої ефективності?
2. Що означає, що HTTP — stateless? Як це обходиться в реальних застосунках?
3. Чому Basic Auth без HTTPS є критичною вразливістю?
4. Які атрибути cookie є обов'язковими для сесійних токенів з точки зору безпеки?
5. Що відбувається під час TLS Handshake? Які дані передаються у відкритому вигляді?
6. Що таке Perfect Forward Secrecy і чому RSA key exchange не забезпечує PFS?
7. Чим TLS 1.3 краще за TLS 1.2? Назвіть 3 відмінності.
8. Навіщо потрібен SNI? Яка проблема вирішується?
9. Як браузер перевіряє автентичність HTTPS-сайту? Перерахуйте кроки.
10. Що таке HSTS і від якої атаки він захищає?

---

## Завдання на самопідготовку

1. Підключитись по SSH до свого сервера (`11.203.X.20`) і встановити пакет `openssl` та `curl`.

2. Дослідити HTTP-трафік до свого Apache vhost з заняття 7.4:
   ```bash
   curl -v http://surname.tsa243.lab/
   ```
   Записати: код стану, 5 ключових заголовків відповіді, версію Apache.

3. Дослідити сертифікат публічного сервера:
   ```bash
   openssl s_client -connect example.com:443 2>/dev/null | openssl x509 -text -noout
   ```
   Виписати: кому виданий, ким виданий, термін дії, алгоритм підпису.

   Потім порівняти з проблемними сертифікатами на `badssl.com`:
   ```bash
   # Прострочений сертифікат
   openssl s_client -connect expired.badssl.com:443 2>/dev/null | openssl x509 -noout -dates
   # Самопідписаний
   openssl s_client -connect self-signed.badssl.com:443 2>/dev/null | openssl x509 -noout -issuer -subject
   ```

4. Увімкнути SSL-модуль у своєму Apache та налаштувати HTTPS для `surname.tsa243.lab`
   з власним self-signed сертифікатом (використовуючи знання з заняття 6.5).

5. Перевірити конфігурацію TLS свого сервера командою:
   ```bash
   nmap --script ssl-enum-ciphers -p 443 11.203.X.20
   ```
   Переконатись, що TLS 1.0/1.1 відсутні у підтримуваних версіях.

---

*Змістовний модуль 7 · Заняття 1 (Лекція) · Технології системного адміністрування · ВІТІ*
