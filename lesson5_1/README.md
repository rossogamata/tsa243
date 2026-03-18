# 🐧 Змістовний модуль 5. Системне адміністрування
## ЗАНЯТТЯ 1 (Лекція) — Користувачі, групи, планування завдань, локалізація та системний час

> **Дисципліна:** Технології Системного Адміністрування | **Курс:** 2-й
> **ОС:** Ubuntu Server 24.04.4 LTS | **Тип заняття:** Лекція

---

## 📋 Навчальні питання

1. [Користувачі та групи](#1-користувачі-та-групи)
2. [Планування завдань](#2-планування-завдань)
3. [Локалізація](#3-локалізація)
4. [Системний час](#4-системний-час)

---

## 1. Користувачі та групи

### 1.1 Концепція прав у Linux

Linux — багатокористувацька система. Кожен об'єкт (файл, процес, сокет) належить **користувачу** і **групі**. Доступ до об'єктів визначається трьома рівнями прав: **власник (user)**, **група (group)**, **інші (others)**.

```
-rwxr-x--- 1 deploy devops 4096 Mar 13 09:00 deploy.sh
 │││├──┤├──┤   │      │
 │││  │   │    │      └── група-власник
 │││  │   │    └───────── користувач-власник
 │││  │   └────────────── права: інші (---)
 │││  └────────────────── права: група (r-x)
 │└┴───────────────────── права: власник (rwx)
 └────────────────────── тип: звичайний файл (-)
```

**Типи прав:**

| Символ | Число | Для файлу | Для каталогу |
|---|---|---|---|
| `r` | 4 | читання | перегляд вмісту (`ls`) |
| `w` | 2 | запис/зміна | створення/видалення файлів |
| `x` | 1 | виконання | перехід (`cd`) |
| `-` | 0 | заборонено | заборонено |

---

### 1.2 Файли облікових записів

**`/etc/passwd`** — база користувачів (відкрита для читання):

```
# формат: login:x:UID:GID:GECOS:home:shell
root:x:0:0:root:/root:/bin/bash
syslog:x:104:110::/home/syslog:/usr/sbin/nologin
ubuntu:x:1000:1000:Ubuntu:/home/ubuntu:/bin/bash
```

| Поле | Опис |
|---|---|
| `login` | ім'я користувача |
| `x` | пароль у `/etc/shadow` |
| `UID` | числовий ідентифікатор |
| `GID` | основна група |
| `GECOS` | повне ім'я / коментар |
| `home` | домашній каталог |
| `shell` | командний інтерпретатор |

**`/etc/shadow`** — зашифровані паролі (тільки root):

```
ubuntu:$6$rounds=4096$salt$hash...:19800:0:99999:7:::
#        │                          │      │ │     └── попередження (днів)
#        │                          │      │ └──────── максимум (99999=безстроково)
#        │                          │      └────────── мінімум (0=без обмежень)
#        │                          └───────────────── дата зміни (днів з 01.01.1970)
#        └──────────────────────────────────────────── хеш ($6$=SHA-512)
```

**`/etc/group`** — групи:

```
# формат: group_name:x:GID:members
sudo:x:27:ubuntu
docker:x:999:ubuntu,deploy
devops:x:1001:deploy,ansible
```

---

### 1.3 Управління користувачами

#### Створення

```bash
# Створити користувача з домашнім каталогом та shell
sudo useradd -m -s /bin/bash -c "Тарас Шевченко" taras
#             │   │            │                   └── login
#             │   │            └────────────────────── коментар (GECOS)
#             │   └─────────────────────────────────── shell
#             └─────────────────────────────────────── створити home

# Встановити пароль
sudo passwd taras

# Інтерактивний варіант (задає більше параметрів)
sudo adduser taras
```

#### Модифікація

```bash
# Змінити shell
sudo usermod -s /bin/zsh taras
#              └── --shell

# Заблокувати (додає ! перед хешем паролю)
sudo usermod -L taras
#              └── --lock

# Розблокувати
sudo usermod -U taras
#              └── --unlock

# Встановити дату закінчення акаунта (YYYY-MM-DD)
sudo usermod -e 2024-12-31 taras

# Змінити домашній каталог (перемістити файли)
sudo usermod -d /home/newhome -m taras
#              │                └── --move-home
#              └── --home

# Змінити UID
sudo usermod -u 1500 taras

# Змінити ім'я (login)
sudo usermod -l taras_new taras
```

#### Видалення

```bash
# Видалити користувача (зберегти home)
sudo userdel taras

# Видалити користувача та домашній каталог
sudo userdel -r taras
#              └── --remove

# Видалити та зробити резервну копію home
sudo userdel -r -b /backup taras
```

#### Перегляд інформації

```bash
# Поточний користувач і групи
whoami          # тільки ім'я
id              # UID, GID, всі групи
id taras        # інформація про конкретного користувача

# Детальна інформація про акаунт
getent passwd taras       # запис з /etc/passwd
sudo chage -l taras       # інформація про термін дії паролю

# Хто зараз у системі
who             # короткий список
w               # з активністю (навантаження, команда)
last            # журнал входів (з /var/log/wtmp)
lastb           # невдалі спроби входу (з /var/log/btmp)
```

---

### 1.4 Управління групами

```bash
# Створити групу
sudo groupadd devops
sudo groupadd -g 2001 devops   # із заданим GID

# Видалити групу
sudo groupdel devops

# Перейменувати групу
sudo groupmod -n ops devops

# Додати користувача до групи
sudo usermod -aG docker taras   # -a = append (не замінювати існуючі групи!)
#               └─────── додати до групи docker

# Альтернативний спосіб
sudo gpasswd -a taras docker

# Видалити з групи
sudo gpasswd -d taras docker

# Переглянути членів групи
getent group docker
groups taras        # всі групи користувача taras
```

> ⚠️ **Важливо:** після `usermod -aG` зміни набудуть чинності лише при наступному вході або після `newgrp docker`.

---

### 1.5 Права доступу

#### `chmod` — зміна прав

```bash
# Числовий (octal) спосіб
chmod 755 script.sh   # rwxr-xr-x
chmod 644 config.txt  # rw-r--r--
chmod 600 secret.key  # rw-------
chmod 700 privatedir/ # rwx------

# Символьний спосіб
chmod u+x script.sh   # додати виконання для власника
chmod g-w config.txt  # забрати запис у групи
chmod o=r public.txt  # встановити тільки читання для інших
chmod a+r readme.txt  # додати читання для всіх (all)
chmod ug=rw,o= file   # комбінований

# Рекурсивно
chmod -R 755 /var/www/html/
```

#### `chown` — зміна власника

```bash
# Змінити власника
sudo chown taras file.txt

# Змінити власника і групу
sudo chown taras:devops file.txt

# Змінити тільки групу
sudo chown :devops file.txt
# або:
sudo chgrp devops file.txt

# Рекурсивно
sudo chown -R deploy:www-data /var/www/
```

#### Спеціальні біти прав

```bash
# SUID (4) — файл виконується з правами власника
# Приклад: /usr/bin/passwd — змінює /etc/shadow від root
sudo chmod u+s /usr/bin/special
# або: chmod 4755 file

# SGID (2) — файл виконується з правами групи
#           — у каталозі: нові файли успадковують групу
sudo chmod g+s /shared/project/
# або: chmod 2775 dir

# Sticky bit (1) — у каталозі: видалення тільки свого файлу
# Приклад: /tmp — кожен може писати, але видалити тільки своє
sudo chmod +t /shared/tmp/
# або: chmod 1777 dir

# Перегляд спеціальних бітів
ls -la /tmp           # drwxrwxrwt (t = sticky)
ls -la /usr/bin/sudo  # -rwsr-xr-x (s = SUID)
```

---

### 1.6 `sudo` та привілеї

```bash
# Виконати команду від root
sudo command

# Виконати від іншого користувача
sudo -u taras command

# Відкрити shell від root
sudo -i         # login shell
sudo -s         # поточне середовище

# Редагувати /etc/sudoers БЕЗПЕЧНО (з валідацією)
sudo visudo

# Переглянути свої sudo-права
sudo -l
```

**Приклади записів у `/etc/sudoers`:**

```bash
# Повні права без пароля
deploy ALL=(ALL) NOPASSWD:ALL

# Тільки певні команди
taras ALL=(ALL) /usr/bin/systemctl restart nginx, /usr/bin/journalctl

# Права для всієї групи
%devops ALL=(ALL) ALL
```

---

## 2. Планування завдань

### 2.1 `cron` — планувальник повторюваних завдань

`cron` — системний демон, що запускає команди за розкладом. Конфігурується через **crontab** (cron table).

#### Синтаксис crontab

```
# ┌───────────── хвилина (0–59)
# │ ┌───────────── година (0–23)
# │ │ ┌───────────── день місяця (1–31)
# │ │ │ ┌───────────── місяць (1–12 або jan–dec)
# │ │ │ │ ┌───────────── день тижня (0–7, 0 і 7 = неділя, або sun–sat)
# │ │ │ │ │
# * * * * *  команда
```

**Спеціальні символи:**

| Символ | Значення | Приклад |
|---|---|---|
| `*` | будь-яке значення | `* * * * *` = щохвилини |
| `,` | перелік | `1,15,30 * * * *` = о 1, 15, 30 хв |
| `-` | діапазон | `0 9-17 * * *` = щогодини з 9 до 17 |
| `/` | крок | `*/15 * * * *` = кожні 15 хв |
| `@` | псевдоніми | `@reboot`, `@daily`, `@weekly` |

#### Приклади crontab-записів

```bash
# Резервна копія щодня о 02:30
30 2 * * * /usr/local/bin/backup.sh

# Оновлення БД кожні 15 хвилин
*/15 * * * * /opt/app/update_db.py

# Перезапуск сервісу кожного понеділка о 06:00
0 6 * * 1 systemctl restart myapp

# Очищення логів 1-го числа кожного місяця
0 0 1 * * find /var/log -name "*.log" -mtime +30 -delete

# Запуск при завантаженні системи
@reboot /opt/startup.sh

# Щоденний звіт о опівночі
@daily /usr/local/bin/daily_report.sh

# Щогодини (тільки у робочий час пн-пт)
0 8-18 * * 1-5 /opt/check_service.sh
```

#### Управління crontab

```bash
# Редагувати crontab поточного користувача
crontab -e

# Переглянути поточний crontab
crontab -l

# Видалити crontab
crontab -r

# Редагувати crontab іншого користувача (root)
sudo crontab -u taras -e

# Системні crontab-файли
cat /etc/crontab             # системний (з вказівкою користувача)
ls /etc/cron.d/              # конфігурації пакетів
ls /etc/cron.{hourly,daily,weekly,monthly}/  # скрипти за розкладом
```

**Формат `/etc/crontab`** (відрізняється додатковим полем USER):

```
# хв год день міс дт_тижня  USER    команда
17  *  *   *   *    root    cd / && run-parts --report /etc/cron.hourly
25  6  *   *   *    root    test -x /usr/sbin/anacron || ...
```

#### Де шукати логи cron

```bash
# Ubuntu 24.04 (systemd-journald)
journalctl -u cron --since today
journalctl -u cron -f          # в реальному часі

# Класичний syslog (якщо є)
grep CRON /var/log/syslog
```

---

### 2.2 `at` — одноразове відкладене виконання

```bash
# Встановлення
sudo apt install at -y

# Запустити о конкретний час
at 14:30
at> /usr/local/bin/report.sh
at> <Ctrl+D>

# Через певний проміжок
at now + 2 hours
at now + 30 minutes
at now + 1 day

# Конкретна дата та час
at 09:00 2024-12-25
at midnight tomorrow

# Перегляд черги
atq           # список запланованих завдань
at -l         # те саме

# Перегляд завдання
at -c 3       # показати вміст завдання #3

# Видалити завдання
atrm 3        # видалити завдання #3

# Запустити команду одразу через stdin
echo "/opt/script.sh" | at now + 5 minutes
```

> ℹ️ Доступ до `at` контролюється файлами `/etc/at.allow` та `/etc/at.deny`.

---

### 2.3 `systemd timers` — сучасна альтернатива cron

`systemd timers` — рекомендований підхід у сучасних Ubuntu-системах. Кожен таймер пов'язаний з `.service` юнітом.

#### Структура: два файли

**`/etc/systemd/system/backup.service`:**

```ini
[Unit]
Description=Daily Backup Service
After=network.target

[Service]
Type=oneshot
User=backup
ExecStart=/usr/local/bin/backup.sh
StandardOutput=journal
StandardError=journal
```

**`/etc/systemd/system/backup.timer`:**

```ini
[Unit]
Description=Daily Backup Timer
Requires=backup.service

[Timer]
# Щодня о 02:30
OnCalendar=*-*-* 02:30:00

# Або через проміжок після завантаження
OnBootSec=5min
OnUnitActiveSec=1h

# Зберегти час між перезавантаженнями
Persistent=true

[Install]
WantedBy=timers.target
```

#### Управління таймерами

```bash
# Активувати та запустити таймер
sudo systemctl daemon-reload
sudo systemctl enable --now backup.timer

# Переглянути всі таймери
systemctl list-timers --all

# Статус конкретного
systemctl status backup.timer

# Перевірити синтаксис OnCalendar
systemd-analyze calendar "*-*-* 02:30:00"
systemd-analyze calendar "weekly"

# Логи сервісу
journalctl -u backup.service
```

**Псевдоніми `OnCalendar`:**

```ini
OnCalendar=hourly        # щогодини
OnCalendar=daily         # щодня о 00:00
OnCalendar=weekly        # щотижня (понеділок)
OnCalendar=monthly       # щомісяця 1-го числа
OnCalendar=Mon-Fri 09:00 # пн-пт о 09:00
```

---

### 2.4 Порівняння планувальників

| Характеристика | `cron` | `at` | `systemd timer` |
|---|---|---|---|
| Повторення | ✅ | ❌ (одноразово) | ✅ |
| Залежності | ❌ | ❌ | ✅ |
| Логування | через syslog | через syslog | journald ✅ |
| Запуск після boot | `@reboot` | ❌ | `OnBootSec` ✅ |
| Persistent (пропущений час) | ❌ | — | ✅ |
| Складність налаштування | низька | низька | середня |

---

## 3. Локалізація

### 3.1 Що таке locale

**Locale** — набір параметрів, що визначає мовні та регіональні налаштування: мова інтерфейсу, кодування, формат дати, часу, чисел, валюти.

#### Структура змінних locale

```bash
# Переглянути поточні налаштування
locale

# Виведення:
LANG=uk_UA.UTF-8           # основна мова
LANGUAGE=uk_UA:uk:en       # пріоритет мов
LC_CTYPE=uk_UA.UTF-8       # тип символів
LC_NUMERIC=uk_UA.UTF-8     # формат чисел (1 234,56)
LC_TIME=uk_UA.UTF-8        # формат дати/часу
LC_MONETARY=uk_UA.UTF-8    # формат валюти
LC_MESSAGES=en_US.UTF-8    # мова системних повідомлень
LC_PAPER=uk_UA.UTF-8       # розмір паперу
LC_ALL=                    # перевизначає всі (якщо задано)
```

---

### 3.2 Управління locale

```bash
# Переглянути встановлені locale
locale -a
locale -a | grep uk

# Переглянути доступні (для генерації)
cat /etc/locale.gen

# Генерація та встановлення locale
sudo locale-gen uk_UA.UTF-8
sudo locale-gen en_US.UTF-8

# Встановити системний locale (записує у /etc/locale.conf)
sudo localectl set-locale LANG=uk_UA.UTF-8

# Або через update-locale (Ubuntu)
sudo update-locale LANG=uk_UA.UTF-8 LANGUAGE=uk_UA:uk:en

# Перегляд поточного locale системи
localectl
localectl status

# Встановлення через dpkg-reconfigure (інтерактивно)
sudo dpkg-reconfigure locales
```

#### Файли налаштувань

```bash
# Системний locale (Ubuntu 24.04)
cat /etc/locale.conf
# або
cat /etc/default/locale

# Для конкретного користувача (у .bashrc або .profile)
echo 'export LANG=uk_UA.UTF-8' >> ~/.bashrc
echo 'export LC_ALL=uk_UA.UTF-8' >> ~/.bashrc
```

#### Тимчасова зміна locale для команди

```bash
# Запустити команду з іншим locale
LANG=C ls /usr/bin        # виведення англійською (POSIX)
LC_TIME=en_US.UTF-8 date  # дата у американському форматі
LANG=C sort file.txt      # POSIX-сортування (по байтах)
```

---

### 3.3 Розкладка клавіатури

```bash
# Поточна розкладка
localectl status
# Виведе: X11 Layout: ua, VC Keymap: ua

# Встановити розкладку для консолі (VC) та X11
sudo localectl set-keymap ua
sudo localectl set-x11-keymap ua

# Комбінована (uk/en з перемиканням Alt+Shift)
sudo localectl set-x11-keymap "ua,us" "" "" "grp:alt_shift_toggle"

# Переглянути доступні розкладки
localectl list-keymaps | grep -i ua
```

---

### 3.4 Кодування та iconv

```bash
# Конвертація файлу між кодуваннями
iconv -f windows-1251 -t utf-8 input.txt -o output.txt
#       │                │
#       │                └── вихідне кодування
#       └────────────────── вхідне кодування

# Визначити кодування файлу
file -i document.txt      # виводить charset
chardet document.txt      # якщо встановлено (pip install chardet)

# Перевірити валідність UTF-8
iconv -f utf-8 -t utf-8 file.txt > /dev/null && echo "OK"

# Переглянути список доступних кодувань
iconv -l | head -30
```

---

## 4. Системний час

### 4.1 Апаратний та системний час

Linux має два годинники:

- **RTC (Real-Time Clock / Hardware Clock)** — апаратний, на материнській платі, працює без живлення (батарейка CMOS). Зберігає час у UTC або локальному часовому поясі.
- **System Clock** — програмний, у ядрі, ініціалізується з RTC при завантаженні. Показує `date`.

```
Завантаження системи:
  RTC (апаратний) → синхронізується → System Clock (ядро)
                                              │
  NTP сервери    → (за мережею) ──────────→ ┘
```

---

### 4.2 `timedatectl` — основний інструмент

```bash
# Поточний стан (час, зона, NTP)
timedatectl
# або
timedatectl status

# Вивід:
#                Local time: Wed 2024-03-13 09:42:15 EET
#            Universal time: Wed 2024-03-13 07:42:15 UTC
#                  RTC time: Wed 2024-03-13 07:42:14
#                 Time zone: Europe/Kyiv (EET, +0200)
# System clock synchronized: yes
#               NTP service: active
#           RTC in local TZ: no

# Встановити часовий пояс
sudo timedatectl set-timezone Europe/Kyiv

# Переглянути доступні часові пояси
timedatectl list-timezones
timedatectl list-timezones | grep -i kyiv
timedatectl list-timezones | grep -i europe

# Встановити час вручну (тільки якщо NTP вимкнено)
sudo timedatectl set-ntp false
sudo timedatectl set-time "2024-03-13 09:30:00"

# Увімкнути синхронізацію NTP
sudo timedatectl set-ntp true

# Зберігати RTC у UTC (рекомендовано)
sudo timedatectl set-local-rtc 0
```

---

### 4.3 `date` — перегляд та встановлення часу

```bash
# Поточна дата і час
date

# Форматований вивід
date "+%Y-%m-%d %H:%M:%S"    # 2024-03-13 09:42:15
date "+%d.%m.%Y"             # 13.03.2024
date "+%A, %d %B %Y"         # Wednesday, 13 March 2024
date "+%s"                   # Unix timestamp (секунди з 1970-01-01)
date "+%Z %z"                # EET +0200

# Час у UTC
date -u

# Дата відносна
date -d "tomorrow"
date -d "2 weeks ago"
date -d "next Monday"
date -d "@1710317535"          # з Unix timestamp

# Встановити системний час (від root, NTP має бути вимкнено)
sudo date -s "2024-03-13 09:30:00"

# Використання у скриптах
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
LOGFILE="/var/log/backup_${TIMESTAMP}.log"
```

**Основні формат-специфікатори `date`:**

| Специфікатор | Значення | Приклад |
|---|---|---|
| `%Y` | рік (4 цифри) | 2024 |
| `%m` | місяць (01-12) | 03 |
| `%d` | день (01-31) | 13 |
| `%H` | година (00-23) | 09 |
| `%M` | хвилина (00-59) | 42 |
| `%S` | секунда (00-59) | 15 |
| `%s` | Unix timestamp | 1710317535 |
| `%A` | повна назва дня | Wednesday |
| `%B` | повна назва місяця | March |
| `%Z` | назва часового поясу | EET |
| `%z` | зміщення UTC | +0200 |

---

### 4.4 Апаратний годинник `hwclock`

```bash
# Переглянути час апаратного годинника
sudo hwclock
sudo hwclock --show

# Синхронізувати системний час → RTC (записати у апарат)
sudo hwclock --systohc
#               └── system to hardware clock

# Синхронізувати RTC → системний час (прочитати з апарату)
sudo hwclock --hctosys
#               └── hardware to system clock

# Показати час у UTC
sudo hwclock --utc

# Показати час у локальному часовому поясі
sudo hwclock --localtime
```

---

### 4.5 NTP — Network Time Protocol

**NTP** забезпечує автоматичну синхронізацію системного часу з еталонними серверами. Точність — мілісекунди.

#### `systemd-timesyncd` — вбудований NTP-клієнт Ubuntu

```bash
# Статус служби
systemctl status systemd-timesyncd
timedatectl show-timesync

# Детальна інформація про синхронізацію
timedatectl timesync-status

# Конфігурація
cat /etc/systemd/timesyncd.conf

# Налаштувати NTP-сервери (Ukraine/NTP pool)
sudo nano /etc/systemd/timesyncd.conf
```

**`/etc/systemd/timesyncd.conf`:**

```ini
[Time]
# Основні сервери
NTP=0.ua.pool.ntp.org 1.ua.pool.ntp.org 2.ua.pool.ntp.org

# Резервні сервери
FallbackNTP=0.pool.ntp.org 1.pool.ntp.org ntp.ubuntu.com

# Максимальне відхилення (після якого = помилка)
RootDistanceMaxSec=5

# Інтервал опитування
PollIntervalMinSec=32
PollIntervalMaxSec=2048
```

```bash
# Перезапустити після змін
sudo systemctl restart systemd-timesyncd

# Перевірити синхронізацію
timedatectl timesync-status
```

#### `chrony` — повнофункціональний NTP (рекомендовано для серверів)

```bash
# Встановлення
sudo apt install chrony -y

# Статус синхронізації
chronyc tracking
chronyc sources -v
chronyc sourcestats

# Конфігурація
sudo nano /etc/chrony/chrony.conf
```

**`/etc/chrony/chrony.conf` (основні директиви):**

```ini
# NTP-сервери (ua.pool.ntp.org)
pool 0.ua.pool.ntp.org iburst maxsources 4
pool 1.ua.pool.ntp.org iburst maxsources 1

# Зберігати дрейф годинника
driftfile /var/lib/chrony/chrony.drift

# Дозволити крокову корекцію при старті
makestep 1.0 3

# Синхронізувати RTC
rtcsync

# Логи
logdir /var/log/chrony
```

---

### 4.6 Часові пояси

```bash
# Поточний часовий пояс
cat /etc/localtime    # символічне посилання
ls -la /etc/localtime
# /etc/localtime -> /usr/share/zoneinfo/Europe/Kyiv

# Встановити часовий пояс
sudo timedatectl set-timezone Europe/Kyiv

# Або вручну (символічне посилання)
sudo ln -sf /usr/share/zoneinfo/Europe/Kyiv /etc/localtime

# Файл /etc/timezone (для сумісності)
cat /etc/timezone     # Europe/Kyiv

# Переглянути базу часових поясів
ls /usr/share/zoneinfo/
ls /usr/share/zoneinfo/Europe/

# Конвертація між часовими поясами у bash
TZ="America/New_York" date
TZ="Asia/Tokyo" date
```

---

## 📖 Шпаргалка — ключові команди

```bash
# ═══ КОРИСТУВАЧІ ══════════════════════════════════
sudo useradd -m -s /bin/bash -c "Full Name" username  # створити
sudo passwd username                                   # встановити пароль
sudo usermod -aG groupname username                    # додати до групи
sudo userdel -r username                               # видалити з home
id username                                            # UID/GID/групи
who / w                                               # хто в системі
last / lastb                                          # журнал входів

# ═══ ГРУПИ ════════════════════════════════════════
sudo groupadd groupname                               # створити групу
sudo groupdel groupname                               # видалити групу
getent group groupname                                # члени групи
groups username                                       # групи користувача

# ═══ ПРАВА ════════════════════════════════════════
chmod 755 file / chmod u+x file                       # права (числові / символьні)
chown user:group file                                 # змінити власника
chmod -R 775 dir/                                     # рекурсивно
ls -la                                                # переглянути права

# ═══ ПЛАНУВАННЯ ════════════════════════════════════
crontab -e                                            # редагувати cron
crontab -l                                            # переглянути cron
at now + 1 hour                                       # одноразово через 1 год
atq / atrm N                                          # черга at / видалити
systemctl list-timers --all                           # systemd таймери

# ═══ ЛОКАЛІЗАЦІЯ ══════════════════════════════════
locale                                                # поточні налаштування
locale -a                                             # встановлені locale
sudo localectl set-locale LANG=uk_UA.UTF-8            # встановити
sudo localectl set-keymap ua                          # розкладка клавіатури
iconv -f cp1251 -t utf-8 in.txt -o out.txt            # конвертація кодування

# ═══ СИСТЕМНИЙ ЧАС ════════════════════════════════
timedatectl                                           # статус (час, зона, NTP)
timedatectl list-timezones | grep Kyiv                # пошук часового поясу
sudo timedatectl set-timezone Europe/Kyiv             # встановити зону
sudo timedatectl set-ntp true                         # увімкнути NTP
date "+%Y-%m-%d %H:%M:%S"                             # форматований вивід
sudo hwclock --systohc                                # синхронізувати RTC
chronyc tracking                                      # статус NTP (chrony)
```

---

## 🔗 Додаткові ресурси

- [Ubuntu Docs — User Management](https://ubuntu.com/server/docs/security-users)
- [Ubuntu Docs — Time Synchronization](https://ubuntu.com/server/docs/network-ntp)
- [systemd.timer man page](https://www.freedesktop.org/software/systemd/man/systemd.timer.html)
- [Cron Expression Generator](https://crontab.guru/)
- [NTP Pool Project — Ukraine](https://www.ntppool.org/zone/ua)
- [IANA Time Zone Database](https://www.iana.org/time-zones)
- [GNU Coreutils — date](https://www.gnu.org/software/coreutils/manual/html_node/date-invocation.html)

---

*Змістовний модуль 5, Заняття 1 | Ubuntu Server 24.04.4 LTS | Кафедра 21, ВІТІ*
