# ЗАЛІК — ВАРІАНТ 2
## Технології системного адміністрування | Курс 2-й | ВІТІ

> **Дата:** _________________ | **Прізвище, ім'я:** _________________________________  
> **Інструкція:** Оберіть одну правильну відповідь на кожне питання.  
> **Оцінювання:** 30 питань × 2 бали = **60 балів**

---

## БЛОК 1 — Процеси та файлові операції

**1.** Яка команда виводить топ-5 процесів за відсотком використання CPU?

- A) `ps -top 5`
- B) `ps aux --sort=-%cpu | head -6`
- C) `top --cpu 5`
- D) `htop -c 5`

---

**2.** Який сигнал надсилає команда `kill PID` за замовчуванням (без вказання номеру)?

- A) SIGKILL (9)
- B) SIGINT (2)
- C) SIGHUP (1)
- D) SIGTERM (15)

---

## БЛОК 2 — Файлова система та диски

**3.** Яка команда форматує розділ `/dev/sdb1` у файлову систему ext4?

- A) `format /dev/sdb1 ext4`
- B) `fdisk -t ext4 /dev/sdb1`
- C) `mkfs.ext4 /dev/sdb1`
- D) `tune2fs --type=ext4 /dev/sdb1`

---

**4.** Яка команда перевіряє цілісність файлової системи на розмонтованому розділі `/dev/sda1`?

- A) `tune2fs /dev/sda1`
- B) `smartctl -a /dev/sda`
- C) `fsck /dev/sda1`
- D) `blkid --check /dev/sda1`

---

## БЛОК 3 — Керування пакетами та ПЗ

**5.** Яка команда відображає детальну інформацію про пакет `nginx` (версія, опис, залежності)?

- A) `dpkg -S nginx`
- B) `dpkg -L nginx`
- C) `apt show nginx`
- D) `apt list nginx`

---

**6.** Яка правильна послідовність команд для збірки програми з вихідного коду?

- A) `make` → `./configure` → `sudo make install`
- B) `./configure` → `make` → `sudo make install`
- C) `cmake` → `make` → `sudo install`
- D) `autoconf` → `autoinstall` → `make`

---

**7.** Яка команда оновлює локальну базу даних доступних пакетів з репозиторіїв?

- A) `apt upgrade`
- B) `apt install --update`
- C) `apt update`
- D) `dpkg --refresh`

---

## БЛОК 4 — Користувачі, групи, планування, час

**8.** Яка команда створює нового користувача `student` з домашньою директорією та оболонкою `/bin/bash`?

- A) `adduser student`
- B) `useradd student`
- C) `useradd -m -s /bin/bash student`
- D) `newuser -m student`

---

**9.** Яка команда запускає одноразове завдання через 1 годину?

- A) `crontab -e "0 */1 * * * task"`
- B) `sleep 3600 && task`
- C) `at now + 1 hour`
- D) `systemctl --schedule +1h task`

---

**10.** Яка команда встановлює системний часовий пояс `Europe/Kyiv`?

- A) `export TZ=Europe/Kyiv`
- B) `localectl set-locale Europe/Kyiv`
- C) `timedatectl set-timezone Europe/Kyiv`
- D) `date --timezone Europe/Kyiv`

---

## БЛОК 5 — Bash-скрипти

**11.** Що виводить конструкція `${VAR:-default}`, якщо змінна `VAR` не встановлена або порожня?

- A) Порожній рядок
- B) Помилку "VAR not set"
- C) Рядок `default`
- D) Незмінне значення `VAR`

---

**12.** Яка умовна перевірка в bash повертає `true`, якщо `/backup` існує та є директорією?

- A) `[ -f /backup ]`
- B) `[ -e /backup ]`
- C) `[ -d /backup ]`
- D) `[ -r /backup ]`

---

## БЛОК 6 — Логування

**13.** Яка команда виводить рядки журналу рівнів `error`, `crit`, `alert`, `emerg` (тобто рівень 3 і вище за пріоритетом)?

- A) `journalctl --error`
- B) `journalctl -p err`
- C) `journalctl -l error`
- D) `journalctl --level=3`

---

**14.** Яка команда записує повідомлення `"backup complete"` у системний syslog?

- A) `syslog "backup complete"`
- B) `echo "backup complete" | syslogd`
- C) `logger "backup complete"`
- D) `journalctl --write "backup complete"`

---

## БЛОК 7 — Мережева конфігурація

**15.** Яка команда тимчасово додає IP-адресу `10.0.0.1/24` до мережевого інтерфейсу `eth0`?

- A) `ifconfig eth0 10.0.0.1/24`
- B) `netplan add 10.0.0.1/24 eth0`
- C) `ip addr add 10.0.0.1/24 dev eth0`
- D) `ip link set eth0 10.0.0.1`

---

**16.** Яка команда перехоплює та відображає ICMP-пакети на мережевому інтерфейсі `eth0`?

- A) `nmap -sn eth0`
- B) `ss --icmp eth0`
- C) `tcpdump -i eth0 icmp`
- D) `wireshark -i eth0 -f icmp`

---

**17.** Яка команда перевіряє доступність TCP-порту `443` на хості `example.com`?

- A) `ping -p 443 example.com`
- B) `nmap --port 443 example.com`
- C) `nc -zv example.com 443`
- D) `ss example.com:443`

---

## БЛОК 8 — SSH, SCP, Rsync

**18.** Яка команда копіює директорію `/data` рекурсивно на сервер із збереженням прав доступу та часових міток?

- A) `scp /data user@host:/backup/`
- B) `scp -r /data user@host:/backup/`
- C) `scp -rp /data user@host:/backup/`
- D) `rsync /data user@host:/backup/`

---

**19.** Яка опція `rsync` запускає синхронізацію в режимі симуляції (без реальних змін на диску)?

- A) `--simulate`
- B) `--test`
- C) `--dry-run`
- D) `--preview`

---

## БЛОК 9 — Протокол HTTP

**20.** До якого класу відносяться HTTP-коди відповіді `500`, `502`, `503`?

- A) `4xx` — помилка клієнта
- B) `3xx` — перенаправлення
- C) `5xx` — помилка сервера
- D) `2xx` — успішне виконання

---

**21.** Яка ключова характеристика HTTP означає, що сервер не зберігає інформацію про попередні запити клієнта?

- A) Connectionless
- B) Stateless
- C) Sessionless
- D) Cacheless

---

**22.** Який HTTP-заголовок відповіді повідомляє браузеру завжди використовувати HTTPS для даного домену?

- A) `X-Frame-Options: DENY`
- B) `X-Content-Type-Options: nosniff`
- C) `Strict-Transport-Security`
- D) `Content-Security-Policy`

---

## БЛОК 10 — Протокол TLS/SSL

**23.** Яка версія TLS була офіційно визнана застарілою та видалена з підтримки сучасними браузерами у 2021 році?

- A) TLS 1.3
- B) TLS 1.2
- C) TLS 1.1
- D) SSL 2.0

---

**24.** Яке призначення розширення SNI (Server Name Indication) у TLS?

- A) Стискання TLS-заголовків для зменшення overhead
- B) Забезпечення Perfect Forward Secrecy
- C) Дозволяє одному серверу з однією IP-адресою обслуговувати кілька HTTPS-сайтів з різними сертифікатами
- D) Перевірка статусу відкликання сертифіката (OCSP)

---

## БЛОК 11 — Балансування навантаження та проксі

**25.** Що таке Single Point of Failure (SPOF)?

- A) Алгоритм балансування навантаження між серверами
- B) Компонент, відмова якого призводить до повної недоступності сервісу
- C) Протокол виявлення відмов у кластері
- D) Метрика для вимірювання рівня навантаження

---

**26.** Який алгоритм балансування гарантує, що клієнт з певної IP-адреси завжди потрапляє на той самий backend-сервер?

- A) Round Robin
- B) Least Connections
- C) IP Hash
- D) Weighted Round Robin

---

## БЛОК 12 — HAProxy та конфігурація

**27.** Що означають параметри `fall 3 rise 2` у конфігурації `server` у HAProxy?

- A) Backend виводиться через 3 секунди і повертається через 2 секунди
- B) Backend виводиться з ротації після 3 провальних health check і повертається після 2 успішних
- C) Backend має 3 резервних сервери та 2 пріоритетних
- D) Таймаут з'єднання — 3 секунди, таймаут відповіді — 2 секунди

---

## БЛОК 13 — Системи моніторингу

**28.** Який тип метрики Prometheus найкраще описує кількість активних HTTP-з'єднань (значення, що може зростати та зменшуватись)?

- A) Counter
- B) Gauge
- C) Histogram
- D) Summary

---

**29.** Яка принципова відмінність `blackbox_exporter` від `node_exporter`?

- A) `blackbox_exporter` збирає системні метрики ОС (CPU, RAM, диск)
- B) `blackbox_exporter` перевіряє доступність ендпоінтів ззовні (HTTP, TCP, DNS, ICMP) — з точки зору користувача
- C) `blackbox_exporter` збирає метрики HAProxy-бекендів
- D) `blackbox_exporter` моніторить стан жорстких дисків (SMART)

---

**30.** Який PromQL-запит обчислює відсоток використання оперативної пам'яті для кожного хоста?

- A) `node_memory_MemTotal_bytes / node_memory_MemFree_bytes`
- B) `rate(node_memory_MemAvailable_bytes[5m])`
- C) `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100`
- D) `sum(node_memory_MemUsed_bytes) by (instance)`

---

*Технології системного адміністрування · Курс 2-й · ВІТІ · 2026*
