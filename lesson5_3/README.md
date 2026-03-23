# Змістовий модуль 5. Системне адміністрування
## ЗАНЯТТЯ 3 (Групове) — Скрипти, BASH-скрипти та системи логування

> **Дисципліна:** Технології Системного Адміністрування | **Курс:** 2-й
> **ОС:** Ubuntu Server 24.04 LTS / WSL2 | **Тип заняття:** Групове

---

## Навчальні питання

1. [Скрипти, BASH-скрипти](#1-скрипти-bash-скрипти)
2. [Системи логування](#2-системи-логування)

---

## 1. Скрипти, BASH-скрипти

### 1.1 Що таке shell-скрипт

**Shell-скрипт** — текстовий файл із послідовністю команд, що виконуються інтерпретатором командного рядка. Дозволяє автоматизувати повторювані дії адміністратора.

**Переваги скриптів:**
- Автоматизація рутинних завдань (резервне копіювання, очищення логів, моніторинг)
- Відтворюваність: скрипт виконує однакові кроки щоразу без помилок оператора
- Документування: скрипт є одночасно інструкцією та виконуваним кодом

### 1.2 Перший скрипт. Shebang

Перший рядок скрипту — **shebang** (`#!`) — вказує шлях до інтерпретатора:

```bash
#!/bin/bash
# Коментар: це перший скрипт

echo "Привіт, адміністраторе!"
echo "Поточний час: $(date '+%H:%M:%S')"
echo "Хост: $(hostname)"
```

#### Створення та запуск

```bash
# Створити файл
nano hello.sh

# Надати право на виконання
chmod +x hello.sh

# Запустити
./hello.sh

# Або явно через bash (без chmod)
bash hello.sh
```

#### Де зберігати скрипти

| Місце | Призначення |
|---|---|
| `~/bin/` або `~/.local/bin/` | Особисті скрипти користувача |
| `/usr/local/bin/` | Системні скрипти для всіх |
| `/opt/scripts/` | Корпоративні/проєктні скрипти |
| `/etc/cron.daily/` | Скрипти для планувальника |

---

### 1.3 Змінні

#### Оголошення та використання

```bash
#!/bin/bash

# Оголошення змінної (без пробілів навколо =)
NAME="Олексій"
AGE=25
PI=3.14

# Використання: $VAR або ${VAR}
echo "Ім'я: $NAME"
echo "Вік: ${AGE} років"

# Конкатенація
GREETING="Привіт, ${NAME}!"
echo "$GREETING"

# Результат команди у змінну
CURRENT_DATE=$(date '+%Y-%m-%d')
FREE_DISK=$(df -h / | awk 'NR==2 {print $4}')
echo "Дата: $CURRENT_DATE"
echo "Вільне місце на /: $FREE_DISK"
```

#### Типи змінних

```bash
# Локальна (тільки у поточній функції)
local MY_VAR="значення"

# Змінна середовища (передається дочірнім процесам)
export PATH="$PATH:/opt/myapp/bin"
export MY_APP_HOME="/opt/myapp"

# Тільки для читання (константа)
readonly MAX_RETRIES=5
readonly CONFIG_FILE="/etc/myapp/config"

# Масив
SERVERS=("web01" "web02" "db01" "db02")
echo "${SERVERS[0]}"      # web01
echo "${SERVERS[@]}"      # всі елементи
echo "${#SERVERS[@]}"     # кількість елементів (4)
```

#### Спеціальні змінні

| Змінна | Значення |
|---|---|
| `$0` | Ім'я скрипту |
| `$1`, `$2`, ... | Позиційні аргументи |
| `$#` | Кількість аргументів |
| `$@` | Всі аргументи (список) |
| `$*` | Всі аргументи (рядок) |
| `$?` | Код повернення останньої команди (0 = успіх) |
| `$$` | PID поточного процесу |
| `$!` | PID останнього фонового процесу |
| `$_` | Останній аргумент попередньої команди |

```bash
#!/bin/bash
# Демонстрація спеціальних змінних
echo "Скрипт: $0"
echo "Перший аргумент: $1"
echo "Всього аргументів: $#"
echo "PID скрипту: $$"

ls /tmp
echo "Код повернення ls: $?"   # 0

ls /nonexistent 2>/dev/null
echo "Код повернення: $?"      # 2
```

---

### 1.4 Введення/виведення. Перенаправлення

```bash
# Зчитати рядок від користувача
echo -n "Введіть ваше ім'я: "
read USER_NAME
echo "Привіт, $USER_NAME"

# read із підказкою (-p) та лімітом часу (-t)
read -p "Ваш вибір [y/n]: " -t 10 CHOICE
read -s -p "Пароль: " SECRET    # -s = беззвучно (не відображати)

# Перенаправлення виведення
echo "Лог-запис" >> /var/log/myapp.log   # дописати
echo "Новий файл" > /tmp/output.txt      # перезаписати

# Перенаправлення помилок
command 2>/dev/null            # ігнорувати stderr
command 2>error.log            # stderr у файл
command >out.log 2>&1          # stdout і stderr у один файл
command &>/tmp/all.log         # скорочений запис (bash)

# /dev/null — "чорна діра"
cat /etc/shadow 2>/dev/null || echo "Немає доступу"
```

---

### 1.5 Умовні конструкції

#### `if / elif / else`

```bash
#!/bin/bash
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

if [ "$DISK_USAGE" -ge 90 ]; then
    echo "КРИТИЧНО: диск заповнений на ${DISK_USAGE}%"
elif [ "$DISK_USAGE" -ge 70 ]; then
    echo "ПОПЕРЕДЖЕННЯ: диск заповнений на ${DISK_USAGE}%"
else
    echo "OK: диск заповнений на ${DISK_USAGE}%"
fi
```

#### Оператори порівняння

**Числа:**

| Оператор | Значення |
|---|---|
| `-eq` | рівно (equal) |
| `-ne` | не рівно (not equal) |
| `-lt` | менше (less than) |
| `-le` | менше або рівно |
| `-gt` | більше (greater than) |
| `-ge` | більше або рівно |

**Рядки:**

| Оператор | Значення |
|---|---|
| `=` або `==` | рівні |
| `!=` | не рівні |
| `-z` | порожній рядок |
| `-n` | непорожній рядок |

**Файли:**

| Оператор | Значення |
|---|---|
| `-f` | існує і є файлом |
| `-d` | існує і є каталогом |
| `-e` | існує (будь-який тип) |
| `-r` | доступний для читання |
| `-w` | доступний для запису |
| `-x` | виконуваний |
| `-s` | розмір > 0 |

```bash
#!/bin/bash
CONFIG="/etc/myapp.conf"

if [ ! -f "$CONFIG" ]; then
    echo "Файл конфігурації не знайдено: $CONFIG"
    exit 1
fi

if [ -r "$CONFIG" ]; then
    echo "Конфігурація доступна для читання"
fi

# Подвійні дужки [[ ]] — розширений синтаксис bash
# підтримує &&, ||, =~, без лапок навколо змінних
SERVICE="nginx"
if [[ "$SERVICE" == "nginx" || "$SERVICE" == "apache2" ]]; then
    echo "Веб-сервер: $SERVICE"
fi

# Перевірка регулярним виразом
IP="192.168.1.100"
if [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Коректний IP: $IP"
fi
```

#### `case`

```bash
#!/bin/bash
read -p "Введіть команду [start|stop|restart|status]: " CMD

case "$CMD" in
    start)
        echo "Запуск сервісу..."
        systemctl start nginx
        ;;
    stop)
        echo "Зупинка сервісу..."
        systemctl stop nginx
        ;;
    restart)
        echo "Перезапуск сервісу..."
        systemctl restart nginx
        ;;
    status)
        systemctl status nginx
        ;;
    *)
        echo "Невідома команда: $CMD"
        echo "Використання: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
```

---

### 1.6 Цикли

#### `for`

```bash
#!/bin/bash

# Ітерація по списку
for SERVER in web01 web02 db01 db02; do
    echo "Перевірка $SERVER..."
    ping -c 1 -W 1 "$SERVER" &>/dev/null && echo "$SERVER: OK" || echo "$SERVER: НЕДОСТУПНИЙ"
done

# Ітерація по масиву
LOGS=("/var/log/syslog" "/var/log/auth.log" "/var/log/kern.log")
for LOG in "${LOGS[@]}"; do
    if [ -f "$LOG" ]; then
        SIZE=$(du -sh "$LOG" | cut -f1)
        echo "$LOG: $SIZE"
    fi
done

# Числовий діапазон
for i in {1..5}; do
    echo "Спроба $i..."
done

# C-подібний синтаксис
for ((i=0; i<10; i++)); do
    echo "i = $i"
done

# Ітерація по файлах
for FILE in /etc/*.conf; do
    echo "Знайдено конфіг: $(basename $FILE)"
done
```

#### `while` та `until`

```bash
#!/bin/bash

# while — виконувати ПОКИ умова істинна
COUNT=0
while [ "$COUNT" -lt 5 ]; do
    echo "Лічильник: $COUNT"
    ((COUNT++))
done

# Читання файлу рядок за рядком
while IFS= read -r LINE; do
    echo "Рядок: $LINE"
done < /etc/hosts

# until — виконувати ПОКИ умова хибна (протилежність while)
ATTEMPTS=0
until ping -c 1 -W 1 8.8.8.8 &>/dev/null; do
    echo "Мережа недоступна. Спроба $((++ATTEMPTS))..."
    sleep 5
    if [ "$ATTEMPTS" -ge 10 ]; then
        echo "Перевищено ліміт спроб"
        exit 1
    fi
done
echo "Мережа доступна після $ATTEMPTS спроб"

# break та continue
for i in {1..10}; do
    [ "$i" -eq 5 ] && continue    # пропустити 5
    [ "$i" -eq 8 ] && break       # зупинити на 8
    echo "$i"
done
```

---

### 1.7 Функції

```bash
#!/bin/bash

# Оголошення функції
log_message() {
    local LEVEL="$1"    # INFO, WARN, ERROR
    local MSG="$2"
    local TIMESTAMP
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] [$LEVEL] $MSG"
}

check_service() {
    local SERVICE="$1"
    if systemctl is-active --quiet "$SERVICE"; then
        log_message "INFO" "Сервіс $SERVICE запущено"
        return 0
    else
        log_message "ERROR" "Сервіс $SERVICE не запущено"
        return 1
    fi
}

# Виклик функцій
log_message "INFO" "Скрипт запущено"
check_service "cron" && log_message "INFO" "Cron працює"

# Функція з поверненням значення через echo
get_uptime_days() {
    awk '{print int($1/86400)}' /proc/uptime
}

DAYS=$(get_uptime_days)
echo "Система працює вже $DAYS днів"
```

---

### 1.8 Обробка аргументів командного рядка

```bash
#!/bin/bash
# backup.sh — скрипт резервного копіювання

# Перевірка аргументів
if [ "$#" -lt 2 ]; then
    echo "Використання: $0 <джерело> <призначення> [--compress]"
    echo "  Приклад: $0 /var/www /backup/www --compress"
    exit 1
fi

SOURCE="$1"
DEST="$2"
COMPRESS="${3:-}"   # третій аргумент або порожній рядок

# Перевірка джерела
if [ ! -d "$SOURCE" ]; then
    echo "Помилка: директорія '$SOURCE' не існує"
    exit 1
fi

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_NAME="backup_$(basename $SOURCE)_${TIMESTAMP}"

if [ "$COMPRESS" = "--compress" ]; then
    tar -czf "${DEST}/${BACKUP_NAME}.tar.gz" "$SOURCE"
    echo "Стиснений архів: ${DEST}/${BACKUP_NAME}.tar.gz"
else
    cp -r "$SOURCE" "${DEST}/${BACKUP_NAME}"
    echo "Копія: ${DEST}/${BACKUP_NAME}"
fi
```

#### `getopts` — обробка ключів

```bash
#!/bin/bash
# Підтримка прапорів: -v (verbose), -o (output file), -h (help)

VERBOSE=0
OUTPUT_FILE=""

while getopts "vo:h" OPT; do
    case "$OPT" in
        v) VERBOSE=1 ;;
        o) OUTPUT_FILE="$OPTARG" ;;
        h)
            echo "Використання: $0 [-v] [-o <файл>]"
            exit 0
            ;;
        ?)
            echo "Невідомий ключ: -$OPTARG"
            exit 1
            ;;
    esac
done

[ "$VERBOSE" -eq 1 ] && echo "Режим деталізації увімкнено"
[ -n "$OUTPUT_FILE" ] && echo "Вихід у файл: $OUTPUT_FILE"
```

---

### 1.9 Арифметика та рядкові операції

```bash
#!/bin/bash

# Арифметика: (( )) або $(( ))
A=10
B=3
echo $((A + B))    # 13
echo $((A * B))    # 30
echo $((A / B))    # 3 (ціла частина)
echo $((A % B))    # 1 (остача)
echo $((A ** B))   # 1000

((A++))            # інкремент
((A += 5))         # += -= *= /=

# Рядкові операції
STR="Hello, World!"
echo "${#STR}"                  # довжина: 13
echo "${STR:7}"                 # зрізати: World!
echo "${STR:7:5}"               # підрядок: World
echo "${STR/World/Linux}"       # заміна першого: Hello, Linux!
echo "${STR//l/L}"              # заміна всіх: HeLLo, WorLd!
echo "${STR,,}"                 # до нижнього регістру
echo "${STR^^}"                 # до верхнього регістру

FILEPATH="/var/log/syslog"
echo "${FILEPATH##*/}"          # тільки ім'я файлу: syslog
echo "${FILEPATH%/*}"           # тільки директорія: /var/log
echo "${FILEPATH##*.}"          # розширення: syslog (без крапки)

# Значення за замовчуванням
NAME="${1:-адміністратор}"      # якщо $1 порожній — "адміністратор"
DIR="${OUTPUT_DIR:-/tmp}"       # якщо змінна не задана
```

---

### 1.10 Практичний приклад: скрипт моніторингу

```bash
#!/bin/bash
# system_check.sh — перевірка стану системи

# ─── Конфігурація ───────────────────────────────────────────
DISK_WARN=70
DISK_CRIT=90
MEM_WARN=80
LOG_FILE="/var/log/system_check.log"

# ─── Функції ────────────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

check_disk() {
    local USAGE
    USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
    if [ "$USAGE" -ge "$DISK_CRIT" ]; then
        log "CRIT | Диск: ${USAGE}% (поріг: ${DISK_CRIT}%)"
        return 2
    elif [ "$USAGE" -ge "$DISK_WARN" ]; then
        log "WARN | Диск: ${USAGE}% (поріг: ${DISK_WARN}%)"
        return 1
    else
        log "OK   | Диск: ${USAGE}%"
        return 0
    fi
}

check_memory() {
    local USAGE
    USAGE=$(free | awk '/^Mem:/ {printf "%d", $3/$2*100}')
    if [ "$USAGE" -ge "$MEM_WARN" ]; then
        log "WARN | Пам'ять: ${USAGE}%"
    else
        log "OK   | Пам'ять: ${USAGE}%"
    fi
}

check_service() {
    local SVC="$1"
    if systemctl is-active --quiet "$SVC"; then
        log "OK   | Сервіс $SVC: активний"
    else
        log "CRIT | Сервіс $SVC: ЗУПИНЕНО"
    fi
}

# ─── Головна логіка ─────────────────────────────────────────
log "=== Початок перевірки системи ==="
check_disk
check_memory
for SVC in cron ssh; do
    check_service "$SVC"
done
log "=== Перевірка завершена ==="
```

---

## 2. Системи логування

### 2.1 Архітектура логування в Linux

Логування в Linux побудовано на кількох рівнях:

```
Програма/Скрипт
      │
      ▼
  syslog API  ──────────────────────────────────────────────────
      │                                                         │
      ▼                                                         │
  rsyslog / syslog-ng           systemd-journald               │
  (класичний демон)             (бінарний журнал)              │
      │                               │                         │
      ▼                               ▼                         │
 /var/log/*.log              journalctl                         │
                                                                │
  /dev/log (Unix socket) ─────────────────────────────────────┘
```

**Два основних підходи:**

| | rsyslog | systemd-journald |
|---|---|---|
| Формат | Текстовий (людиночитаний) | Бінарний (індексований) |
| Файли | `/var/log/syslog`, `/var/log/auth.log` та ін. | `/run/log/journal/` або `/var/log/journal/` |
| Інструмент | `grep`, `tail`, `less` | `journalctl` |
| Ротація | `logrotate` | автоматична (за розміром/часом) |
| Постійність | з коробки | потрібен `/var/log/journal/` |

На Ubuntu 24.04 обидва системи працюють **одночасно**: journald збирає всі логи, rsyslog також отримує копію через `/run/systemd/journal/syslog`.

---

### 2.2 Стандартні файли логів

```bash
# Основні файли у /var/log/
ls -lh /var/log/

# Найважливіші:
/var/log/syslog          # загальний системний журнал
/var/log/auth.log        # авторизація, sudo, ssh
/var/log/kern.log        # повідомлення ядра
/var/log/dpkg.log        # дії з пакетами apt/dpkg
/var/log/apt/history.log # історія apt
/var/log/ufw.log         # брандмауер UFW
/var/log/nginx/          # логи nginx (access.log, error.log)
/var/log/postgresql/     # логи PostgreSQL
/var/log/journal/        # systemd journal (бінарний)

# Спеціальні файли (бінарні):
/var/log/wtmp            # журнал входів (last)
/var/log/btmp            # невдалі входи (lastb)
/var/log/lastlog         # останній вхід кожного юзера
```

#### Перегляд логів у реальному часі

```bash
# tail -f — стежити за оновленнями
tail -f /var/log/syslog
tail -f /var/log/auth.log

# Декілька файлів одночасно
tail -f /var/log/syslog /var/log/auth.log

# Останні 50 рядків
tail -n 50 /var/log/syslog

# Фільтрація під час перегляду
tail -f /var/log/syslog | grep -i "error\|fail\|crit"
```

---

### 2.3 Рівні та об'єкти syslog

#### Рівні серйозності (severity)

| Число | Назва | Опис |
|---|---|---|
| 0 | `emerg` | Система непрацездатна (паніка) |
| 1 | `alert` | Потрібна негайна дія |
| 2 | `crit` | Критичний стан |
| 3 | `err` | Помилки |
| 4 | `warning` | Попередження |
| 5 | `notice` | Нормальна, але важлива подія |
| 6 | `info` | Інформаційне повідомлення |
| 7 | `debug` | Налагоджувальна інформація |

#### Об'єкти (facility)

| Об'єкт | Призначення |
|---|---|
| `kern` | Ядро ОС |
| `auth` / `authpriv` | Авторизація, sudo, PAM |
| `cron` | Планувальник cron |
| `daemon` | Системні демони |
| `user` | Програми користувача |
| `local0`–`local7` | Для власних програм |

---

### 2.4 `journalctl` — основний інструмент перегляду

```bash
# ═══ БАЗОВИЙ ПЕРЕГЛЯД ══════════════════════════════════════

# Весь журнал (від найстарішого)
journalctl

# Від кінця (-e = --pager-end)
journalctl -e

# У реальному часі (аналог tail -f)
journalctl -f

# Останні N рядків
journalctl -n 50

# ═══ ФІЛЬТРАЦІЯ ═══════════════════════════════════════════

# Конкретний сервіс
journalctl -u nginx
journalctl -u nginx -u postgresql    # кілька сервісів

# За пріоритетом (і вище)
journalctl -p err          # тільки err, crit, alert, emerg
journalctl -p warning      # warning і вище

# За часом
journalctl --since "2024-03-13 08:00:00"
journalctl --since "1 hour ago"
journalctl --since "today"
journalctl --since yesterday --until today
journalctl --since "2024-03-13" --until "2024-03-14"

# За ідентифікатором процесу
journalctl _PID=1234

# Від ядра (аналог dmesg)
journalctl -k
journalctl -k --since "1 hour ago"

# ═══ ФОРМАТ ВИВЕДЕННЯ ══════════════════════════════════════

# Короткий (за замовчуванням)
journalctl -u ssh -n 20

# JSON (для обробки скриптами)
journalctl -u ssh -n 5 -o json-pretty

# Без кольорів і пейджера (для скриптів)
journalctl -u ssh --no-pager

# ═══ ІНФОРМАЦІЯ ПРО ЖУРНАЛ ════════════════════════════════

# Розмір журналу
journalctl --disk-usage

# Список завантажень
journalctl --list-boots

# Логи попереднього завантаження
journalctl -b -1

# Очистити старі записи
sudo journalctl --vacuum-time=30d   # старіші 30 днів
sudo journalctl --vacuum-size=500M  # залишити тільки 500 МБ
```

---

### 2.5 `rsyslog` — класичний демон логування

```bash
# Перевірити статус
systemctl status rsyslog

# Конфігурація
cat /etc/rsyslog.conf
ls /etc/rsyslog.d/
```

#### Основи конфігурації `/etc/rsyslog.conf`

```
# Формат правила:
# <facility>.<severity>    <дія>

# Усі повідомлення auth — у auth.log
auth,authpriv.*             /var/log/auth.log

# Усі рівні крім debug у syslog
*.*;auth,authpriv.none      /var/log/syslog

# Тільки критичні помилки ядра
kern.crit                   /var/log/kern.log

# Передати на віддалений сервер (UDP)
*.err                       @192.168.1.10:514

# Передати на віддалений сервер (TCP — надійніше)
*.err                       @@192.168.1.10:514
```

#### Власний файл у `/etc/rsyslog.d/`

```bash
# Створити конфіг для власної програми
sudo nano /etc/rsyslog.d/50-myapp.conf
```

```
# /etc/rsyslog.d/50-myapp.conf
# Логи від facility local0 — у окремий файл
local0.*    /var/log/myapp.log

# Зупинити обробку (не дублювати у syslog)
local0.*    stop
```

```bash
# Перезапустити rsyslog
sudo systemctl restart rsyslog
```

---

### 2.6 `logger` — запис у syslog зі скриптів

```bash
# Базовий запис
logger "Резервна копія завершена успішно"

# Вказати тег та об'єкт
logger -t myapp -p local0.info "Сервіс запущено"
logger -t myapp -p local0.warning "Мало вільного місця"
logger -t myapp -p local0.err "З'єднання з БД втрачено"

# Перевірити у журналі
journalctl -t myapp -n 10
grep "myapp" /var/log/syslog
```

#### Інтеграція у скрипт

```bash
#!/bin/bash
# backup_with_logging.sh

APP="backup"
LOG_FILE="/var/log/backup.log"

log_info()  { logger -t "$APP" -p local0.info "$*";    echo "$(date) INFO  $*" >> "$LOG_FILE"; }
log_warn()  { logger -t "$APP" -p local0.warning "$*"; echo "$(date) WARN  $*" >> "$LOG_FILE"; }
log_error() { logger -t "$APP" -p local0.err "$*";     echo "$(date) ERROR $*" >> "$LOG_FILE"; }

SOURCE="/var/www"
DEST="/backup"

log_info "Початок резервного копіювання: $SOURCE -> $DEST"

if [ ! -d "$SOURCE" ]; then
    log_error "Джерело не існує: $SOURCE"
    exit 1
fi

tar -czf "${DEST}/www_$(date +%Y%m%d).tar.gz" "$SOURCE" 2>/dev/null
if [ $? -eq 0 ]; then
    log_info "Резервна копія створена успішно"
else
    log_error "Помилка при створенні архіву (код: $?)"
    exit 1
fi
```

---

### 2.7 Аналіз логів

```bash
# ═══ ФІЛЬТРАЦІЯ ════════════════════════════════════════════

# Знайти помилки
grep -i "error\|fail\|critical" /var/log/syslog

# Знайти входи по SSH
grep "Accepted" /var/log/auth.log

# Знайти невдалі спроби входу
grep "Failed password" /var/log/auth.log

# Показати унікальні IP, що намагались увійти
grep "Failed password" /var/log/auth.log | awk '{print $11}' | sort | uniq -c | sort -rn

# ═══ ПІДРАХУНОК ════════════════════════════════════════════

# Кількість помилок за годину
grep "$(date '+%b %e %H')" /var/log/syslog | grep -c "error"

# Топ-10 процесів за кількістю записів у syslog
awk '{print $5}' /var/log/syslog | sort | uniq -c | sort -rn | head -10

# ═══ ЧАСОВІ ФІЛЬТРИ ════════════════════════════════════════

# Записи за сьогодні
grep "$(date '+%b %e')" /var/log/syslog | tail -100

# Записи між двома часовими мітками
awk '/Mar 13 08:00/,/Mar 13 09:00/' /var/log/syslog

# ═══ МОНІТОРИНГ В РЕАЛЬНОМУ ЧАСІ ══════════════════════════

# Слідкувати тільки за помилками
tail -f /var/log/syslog | grep --line-buffered -i "error\|crit\|fail"

# Підсвітити помилки кольором
journalctl -f | grep --color=auto -i "error\|fail\|warn"
```

---

### 2.8 `logrotate` — ротація логів

**Ротація логів** — автоматична заміна старих лог-файлів новими. Запобігає переповненню диска.

```bash
# Конфігурація
cat /etc/logrotate.conf       # глобальна
ls /etc/logrotate.d/          # конфіги для кожної програми

# Перевірити статус ротації
cat /var/lib/logrotate/status

# Запустити вручну (тест без реальних змін)
sudo logrotate --debug /etc/logrotate.conf

# Примусова ротація (ігнорувати часові умови)
sudo logrotate --force /etc/logrotate.d/nginx
```

#### Приклад конфігурації logrotate

```
# /etc/logrotate.d/myapp

/var/log/myapp.log {
    # Ротувати щотижня
    weekly

    # Зберігати 4 тижні (4 архіви)
    rotate 4

    # Стискати архіви
    compress
    # Відкласти стиснення на 1 цикл (щоб не стискати поточний)
    delaycompress

    # Не помилятись якщо файл відсутній
    missingok

    # Пропустити якщо файл порожній
    notifempty

    # Створити новий файл після ротації
    create 640 syslog adm

    # Виконати після ротації (перевідкрити файл)
    postrotate
        systemctl kill -s HUP rsyslog.service 2>/dev/null || true
    endscript
}
```

---

### 2.9 Постійне зберігання journald

За замовчуванням journald зберігає логи у RAM (`/run/log/journal/`) — вони зникають при перезавантаженні. Для постійного зберігання:

```bash
# Увімкнути постійне зберігання
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal
sudo systemctl restart systemd-journald

# Або через конфігурацію
sudo nano /etc/systemd/journald.conf
```

```ini
[Journal]
# Storage=auto означає: постійне якщо /var/log/journal існує
Storage=persistent

# Обмеження розміру (від загального обсягу диска)
SystemMaxUse=500M
SystemKeepFree=1G

# Обмеження часу зберігання
MaxRetentionSec=1month

# Стиснення
Compress=yes
```

```bash
# Перезапустити
sudo systemctl restart systemd-journald

# Перевірити
journalctl --disk-usage
ls -la /var/log/journal/
```

---

## Практичні завдання

### Завдання 1. Базовий BASH-скрипт

Написати скрипт `info.sh`, який виводить:
- Ім'я хосту та IP-адресу
- Версію ОС
- Час роботи системи (uptime)
- Відсоток зайнятого місця на /
- Кількість запущених процесів

```bash
#!/bin/bash
# Підказка: використовуйте hostname, ip addr, lsb_release, uptime, df, ps
```

### Завдання 2. Скрипт з умовами та циклом

Написати скрипт `check_services.sh`, що приймає список сервісів як аргументи та:
- Для кожного сервісу перевіряє статус
- Виводить "OK" або "STOPPED" відповідно
- Наприкінці виводить зведення: скільки запущено / зупинено

```bash
# Запуск:
bash check_services.sh cron ssh ufw rsyslog
```

### Завдання 3. Аналіз логів

```bash
# 1. Переглянути останні 20 рядків auth.log
# 2. Знайти всі рядки зі словом "session" в syslog
# 3. Переглянути логи cron через journalctl за сьогодні
# 4. Записати тестове повідомлення через logger та знайти його
logger -t test123 "Моє тестове повідомлення"
journalctl -t test123 -n 5
grep "test123" /var/log/syslog
```

### Завдання 4. Налаштування logrotate

Створити конфігурацію logrotate для `/var/log/myapp.log`:
- Ротація щодня
- Зберігати 7 архівів
- Стискати
- Не помилятись якщо файл відсутній

---

## Шпаргалка

```bash
# ═══ BASH-СКРИПТИ ══════════════════════════════════════════

chmod +x script.sh && ./script.sh    # надати права та запустити
bash -x script.sh                    # режим налагодження (trace)
bash -n script.sh                    # перевірка синтаксису без виконання

# Змінні
VAR="значення"                        # оголошення
echo "$VAR" / echo "${VAR}"           # використання
CMD=$(command)                        # результат команди
export VAR                            # зробити змінною середовища
readonly CONST="незмінна"             # константа

# Умови
[ condition ]                         # test
[[ condition ]]                       # розширений test (bash)
-f file / -d dir / -e path            # файл/директорія/існує
-z str / -n str                       # порожній/непорожній рядок
-eq -ne -lt -le -gt -ge               # числові порівняння

# Цикли
for i in list; do ...; done
for ((i=0; i<N; i++)); do ...; done
while [ cond ]; do ...; done
until [ cond ]; do ...; done

# ═══ ЛОГУВАННЯ ═════════════════════════════════════════════

tail -f /var/log/syslog               # стежити за syslog
tail -f /var/log/auth.log             # стежити за авторизацією
journalctl -f                         # стежити за journald
journalctl -u SERVICE                 # логи конкретного сервісу
journalctl -p err                     # тільки помилки
journalctl --since "1 hour ago"       # за останню годину
logger -t TAG -p local0.info "MSG"    # записати у syslog зі скрипту
grep -i "error" /var/log/syslog       # шукати помилки
sudo logrotate --force /etc/logrotate.d/APP  # примусова ротація
journalctl --vacuum-time=30d          # очистити старі записи journald
```

---

*Змістовий модуль 5, Заняття 3 | Ubuntu Server 24.04 LTS | Кафедра 21, ВІТІ*
