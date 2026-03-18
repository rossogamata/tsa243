# 🐧 Змістовний модуль 5. Системне адміністрування
## ЗАНЯТТЯ 2 (Практичне) — Адміністрування користувачів, планування завдань, локалізація та системний час

> **Дисципліна:** Технології Системного Адміністрування | **Курс:** 2-й
> **ОС:** Ubuntu Server 24.04.4 LTS | **Тип заняття:** Практичне

---

## 📋 Навчальні питання

| № | Тема | Час |
|---|---|---|
| 1 | [Створення користувачів та груп](#питання-1--створення-користувачів-та-груп) | ~30 хв |
| 2 | [Планування завдань](#питання-2--планування-завдань) | ~30 хв |
| 3 | [Налаштування локалізації](#питання-3--налаштування-локалізації) | ~15 хв |
| 4 | [Налаштування системного часу](#питання-4--налаштування-системного-часу) | ~15 хв |
| 5 | [Самоперевірка](#самоперевірка) | ~20 хв |

---

## ⚙️ Підготовка робочого місця

```bash
# Переконатись, що система оновлена
sudo apt update && sudo apt upgrade -y

# Встановити необхідні пакети для заняття
sudo apt install -y at tree vim chrony

# Перевірити стан системи
uname -a          # версія ядра
lsb_release -a    # версія Ubuntu
whoami            # поточний користувач
id                # UID, GID, групи
```

---

## ПИТАННЯ 1 — Створення користувачів та груп

### Завдання 1.1 — Підготовка організаційної структури

Змоделюємо навчальний підрозділ: **кафедра із трьома відділами**.

```
Кафедра 21
├── Група: dept21           ← загальна група кафедри
├── Група: instructors      ← викладачі
├── Група: cadets           ← курсанти
└── Група: sysadmins        ← системні адміністратори
```

```bash
# Крок 1: Створення груп
sudo groupadd dept21        # основна група кафедри
sudo groupadd instructors   # група викладачів
sudo groupadd cadets        # група курсантів
sudo groupadd sysadmins     # група системних адміністраторів

# Переконатись, що групи створено
getent group dept21 instructors cadets sysadmins

# Або переглянути хвости /etc/group
tail -6 /etc/group
```

---

### Завдання 1.2 — Створення користувачів

```bash
# ── Викладачі ──────────────────────────────────────────────
# useradd: -m (створити home), -s (shell), -c (коментар/GECOS), -g (основна група)
sudo useradd -m -s /bin/bash -c "Іваненко Василь" -g instructors ivanenko
sudo useradd -m -s /bin/bash -c "Петренко Олена"  -g instructors petrenko

# Встановити паролі
echo "ivanenko:Inst@2024!" | sudo chpasswd   # chpasswd читає login:password з stdin
echo "petrenko:Inst@2024!" | sudo chpasswd

# ── Курсанти ──────────────────────────────────────────────
sudo useradd -m -s /bin/bash -c "Шевченко Тарас"    -g cadets shevchenko
sudo useradd -m -s /bin/bash -c "Коваленко Олег"    -g cadets kovalenko
sudo useradd -m -s /bin/bash -c "Бондаренко Марія"  -g cadets bondarenko

echo "shevchenko:Cadet@2024!" | sudo chpasswd
echo "kovalenko:Cadet@2024!"  | sudo chpasswd
echo "bondarenko:Cadet@2024!" | sudo chpasswd

# ── Системний адміністратор ────────────────────────────────
sudo useradd -m -s /bin/bash -c "Сисадмін Кафедри" -g sysadmins sysadmin21
echo "sysadmin21:SysAdm@2024!" | sudo chpasswd

# ── Технічний акаунт (без входу) ──────────────────────────
# /usr/sbin/nologin — shell, який забороняє інтерактивний вхід
sudo useradd -r -s /usr/sbin/nologin -c "Backup Service" backup_svc
#              └── -r: системний акаунт (UID < 1000, без home за замовчуванням)
```

---

### Завдання 1.3 — Налаштування додаткових груп

```bash
# Додати користувачів до додаткових груп
# ВАЖЛИВО: -a (append) — НЕ замінює існуючі групи, а додає!
sudo usermod -aG dept21 ivanenko    # викладач → загальна група кафедри
sudo usermod -aG dept21 petrenko
sudo usermod -aG dept21 shevchenko  # курсанти → загальна група кафедри
sudo usermod -aG dept21 kovalenko
sudo usermod -aG dept21 bondarenko

# Адміністратор → всі групи
sudo usermod -aG dept21,instructors,cadets sysadmin21

# Перевірити групи конкретного користувача
groups ivanenko
id shevchenko

# Переглянути список членів групи dept21
getent group dept21
```

---

### Завдання 1.4 — Організація спільного каталогу

```bash
# Створити ієрархію каталогів кафедри
sudo mkdir -p /opt/dept21/{shared,instructors,cadets,scripts,logs}
#                          └── {}: bash brace expansion — створює всі підкаталоги

# Встановити власника та групу
sudo chown -R root:dept21 /opt/dept21           # власник root, група dept21
sudo chown -R root:instructors /opt/dept21/instructors
sudo chown -R root:cadets /opt/dept21/cadets

# Права:
# 2775 = SGID(2) + rwx(7) + rwx(7) + r-x(5)
# SGID на каталозі: нові файли успадкують групу каталогу
sudo chmod 2775 /opt/dept21/shared
sudo chmod 2770 /opt/dept21/instructors    # 2770: група повний доступ, інші — нічого
sudo chmod 2750 /opt/dept21/cadets         # 2750: група читання+виконання
sudo chmod 1777 /opt/dept21/logs           # 1777: sticky bit — кожен пише тільки своє

# Перевірити результат
ls -la /opt/dept21/
# drwxrwsr-x  dept21 shared     ← s у групі = SGID
# drwxrws---  instructors        ← доступ тільки групі
# drwxr-s---  cadets             ← курсанти читають
# drwxrwxrwt  logs               ← t = sticky bit
```

---

### Завдання 1.5 — Налаштування sudo

```bash
# Редагувати sudoers ТІЛЬКИ через visudo (перевіряє синтаксис!)
sudo visudo

# Або через окремий файл у /etc/sudoers.d/ (краща практика)
# Кожен файл = окреме правило, легко додавати/видаляти

# Надати sysadmin21 повні права без пароля
echo "sysadmin21 ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/sysadmin21
sudo chmod 440 /etc/sudoers.d/sysadmin21   # обов'язкові права для файлів sudoers.d

# Надати instructors право перезапускати сервіси
echo "%instructors ALL=(ALL) /usr/bin/systemctl restart *, /usr/bin/journalctl" \
  | sudo tee /etc/sudoers.d/instructors
sudo chmod 440 /etc/sudoers.d/instructors

# Перевірити валідність
sudo visudo -c                             # -c: тільки перевірка, без редагування
sudo -l -U sysadmin21                      # переглянути права конкретного користувача
```

---

### Завдання 1.6 — Управління паролями та терміном дії

```bash
# Переглянути поточні параметри паролю
sudo chage -l shevchenko

# Встановити параметри:
# -M: максимальний термін дії пароля (90 днів)
# -m: мінімальний термін (7 днів — не може змінити раніше)
# -W: попередження за N днів до закінчення
# -I: заблокувати через N днів після закінчення
# -E: дата закінчення акаунта
sudo chage -M 90 -m 7 -W 14 -I 30 shevchenko

# Примусово змусити змінити пароль при наступному вході
sudo chage -d 0 shevchenko
#              └── -d 0: дата останньої зміни = 01.01.1970 → застарілий

# Встановити дату закінчення акаунта (YYYY-MM-DD)
sudo chage -E 2025-06-30 shevchenko

# Заблокувати/розблокувати акаунт
sudo usermod -L kovalenko    # Lock: додає ! перед хешем у /etc/shadow
sudo usermod -U kovalenko    # Unlock: прибирає !

# Перевірити стан через /etc/shadow
sudo grep kovalenko /etc/shadow | cut -d: -f2 | head -c 5
# !$6$... = заблокований; $6$... = активний
```

---

### Завдання 1.7 — Моніторинг та аудит

```bash
# Хто зараз у системі
who -a            # всі сесії, включаючи системні
w                 # з даними про навантаження і командами

# Журнал входів (з /var/log/wtmp)
last              # всі входи
last ivanenko     # входи конкретного користувача
last -n 10        # останні 10 записів

# Невдалі спроби входу (з /var/log/btmp)
sudo lastb        # потребує root

# Останній вхід кожного користувача
lastlog
lastlog -u shevchenko

# Журнал аутентифікації через systemd
sudo journalctl _SYSTEMD_UNIT=ssh.service --since today
sudo journalctl -u systemd-logind --since "1 hour ago"

# Перевірка прав файлів (пошук SUID/SGID)
find /usr/bin -perm /4000 2>/dev/null   # SUID файли у /usr/bin
find /opt/dept21 -type f -perm /g+w     # файли з правом запису групи
```

---

### ✅ Контрольні запитання до Питання 1

1. Чим відрізняється `useradd` від `adduser`?
2. Що станеться якщо виконати `usermod -G docker taras` замість `usermod -aG docker taras`?
3. Для чого потрібен sticky bit на каталозі `/tmp`?
4. Чому не можна редагувати `/etc/sudoers` напряму через `nano`?

---

## ПИТАННЯ 2 — Планування завдань

### Завдання 2.1 — Базова робота з crontab

```bash
# Відкрити crontab поточного користувача для редагування
# За замовчуванням використовує $EDITOR (nano або vi)
crontab -e

# Додати наступні записи (пояснення — у коментарях):

# Щохвилини записувати поточний час і користувачів у лог
* * * * * echo "$(date '+\%Y-\%m-\%d \%H:\%M:\%S') $(who | wc -l) users" >> /tmp/activity.log

# Щогодини (на 0-й хвилині) — очистити /tmp від файлів старших 7 днів
0 * * * * find /tmp -maxdepth 1 -mtime +7 -delete 2>/dev/null

# Щодня о 23:55 — резервна копія домашнього каталогу
55 23 * * * tar -czf /opt/dept21/logs/home_backup_$(date +\%Y\%m\%d).tar.gz ~/

# Кожні 15 хвилин у робочий час (пн–пт, 08–18)
*/15 8-18 * * 1-5 /opt/dept21/scripts/check_status.sh 2>/dev/null

# Перша субота місяця о 04:00 — повна перевірка диску
0 4 1-7 * 6 df -h >> /opt/dept21/logs/disk_report.log

# Переглянути зміст crontab
crontab -l

# Перевірити синтаксис cron-виразу онлайн: https://crontab.guru
```

---

### Завдання 2.2 — Системний crontab

```bash
# Системний crontab (відрізняється полем USER між часом і командою)
sudo nano /etc/cron.d/dept21

# Вміст файлу /etc/cron.d/dept21:
# хв  год  день  міс  дт_тж  USER      команда
# 0   2    *     *    *      root      /opt/dept21/scripts/nightly_backup.sh
# */5 *    *     *    *      sysadmin21 /opt/dept21/scripts/monitor.sh >> /opt/dept21/logs/monitor.log 2>&1

# Права на файл cron.d (важливо!)
sudo chmod 644 /etc/cron.d/dept21   # має бути 644, НЕ виконуваний
sudo chown root:root /etc/cron.d/dept21

# Переглянути системні cron-каталоги
ls -la /etc/cron.{hourly,daily,weekly,monthly}/
# Скрипти у цих каталогах запускаються автоматично
```

---

### Завдання 2.3 — Створення скриптів для cron

```bash
# Створити каталог для скриптів
sudo mkdir -p /opt/dept21/scripts

# Скрипт моніторингу дискового простору
sudo tee /opt/dept21/scripts/disk_alert.sh << 'EOF'
#!/bin/bash
# disk_alert.sh — перевірка вільного місця, запис у лог
THRESHOLD=80                                      # поріг у відсотках
LOGFILE="/opt/dept21/logs/disk_alert.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# df -h: показати диски; awk: знайти розділи > THRESHOLD%
ALERT=$(df -h | awk -v threshold="$THRESHOLD" '
  NR>1 && substr($5,1,length($5)-1) > threshold {
    print $0
  }
')

if [ -n "$ALERT" ]; then
    echo "[$TIMESTAMP] ALERT! Диск заповнений понад ${THRESHOLD}%:" >> "$LOGFILE"
    echo "$ALERT" >> "$LOGFILE"
else
    echo "[$TIMESTAMP] OK. Диск у нормі." >> "$LOGFILE"
fi
EOF

# Зробити виконуваним
sudo chmod +x /opt/dept21/scripts/disk_alert.sh
sudo chown root:dept21 /opt/dept21/scripts/disk_alert.sh

# Додати до crontab (перевірка кожні 30 хвилин)
(crontab -l 2>/dev/null; echo "*/30 * * * * /opt/dept21/scripts/disk_alert.sh") | crontab -

# Запустити вручну для перевірки
/opt/dept21/scripts/disk_alert.sh
cat /opt/dept21/logs/disk_alert.log
```

---

### Завдання 2.4 — Планувальник `at`

```bash
# Переконатись, що демон atd запущений
systemctl status atd
sudo systemctl enable --now atd    # запустити якщо не активний

# Виконати команду через 2 хвилини
at now + 2 minutes << 'EOF'
echo "$(date): Завдання at виконано!" >> /tmp/at_test.log
who >> /tmp/at_test.log
EOF

# Виконати о конкретний час сьогодні
at 23:59 << 'EOF'
echo "$(date): Нічна перевірка" >> /opt/dept21/logs/nightly.log
df -h >> /opt/dept21/logs/nightly.log
EOF

# Переглянути чергу завдань
atq             # номер, дата/час, черга (a=at), власник
at -l           # те саме, довга форма

# Переглянути вміст конкретного завдання
at -c 1         # показати завдання №1 (з усіма змінними середовища)

# Видалити завдання
atrm 2          # видалити завдання №2

# Перевірити результат через 2+ хвилини
sleep 130 && cat /tmp/at_test.log
```

---

### Завдання 2.5 — systemd Timer

```bash
# Створити сервіс для перевірки стану кафедри
sudo tee /etc/systemd/system/dept21-monitor.service << 'EOF'
[Unit]
Description=Dept21 System Monitor
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=/opt/dept21/scripts/disk_alert.sh
StandardOutput=journal
StandardError=journal
EOF

# Створити таймер (запуск кожні 30 хвилин)
sudo tee /etc/systemd/system/dept21-monitor.timer << 'EOF'
[Unit]
Description=Dept21 Monitor Timer (every 30 min)
Requires=dept21-monitor.service

[Timer]
# Через 1 хвилину після завантаження
OnBootSec=1min

# Кожні 30 хвилин після останнього запуску
OnUnitActiveSec=30min

# Зберегти пропущені запуски між перезавантаженнями
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Активувати
sudo systemctl daemon-reload
sudo systemctl enable --now dept21-monitor.timer

# Перевірити
systemctl status dept21-monitor.timer
systemctl list-timers dept21-monitor.timer

# Запустити сервіс вручну (без очікування таймера)
sudo systemctl start dept21-monitor.service

# Переглянути логи
journalctl -u dept21-monitor.service --since today -f
```

---

### Завдання 2.6 — Перегляд та відлагодження cron

```bash
# Логи cron через journald (Ubuntu 24.04)
journalctl -u cron --since "1 hour ago"
journalctl -u cron -f          # стежити в реальному часі

# Перевірити, що крон-сервіс активний
systemctl status cron

# Дозволи на виконання cron: /etc/cron.allow і /etc/cron.deny
# Якщо /etc/cron.allow існує → тільки перелічені у ньому мають доступ
# Якщо тільки /etc/cron.deny → всі окрім перелічених
cat /etc/cron.deny 2>/dev/null || echo "Файл відсутній — доступ усім"

# Змінні середовища у crontab (додати на початок crontab -e)
# SHELL=/bin/bash           ← використовуваний shell
# PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# MAILTO=""                 ← "" = не надсилати email з виводом
```

---

### ✅ Контрольні запитання до Питання 2

1. Який запис crontab запускає завдання о 00:00 першого числа кожного місяця?
2. Чим `at` відрізняється від `cron`? Коли краще використовувати `at`?
3. Яку перевагу має `systemd timer` над `cron` при повторних завданнях?
4. Як перевірити логи виконання cron-завдань у Ubuntu 24.04?

---

## ПИТАННЯ 3 — Налаштування локалізації

### Завдання 3.1 — Діагностика поточного стану

```bash
# Переглянути поточні налаштування locale
locale

# Детальна інформація через localectl
localectl status
# Виведе:
#    System Locale: LANG=en_US.UTF-8
#        VC Keymap: ua
#       X11 Layout: ua

# Переглянути всі встановлені locale
locale -a

# Переглянути доступні для генерації
grep -v "^#" /etc/locale.gen | head -20
```

---

### Завдання 3.2 — Встановлення нових locale

```bash
# Перевірити, чи встановлено uk_UA.UTF-8
locale -a | grep uk

# Якщо відсутнє — встановити через locale-gen
sudo locale-gen uk_UA.UTF-8
sudo locale-gen en_US.UTF-8

# Оновити кеш locale
sudo update-locale

# Перевірити
locale -a | grep -E "uk_UA|en_US"

# Альтернатива — інтерактивний вибір через dpkg-reconfigure
# sudo dpkg-reconfigure locales
```

---

### Завдання 3.3 — Зміна системного locale

```bash
# Встановити системний locale
sudo localectl set-locale LANG=uk_UA.UTF-8

# Або через update-locale (Ubuntu-специфічний спосіб)
sudo update-locale \
  LANG=uk_UA.UTF-8 \
  LANGUAGE=uk_UA:uk:en \
  LC_MESSAGES=en_US.UTF-8   # системні повідомлення залишити англійськими

# Перевірити що записано у файл
cat /etc/locale.conf         # systemd-системи
cat /etc/default/locale      # Ubuntu (може бути або те, або інше)

# УВАГА: зміна набуває чинності після перезавантаження або:
source /etc/default/locale
locale                       # перевірити

# Тимчасова зміна тільки для поточної сесії
export LANG=uk_UA.UTF-8
export LC_TIME=uk_UA.UTF-8
date                         # тепер дата у форматі ua
```

---

### Завдання 3.4 — Розкладка клавіатури

```bash
# Поточна розкладка
localectl status

# Встановити розкладку консолі (VC = Virtual Console)
sudo localectl set-keymap ua           # тільки ua

# Встановити розкладку для X11 (графічне середовище)
sudo localectl set-x11-keymap ua       # тільки ua

# Дві розкладки з перемиканням Alt+Shift
sudo localectl set-x11-keymap "ua,us" "" "" "grp:alt_shift_toggle"
#                               │   │   │    └── варіант перемикання
#                               │   │   └──────── variant (залишити порожнім)
#                               │   └──────────── model (залишити порожнім)
#                               └──────────────── розкладки через кому

# Переглянути доступні розкладки
localectl list-keymaps | grep -E "^ua|^en|^ru"

# Для тексту консолі: перевірити поточну
cat /etc/vconsole.conf         # KEYMAP=ua
```

---

### Завдання 3.5 — Конвертація кодувань

```bash
# Створити тестовий файл у CP1251 (Windows-кодування)
echo -e "\xC2\xE0\xF1\xFF \xE4\xE0\xED\xE8\xF5" > /tmp/cp1251_test.txt
#        ← байти CP1251 для "Ваша даних" (спрощено для прикладу)

# Або скопіювати файл з Windows через scp і перевірити:
file -i /tmp/windows_file.txt        # charset=windows-1251

# Конвертувати CP1251 → UTF-8
iconv -f windows-1251 -t utf-8 /tmp/cp1251_test.txt -o /tmp/utf8_result.txt
#       │                │       └── вхідний файл       └── вихідний файл
#       └── FROM          └── TO

# Конвертувати UTF-8 → ASCII (з транслітерацією)
iconv -f utf-8 -t ascii//TRANSLIT input.txt -o output.txt
#                          └── TRANSLIT: спробує транслітерувати символи

# Переглянути всі доступні кодування
iconv -l | head -40

# Визначити кодування файлу
file -i /tmp/utf8_result.txt         # charset=utf-8

# Перевірка валідності UTF-8
iconv -f utf-8 -t utf-8 /tmp/utf8_result.txt > /dev/null 2>&1 \
  && echo "UTF-8 валідний" \
  || echo "Файл містить помилки кодування"
```

---

### ✅ Контрольні запитання до Питання 3

1. Чим відрізняється `LANG` від `LC_ALL`?
2. Яка команда генерує нові locale з `/etc/locale.gen`?
3. Для чого потрібна опція `LC_MESSAGES=en_US.UTF-8` при українській локалі?
4. Як тимчасово змінити locale тільки для однієї команди?

---

## ПИТАННЯ 4 — Налаштування системного часу

### Завдання 4.1 — Діагностика стану часу

```bash
# Повна інформація про час системи
timedatectl status
# Зверніть увагу на:
# "System clock synchronized: yes"  ← NTP активний і синхронізований
# "NTP service: active"              ← служба запущена
# "RTC in local TZ: no"             ← RTC у UTC (правильно!)

# Поточний час у різних форматах
date                                  # локальний формат
date -u                               # UTC
date "+%Y-%m-%d %H:%M:%S %Z"         # кастомний формат
date "+%s"                            # Unix timestamp

# Апаратний годинник
sudo hwclock --show --verbose         # детальний вивід RTC
```

---

### Завдання 4.2 — Налаштування часового поясу

```bash
# Переглянути поточний часовий пояс
timedatectl | grep "Time zone"
cat /etc/timezone
ls -la /etc/localtime   # символічне посилання → /usr/share/zoneinfo/...

# Знайти правильний часовий пояс для України
timedatectl list-timezones | grep -i ukraine
timedatectl list-timezones | grep -i kyiv

# Встановити часовий пояс Київ
sudo timedatectl set-timezone Europe/Kyiv

# Перевірити результат
timedatectl
date    # має показати +0200 (EET) або +0300 (EEST влітку)

# Переглянути інформацію про часовий пояс
zdump -v /usr/share/zoneinfo/Europe/Kyiv | grep 2024
#     └── показує зміни offset (переходи на літній/зимовий час)

# Конвертація часу між поясами в bash
echo "Київ:    $(TZ='Europe/Kyiv'    date '+%H:%M')"
echo "Лондон:  $(TZ='Europe/London'  date '+%H:%M')"
echo "Нью-Йорк:$(TZ='America/New_York' date '+%H:%M')"
echo "Токіо:   $(TZ='Asia/Tokyo'     date '+%H:%M')"
```

---

### Завдання 4.3 — Налаштування NTP через systemd-timesyncd

```bash
# Статус вбудованого NTP-клієнта
systemctl status systemd-timesyncd
timedatectl timesync-status

# Переглянути поточну конфігурацію
cat /etc/systemd/timesyncd.conf

# Налаштувати українські NTP-сервери
sudo tee /etc/systemd/timesyncd.conf << 'EOF'
[Time]
# Основні сервери (Ukrainian NTP Pool)
NTP=0.ua.pool.ntp.org 1.ua.pool.ntp.org 2.ua.pool.ntp.org 3.ua.pool.ntp.org

# Резервні (глобальний пул + Ubuntu)
FallbackNTP=0.pool.ntp.org 1.pool.ntp.org ntp.ubuntu.com

# Максимально допустиме відхилення
RootDistanceMaxSec=5

# Інтервал запитів (32с мін → 2048с макс)
PollIntervalMinSec=32
PollIntervalMaxSec=2048
EOF

# Перезапустити та перевірити
sudo systemctl restart systemd-timesyncd
sleep 5
timedatectl timesync-status
# Зверніть увагу на рядок "Server:" і "Offset:"
```

---

### Завдання 4.4 — Встановлення chrony (для серверів)

```bash
# Встановити chrony
sudo apt install chrony -y

# При встановленні chrony — systemd-timesyncd зупиняється автоматично
# Перевіримо:
systemctl status systemd-timesyncd   # має бути inactive
systemctl status chronyd             # має бути active

# Переглянути конфігурацію
cat /etc/chrony/chrony.conf

# Налаштувати
sudo tee /etc/chrony/chrony.conf << 'EOF'
# Українські NTP-сервери з iburst (пришвидшений початковий синхронізм)
pool 0.ua.pool.ntp.org iburst maxsources 4
pool 1.ua.pool.ntp.org iburst maxsources 2

# Файл дрейфу (зберігає частоту відхилення годинника)
driftfile /var/lib/chrony/chrony.drift

# Синхронізувати RTC з системним часом
rtcsync

# Дозволити крокове виправлення при великому відхиленні
# (тільки перші 3 оновлення, потім тільки плавне коригування)
makestep 1.0 3

# Логування
logdir /var/log/chrony
log measurements statistics tracking
EOF

sudo systemctl restart chronyd

# Моніторинг синхронізації chrony
chronyc tracking            # поточний стан і відхилення
chronyc sources -v          # список NTP-серверів і якість з'єднання
chronyc sourcestats         # статистика по кожному серверу

# Форсувати синхронізацію негайно
sudo chronyc makestep
```

---

### Завдання 4.5 — Синхронізація апаратного годинника

```bash
# Переглянути апаратний час
sudo hwclock --show

# Порівняти: системний vs апаратний
echo "Системний час: $(date)"
echo "Апаратний час: $(sudo hwclock --show)"

# Записати системний час у RTC (після ручного встановлення або NTP-синхронізації)
sudo hwclock --systohc           # system → hardware clock
#              └── --systohc = --set --system

# Зчитати час із RTC і встановити системний (при проблемах з NTP)
sudo hwclock --hctosys           # hardware → system clock

# Переконатись, що RTC зберігає час у UTC (рекомендовано!)
sudo timedatectl set-local-rtc 0    # 0 = UTC, 1 = local time
timedatectl | grep "RTC in local TZ"
# "RTC in local TZ: no" = UTC (правильно)
```

---

### Завдання 4.6 — Практика з командою date у скриптах

```bash
# Створити скрипт що генерує звіт із часовими мітками
sudo tee /opt/dept21/scripts/time_report.sh << 'EOF'
#!/bin/bash
# time_report.sh — демонстрація роботи з часом у bash

REPORT="/opt/dept21/logs/time_report.log"
NOW=$(date '+%Y-%m-%d %H:%M:%S')        # поточний час
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')      # для імен файлів
UNIX=$(date '+%s')                       # Unix timestamp
WEEKDAY=$(date '+%A')                    # день тижня
WEEK=$(date '+%V')                       # номер тижня

echo "========================================" >> "$REPORT"
echo "Звіт сформовано: $NOW"              >> "$REPORT"
echo "Unix timestamp:  $UNIX"             >> "$REPORT"
echo "День тижня:      $WEEKDAY"          >> "$REPORT"
echo "Тиждень року:    $WEEK"             >> "$REPORT"
echo ""                                   >> "$REPORT"

# Відносні дати
echo "Учора: $(date -d 'yesterday' '+%Y-%m-%d')"        >> "$REPORT"
echo "Завтра: $(date -d 'tomorrow' '+%Y-%m-%d')"        >> "$REPORT"
echo "Через тиждень: $(date -d '+7 days' '+%Y-%m-%d')"  >> "$REPORT"
echo "Початок місяця: $(date -d 'first day of this month' '+%Y-%m-%d')" >> "$REPORT"
echo "========================================" >> "$REPORT"

cat "$REPORT"
EOF

sudo chmod +x /opt/dept21/scripts/time_report.sh
/opt/dept21/scripts/time_report.sh
```

---

### ✅ Контрольні запитання до Питання 4

1. Яка різниця між системним часом і апаратним (RTC) годинником?
2. Чому рекомендується зберігати RTC у UTC, а не у локальному часі?
3. Яка команда синхронізує системний час у RTC?
4. Як перевірити, чи активний NTP і з яким сервером синхронізується система?

---

## 📊 Підсумкові лабораторні завдання

### Обов'язкові (виконати всі)

**Завдання A.** Структура кафедри:
- [ ] Створено 4 групи: `dept21`, `instructors`, `cadets`, `sysadmins`
- [ ] Створено мінімум 5 користувачів з правильними групами та паролями
- [ ] Створено ієрархію `/opt/dept21/` з правильними правами (SGID, sticky)
- [ ] Перевірено: `ls -la /opt/dept21/` показує правильні права

**Завдання Б.** Планування:
- [ ] Crontab містить щонайменше 2 записи (один із `*/N` кроком)
- [ ] Скрипт `disk_alert.sh` створено, виконуваний, додано до crontab
- [ ] `systemd timer` `dept21-monitor` активний (`systemctl list-timers`)
- [ ] Є хоча б одне завдання в черзі `at` (`atq`)

**Завдання В.** Локалізація:
- [ ] Locale `uk_UA.UTF-8` встановлено (`locale -a | grep uk`)
- [ ] Системний locale виставлено (`localectl status`)
- [ ] Розкладка клавіатури виставлена (`localectl status` → VC Keymap: ua)

**Завдання Г.** Системний час:
- [ ] Часовий пояс `Europe/Kyiv` встановлено
- [ ] NTP активний і синхронізований (`timedatectl | grep synchronized`)
- [ ] Налаштовані українські NTP-сервери у конфігурації
- [ ] `hwclock --systohc` виконано (RTC синхронізований)

---

### Додаткові (за бажанням ⭐)

1. Налаштувати chrony як NTP-клієнт замість systemd-timesyncd
2. Написати cron-завдання, що надсилає alert якщо диск заповнений >80%
3. Налаштувати `logrotate` для файлів у `/opt/dept21/logs/`
4. Написати bash-скрипт, що виводить список користувачів, які не входили >30 днів

---

## 🗂️ Структура файлів після заняття

```
/opt/dept21/
├── shared/          (2775 root:dept21)   ← спільний для всіх
├── instructors/     (2770 root:instructors) ← тільки викладачі
├── cadets/          (2750 root:cadets)   ← курсанти читають
├── scripts/
│   ├── disk_alert.sh
│   └── time_report.sh
└── logs/            (1777 root:root)     ← sticky bit
    ├── disk_alert.log
    ├── monitor.log
    └── time_report.log

/etc/systemd/system/
├── dept21-monitor.service
└── dept21-monitor.timer

/etc/sudoers.d/
├── sysadmin21
└── instructors

/etc/chrony/chrony.conf     (або /etc/systemd/timesyncd.conf)
```

---

## 🔗 Корисні посилання

- [crontab.guru](https://crontab.guru/) — онлайн-інтерпретатор cron-виразів
- [Ubuntu — Time Synchronization](https://ubuntu.com/server/docs/network-ntp)
- [systemd.timer manual](https://www.freedesktop.org/software/systemd/man/systemd.timer.html)
- [NTP Pool Project — Ukraine](https://www.ntppool.org/zone/ua)
- [chrony docs](https://chrony-project.org/documentation.html)

---

## Самоперевірка

```bash
# Запустити інтерактивний скрипт самоперевірки
bash check_m5l2.sh
```

---

*Змістовний модуль 5, Заняття 2 (Практичне) | Ubuntu Server 24.04.4 LTS | Кафедра 21, ВІТІ*
