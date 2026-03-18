#!/bin/bash
# ============================================================
#  check_m5l2.sh — Інтерактивний скрипт самоперевірки
#  Змістовний модуль 5, Заняття 2 (Практичне)
#  Тема: Користувачі, групи, планування, локалізація, час
# ============================================================

# ─── Кольори ────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m';  YELLOW='\033[1;33m'
BLUE='\033[0;34m';   CYAN='\033[0;36m';   MAGENTA='\033[0;35m'
BOLD='\033[1m';      DIM='\033[2m';        NC='\033[0m'
UNDERLINE='\033[4m'

# ─── Конфігурація ───────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"
LOG_FILE="/tmp/check_m5l2_$(date +%Y%m%d_%H%M%S).log"

# ─── Лічильники ─────────────────────────────────────────────
SCORE=0; MAX_SCORE=0; WRONG=0
SEC_SCORE=0; SEC_MAX=0
CADET_NAME=""; CADET_GROUP=""

# ════════════════════════════════════════════════════════════
#  ВСТУП
# ════════════════════════════════════════════════════════════

intro() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  🐧  М5З2 — Адміністрування Linux | Самоперевірка          ║"
    echo "║      Користувачі · Планування · Локалізація · Час           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  Скрипт перевіряє знання з чотирьох тем практичного заняття."
    echo -e "  ${DIM}Для живих перевірок системи введіть команду і натисніть Enter.${NC}"
    echo -e "  ${DIM}Для пропуску практичного завдання введіть: s${NC}"
    echo ""

    echo -ne "  ${BOLD}Ваше прізвище та ім'я:${NC} "
    read -r CADET_NAME
    [[ -z "$CADET_NAME" ]] && CADET_NAME="Курсант"

    echo -ne "  ${BOLD}Навчальна група:${NC} "
    read -r CADET_GROUP
    [[ -z "$CADET_GROUP" ]] && CADET_GROUP="—"

    # Ініціалізувати лог
    mkdir -p "$RESULTS_DIR"
    {
        echo "═══════════════════════════════════════"
        echo "Курсант:   $CADET_NAME"
        echo "Група:     $CADET_GROUP"
        echo "Початок:   $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Хост:      $(hostname)"
        echo "ОС:        $(lsb_release -d 2>/dev/null | cut -f2 || uname -sr)"
        echo "═══════════════════════════════════════"
    } >> "$LOG_FILE"

    echo ""
    echo -e "  ${GREEN}Вітаємо, ${BOLD}$CADET_NAME${NC}${GREEN}! Починаємо тестування.${NC}"
    sleep 1
}

# ════════════════════════════════════════════════════════════
#  ДОПОМІЖНІ ФУНКЦІЇ (UI)
# ════════════════════════════════════════════════════════════

print_header() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  🐧  М5З2 — Адміністрування Linux | Самоперевірка          ║"
    printf "║  %-60s║\n" "  $CADET_NAME | гр. $CADET_GROUP"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo ""
    echo -e "${CYAN}${BOLD}┌──────────────────────────────────────────────────────────────┐${NC}"
    printf "${CYAN}${BOLD}│  📌 %-58s│${NC}\n" "$1"
    echo -e "${CYAN}${BOLD}└──────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

correct() {
    echo -e "  ${GREEN}${BOLD}✅  Правильно!${NC}${DIM}  $1${NC}"
    ((SCORE++)); ((SEC_SCORE++)); ((MAX_SCORE++)); ((SEC_MAX++))
    echo "[OK] $2" >> "$LOG_FILE"
    sleep 0.3
}

wrong() {
    echo -e "  ${RED}${BOLD}❌  Неправильно.${NC}"
    echo -e "  ${YELLOW}💡  Правильна відповідь: ${BOLD}$1${NC}"
    [[ -n "$2" ]] && echo -e "  ${DIM}$2${NC}"
    ((WRONG++)); ((MAX_SCORE++)); ((SEC_MAX++))
    echo "[WRONG] Expected: $1" >> "$LOG_FILE"
    sleep 0.8
}

hint() { echo -e "  ${MAGENTA}${DIM}💭 Підказка: $1${NC}"; }

section_result() {
    echo ""
    echo -e "  ${DIM}────────────────────────────────────────────${NC}"
    local pct=0
    [[ $SEC_MAX -gt 0 ]] && pct=$((SEC_SCORE * 100 / SEC_MAX))
    if   [[ $pct -ge 80 ]]; then echo -e "  ${GREEN}${BOLD}Результат розділу: $SEC_SCORE/$SEC_MAX ($pct%) ✨${NC}"
    elif [[ $pct -ge 50 ]]; then echo -e "  ${YELLOW}${BOLD}Результат розділу: $SEC_SCORE/$SEC_MAX ($pct%) 📚${NC}"
    else                         echo -e "  ${RED}${BOLD}Результат розділу: $SEC_SCORE/$SEC_MAX ($pct%) — Повторіть матеріал!${NC}"
    fi
    SEC_SCORE=0; SEC_MAX=0
    echo ""
    echo -ne "  ${DIM}Натисніть Enter для продовження...${NC}"
    read -r
}

progress_bar() {
    local cur=$1 tot=$2 w=45
    local fill=$((cur * w / tot)) empty=$((w - fill))
    echo -ne "  ["
    printf "%${fill}s"  | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    echo -ne "] ${BOLD}$cur/$tot${NC}"
}

# Питання одиночного вибору
ask_choice() {
    # $1=питання  $2=варіанти(|)  $3=правильна_літера  $4=пояснення
    echo -e "\n  ${BOLD}❓ $1${NC}\n"
    IFS='|' read -ra OPTS <<< "$2"
    local LETS=("a" "b" "c" "d" "e")
    for i in "${!OPTS[@]}"; do
        echo -e "    ${BOLD}${LETS[$i]})${NC} ${OPTS[$i]}"
    done
    echo ""
    echo -ne "  ${YELLOW}▶ Ваш вибір [${LETS[0]}-${LETS[$((${#OPTS[@]}-1))]}]: ${NC}"
    read -r ans
    local ans_l correct_l
    ans_l=$(echo "$ans" | tr '[:upper:]' '[:lower:]' | xargs)
    correct_l=$(echo "$3" | tr '[:upper:]' '[:lower:]')
    if [[ "$ans_l" == "$correct_l" ]]; then
        correct "$4" "$1"
    else
        local ci=$(echo "$correct_l" | tr 'a-e' '0-4')
        wrong "$3) ${OPTS[$ci]}" "$4"
    fi
}

# Питання з відкритою відповіддю (regex match)
ask_open() {
    # $1=питання  $2=regex  $3=пояснення  $4=підказка
    echo -e "\n  ${BOLD}❓ $1${NC}"
    [[ -n "$4" ]] && hint "$4"
    echo -ne "  ${YELLOW}▶ Відповідь: ${NC}"
    read -r ans
    local ans_l
    ans_l=$(echo "$ans" | tr '[:upper:]' '[:lower:]' | xargs)
    if echo "$ans_l" | grep -qiE "$2"; then
        correct "$3" "$1"
    else
        wrong "$2" "$3"
    fi
}

# Перевірка реального стану системи
ask_live() {
    # $1=опис  $2=інструкція  $3=команда_перевірки  $4=пояснення
    echo -e "\n  ${BOLD}🔍 ПЕРЕВІРКА СИСТЕМИ: $1${NC}"
    echo -e "  ${DIM}$2${NC}"
    echo ""
    echo -ne "  ${YELLOW}▶ Натисніть Enter після виконання (або 's' — пропустити): ${NC}"
    read -r skip
    if [[ "$skip" =~ ^[sS]$ ]]; then
        echo -e "  ${DIM}⏭  Пропущено${NC}"
        return 2
    fi
    if eval "$3" &>/dev/null 2>&1; then
        correct "$4" "$1"
        echo -e "  ${GREEN}${DIM}  Перевірка системи: ✅ пройдена${NC}"
    else
        echo -e "  ${RED}  Перевірка системи: ❌ не пройдена${NC}"
        echo -e "  ${YELLOW}  Порада: $4${NC}"
        ((WRONG++)); ((MAX_SCORE++)); ((SEC_MAX++))
    fi
}

# Практичне завдання з виконанням команди
ask_command() {
    # $1=питання  $2=підказка
    echo -e "\n  ${BOLD}⌨️  КОМАНДА: $1${NC}"
    [[ -n "$2" ]] && hint "$2"
    echo -ne "  ${YELLOW}▶ Введіть команду: ${NC}"
    read -r cmd
    if [[ -z "$cmd" ]]; then
        echo -e "  ${DIM}Команду не введено${NC}"
        return
    fi
    echo -e "  ${DIM}Виконую: $cmd${NC}"
    echo ""
    if eval "$cmd" 2>&1; then
        echo ""
        echo -e "  ${GREEN}✅ Команда виконана${NC}"
        ((SCORE++)); ((SEC_SCORE++)); ((MAX_SCORE++)); ((SEC_MAX++))
        echo "[CMD] $cmd" >> "$LOG_FILE"
    else
        echo -e "  ${RED}❌ Помилка виконання команди${NC}"
        ((WRONG++)); ((MAX_SCORE++)); ((SEC_MAX++))
    fi
}

# ════════════════════════════════════════════════════════════
#  РОЗДІЛ 1: КОРИСТУВАЧІ ТА ГРУПИ
# ════════════════════════════════════════════════════════════

section_users() {
    print_header
    print_section "РОЗДІЛ 1: Користувачі та групи"

    # 1.1 Теорія
    ask_choice \
        "Яка опція useradd створює домашній каталог для нового користувача?" \
        "-d|--home-dir|−m (--create-home)|−r (--system)" \
        "c" \
        "Опція -m або --create-home автоматично створює /home/username і копіює туди /etc/skel"

    ask_choice \
        "Що робить команда: sudo usermod -aG docker taras" \
        "Замінює всі групи taras на docker|Додає taras до групи docker (зберігаючи поточні)|Видаляє taras з групи docker|Встановлює docker як основну групу" \
        "b" \
        "-aG = --append --groups. Без -a: -G ЗАМІНИТЬ усі групи! Типова помилка — забути -a."

    ask_open \
        "Яка команда показує UID, GID та всі групи поточного користувача?" \
        "^id$" \
        "Команда 'id' без аргументів виводить uid, gid і всі групи. З аргументом: id username" \
        "Двохлітерна команда"

    ask_choice \
        "Яке спеціальне право потрібно встановити на спільний каталог, щоб нові файли успадковували групу каталогу?" \
        "Sticky bit (chmod +t)|SUID (chmod u+s)|SGID (chmod g+s)|execute для всіх" \
        "c" \
        "SGID (Set Group ID) на каталозі: chmod g+s або chmod 2XXX. Новий файл матиме групу каталогу, а не групу творця."

    ask_open \
        "Яка команда безпечно редагує /etc/sudoers з перевіркою синтаксису?" \
        "visudo|sudo visudo" \
        "visudo перевіряє синтаксис перед збереженням. Пряме редагування nano/vi може зробити систему непрацездатною!" \
        "v-i-s-u-d-o"

    # 1.2 Перевірки системи
    ask_live \
        "Група 'cadets' існує у системі" \
        "Виконайте: sudo groupadd cadets (якщо ще не створено)" \
        "getent group cadets" \
        "getent group cadets — перевіряє наявність групи у /etc/group (та LDAP якщо налаштовано)"

    ask_live \
        "Існує хоча б один користувач з групою 'cadets'" \
        "Перевірте: getent group cadets | grep -E ':[^:]*$'" \
        "getent group cadets | grep -qE ':[^:]+$'" \
        "getent group cadets виводить: cadets:x:GID:член1,член2,..."

    ask_live \
        "Каталог /opt/dept21 існує" \
        "Виконайте: sudo mkdir -p /opt/dept21/{shared,instructors,cadets,scripts,logs}" \
        "[ -d /opt/dept21 ]" \
        "sudo mkdir -p /opt/dept21 — створює каталог і всі батьківські"

    ask_live \
        "Файл /etc/sudoers.d/sysadmin21 або sysadmins існує" \
        "Виконайте: echo 'sysadmin21 ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/sysadmin21 && sudo chmod 440 /etc/sudoers.d/sysadmin21" \
        "sudo ls /etc/sudoers.d/ | grep -qE 'sysadmin'" \
        "Файли у /etc/sudoers.d/ мають мати права 440 (rw-r-----)"

    # 1.3 Практична команда
    ask_command \
        "Виведіть список усіх користувачів і їх UID (з /etc/passwd, тільки реальні users UID>=1000)" \
        "awk -F: '\$3>=1000 && \$3<65534 {print \$1, \$3}' /etc/passwd"

    section_result
}

# ════════════════════════════════════════════════════════════
#  РОЗДІЛ 2: ПЛАНУВАННЯ ЗАВДАНЬ
# ════════════════════════════════════════════════════════════

section_cron() {
    print_header
    print_section "РОЗДІЛ 2: Планування завдань"

    # 2.1 Теорія cron
    ask_open \
        "Запишіть cron-вираз для запуску завдання щодня о 02:30:" \
        "30 2 \* \* \*|30 02 \* \* \*" \
        "Формат: хвилина(30) година(2) день(*) місяць(*) день_тижня(*)" \
        "хв год день міс дт_тижня"

    ask_open \
        "Запишіть cron-вираз: кожні 15 хвилин у робочий час пн–пт (09:00–17:00):" \
        "\*/15 9-17 \* \* 1-5|\*/15 09-17 \* \* 1-5" \
        "*/15 9-17 * * 1-5 : '/' = крок, '-' = діапазон годин, '1-5' = пн(1)–пт(5)" \
        "*/N для кроку, H1-H2 для діапазону, 1-5 для пн-пт"

    ask_choice \
        "Яка команда відкриває crontab поточного користувача для редагування?" \
        "crontab -e|crontab -l|crontab -r|cron -e" \
        "a" \
        "crontab -e (edit), -l (list), -r (remove/DELETE!). Ніколи не плутайте -e і -r!"

    ask_choice \
        "Яке призначення @ символа у crontab? Наприклад: @reboot /opt/startup.sh" \
        "Позначає коментар|Псевдонім для типових розкладів|Запуск від root|Виконати негайно" \
        "b" \
        "@reboot, @daily, @weekly, @monthly, @yearly, @hourly — зручні псевдоніми для типових розкладів."

    ask_choice \
        "Де знаходяться логи виконання cron у Ubuntu 24.04?" \
        "/var/log/cron.log|/var/log/syslog|У systemd journald (journalctl -u cron)|/etc/cron.log" \
        "c" \
        "journalctl -u cron — в Ubuntu 24.04 cron логується через systemd-journald. Старіші системи: /var/log/syslog"

    ask_choice \
        "Чим at відрізняється від cron?" \
        "at швидший за cron|at для одноразових завдань, cron для регулярних|at потребує root|at не підтримує bash" \
        "b" \
        "at — одноразове відкладене виконання. cron — регулярний розклад. systemd timer — сучасна альтернатива обом."

    # 2.2 Перевірки системи
    ask_live \
        "Служба cron (або cron.service) активна" \
        "Перевірте: systemctl status cron" \
        "systemctl is-active cron 2>/dev/null || systemctl is-active crond 2>/dev/null" \
        "systemctl enable --now cron — якщо не активна"

    ask_live \
        "У crontab поточного користувача є хоча б один запис" \
        "Виконайте: crontab -e і додайте хоча б один запис (наприклад disk_alert.sh)" \
        "crontab -l 2>/dev/null | grep -qvE '^#|^$'" \
        "crontab -l показує записи. Коментарі (рядки з #) не рахуються."

    ask_live \
        "Скрипт /opt/dept21/scripts/disk_alert.sh існує та є виконуваним" \
        "Перевірте наявність скрипта та права: ls -la /opt/dept21/scripts/" \
        "[ -x /opt/dept21/scripts/disk_alert.sh ]" \
        "chmod +x /opt/dept21/scripts/disk_alert.sh — додати право виконання"

    ask_live \
        "systemd timer dept21-monitor.timer активний" \
        "Виконайте: sudo systemctl enable --now dept21-monitor.timer" \
        "systemctl is-active dept21-monitor.timer 2>/dev/null" \
        "Попередньо створіть .service і .timer файли у /etc/systemd/system/"

    ask_live \
        "Є хоча б одне завдання у черзі at (atq)" \
        "Виконайте: at now + 5 minutes <<< 'echo test >> /tmp/at_test.log'" \
        "atq | grep -q ." \
        "atq виводить порожньо якщо черга пуста. Служба atd має бути активна."

    # 2.3 Практична команда
    ask_command \
        "Перегляньте всі активні systemd timer-и у системі" \
        "systemctl list-timers --all"

    section_result
}

# ════════════════════════════════════════════════════════════
#  РОЗДІЛ 3: ЛОКАЛІЗАЦІЯ
# ════════════════════════════════════════════════════════════

section_locale() {
    print_header
    print_section "РОЗДІЛ 3: Налаштування локалізації"

    # 3.1 Теорія
    ask_open \
        "Яка змінна є ОСНОВНОЮ для визначення мови та кодування у Linux?" \
        "^lang$|^lang=" \
        "LANG — базова змінна locale. Якщо LC_ALL задана, вона перевизначає всі інші, включно з LANG." \
        "Чотири літери, визначає мову і кодування"

    ask_choice \
        "Яка команда показує поточні налаштування locale та розкладки клавіатури?" \
        "locale|localectl|locale-gen|localectl status" \
        "d" \
        "localectl status — показує System Locale, VC Keymap, X11 Layout. localectl без status теж працює."

    ask_choice \
        "Яка команда генерує locale на основі /etc/locale.gen?" \
        "localectl set-locale|locale-gen|update-locale|dpkg-reconfigure" \
        "b" \
        "sudo locale-gen uk_UA.UTF-8 — генерує конкретний locale. Без аргументів — генерує всі розкоментовані у /etc/locale.gen"

    ask_open \
        "Яка команда конвертує файл з Windows-1251 у UTF-8?" \
        "iconv -f windows-1251 -t utf-8|iconv -f cp1251 -t utf-8" \
        "iconv -f windows-1251 -t utf-8 input.txt -o output.txt (-f=from, -t=to, -o=output)" \
        "Починається з 'iconv'"

    ask_choice \
        "Що відбудеться якщо встановити LC_ALL=C?" \
        "Система перейде на китайську|Всі LC_* змінні та LANG будуть замінені на POSIX/C (English ASCII)|Locale буде очищено|Система перестане відображати Unicode" \
        "b" \
        "LC_ALL перевизначає ВСЕ. LC_ALL=C: POSIX-сумісний режим, ASCII, англійська, відсортовані рядки 'правильно'. LANG=C — те саме, але без override LC_*"

    # 3.2 Перевірки системи
    ask_live \
        "Locale uk_UA.UTF-8 встановлено у системі" \
        "Виконайте: sudo locale-gen uk_UA.UTF-8" \
        "locale -a | grep -q 'uk_UA.utf8\|uk_UA.UTF-8'" \
        "locale -a виводить список. Формат може бути uk_UA.utf8 або uk_UA.UTF-8"

    ask_live \
        "Системний LANG встановлено (не порожній)" \
        "Виконайте: sudo localectl set-locale LANG=uk_UA.UTF-8" \
        "localectl | grep -q 'LANG='" \
        "localectl set-locale LANG=uk_UA.UTF-8 — встановлює /etc/locale.conf"

    ask_live \
        "Розкладка клавіатури VC Keymap встановлена (не порожня)" \
        "Виконайте: sudo localectl set-keymap ua" \
        "localectl | grep 'VC Keymap' | grep -qv 'n/a\|^$'" \
        "localectl set-keymap ua — встановлює розкладку консолі"

    # 3.3 Практичне
    ask_command \
        "Виведіть список встановлених locale що містять 'UTF'" \
        "locale -a | grep -i utf | head -10"

    section_result
}

# ════════════════════════════════════════════════════════════
#  РОЗДІЛ 4: СИСТЕМНИЙ ЧАС
# ════════════════════════════════════════════════════════════

section_time() {
    print_header
    print_section "РОЗДІЛ 4: Налаштування системного часу"

    # 4.1 Теорія
    ask_choice \
        "Яка команда є основним інструментом керування часом і часовим поясом у systemd-системах?" \
        "date|hwclock|timedatectl|ntpdate" \
        "c" \
        "timedatectl — основний інструмент. Показує локальний час, UTC, RTC, часовий пояс, статус NTP одночасно."

    ask_open \
        "Яка команда встановлює часовий пояс Київ?" \
        "timedatectl set-timezone europe/kyiv|sudo timedatectl set-timezone europe/kyiv" \
        "sudo timedatectl set-timezone Europe/Kyiv — назви чутливі до регістру! Europe/Kyiv (не Kiev, не Kyiv без Europe)" \
        "timedatectl set-timezone ..."

    ask_choice \
        "Яка різниця між системним годинником і апаратним (RTC)?" \
        "Різниці немає, це одне й те саме|Системний — у ядрі, синхронізується при завантаженні з RTC; RTC — апаратний, на батарейці|RTC точніший за системний|Системний зберігається у /etc/time" \
        "b" \
        "RTC (Real-Time Clock) = CMOS годинник, працює завжди. System Clock = програмний у ядрі, ініціалізується з RTC при boot, потім може синхронізуватися з NTP."

    ask_open \
        "Яка команда виводить поточну дату у форматі РРРР-ММ-ДД?" \
        "date \+%Y-%m-%d|date '\\+%Y-%m-%d'" \
        "date '+%Y-%m-%d' — специфікатори: %Y=рік, %m=місяць, %d=день. Результат: 2024-03-13" \
        "date '+формат'"

    ask_choice \
        "Яке NTP-рішення вбудоване в Ubuntu 24.04 за замовчуванням?" \
        "ntpd|chrony|systemd-timesyncd|openntpd" \
        "c" \
        "systemd-timesyncd — легкий NTP-клієнт, вбудований у systemd. Тільки клієнт (не сервер). Chrony — більш потужна альтернатива для серверів."

    ask_choice \
        "Яка команда синхронізує системний час у апаратний годинник (RTC)?" \
        "hwclock --hctosys|hwclock --systohc|timedatectl set-rtc|date --rtc" \
        "b" \
        "hwclock --systohc (system to hardware clock). --hctosys = навпаки (hardware to system). Запам'ятати: systohc = sys→hw"

    ask_open \
        "Яка команда показує список доступних часових поясів що містять 'Kyiv'?" \
        "timedatectl list-timezones.*kyiv|timedatectl list-timezones.*grep.*kyiv" \
        "timedatectl list-timezones | grep -i Kyiv" \
        "timedatectl list-timezones | grep ..."

    # 4.2 Перевірки системи
    ask_live \
        "Часовий пояс встановлено Europe/Kyiv" \
        "Виконайте: sudo timedatectl set-timezone Europe/Kyiv" \
        "timedatectl | grep -q 'Europe/Kyiv'" \
        "timedatectl set-timezone Europe/Kyiv — потребує sudo"

    ask_live \
        "NTP синхронізація активна" \
        "Перевірте: timedatectl | grep 'synchronized'" \
        "timedatectl | grep -q 'synchronized: yes'" \
        "sudo timedatectl set-ntp true — увімкнути NTP синхронізацію"

    ask_live \
        "Служба синхронізації часу активна (timesyncd або chronyd)" \
        "Перевірте: systemctl status systemd-timesyncd або chronyd" \
        "systemctl is-active systemd-timesyncd 2>/dev/null || systemctl is-active chronyd 2>/dev/null" \
        "sudo systemctl enable --now systemd-timesyncd"

    # 4.3 Практичне
    ask_command \
        "Виведіть поточний час у форматі: ДД.ММ.РРРР ГГ:ХХ:СС (Часовий пояс)" \
        "date '+%d.%m.%Y %H:%M:%S (%Z)'"

    section_result
}

# ════════════════════════════════════════════════════════════
#  РОЗДІЛ 5: КОМПЛЕКСНИЙ ПРАКТИЧНИЙ БЛОК
# ════════════════════════════════════════════════════════════

section_complex() {
    print_header
    print_section "РОЗДІЛ 5: Комплексний практичний блок"

    echo -e "  ${DIM}Цей розділ перевіряє комплексне розуміння теми.${NC}"
    echo -e "  ${DIM}Питання поєднують кілька тем одночасно.${NC}"
    echo ""

    # Комбіновані запитання
    ask_choice \
        "Адміністратор хоче щоб усі файли створені в /shared/ автоматично належали групі 'devops'. Що потрібно зробити?" \
        "chmod 777 /shared/|chown devops /shared/|chmod g+s /shared/ та chown :devops /shared/|chmod +t /shared/" \
        "c" \
        "SGID (g+s) на каталозі + chown :devops — нові файли успадкують групу devops. chmod 777 — небезпечно. Sticky bit (t) — захищає від видалення, не змінює групу."

    ask_choice \
        "Cron-завдання не виконується. Перший крок діагностики?" \
        "Перезапустити сервер|Видалити crontab і створити заново|journalctl -u cron --since '1 hour ago'|Перевстановити cron" \
        "c" \
        "journalctl -u cron показує всі спроби запуску і помилки. Типові причини: PATH у cron не містить потрібних утиліт, немає прав на скрипт, помилковий синтаксис."

    ask_open \
        "Яка команда показує деталі NTP-синхронізації при використанні chrony: сервер, offset, stratum?" \
        "chronyc tracking|chronyc sources" \
        "chronyc tracking — детально про синхронізацію. chronyc sources -v — список серверів." \
        "chronyc ..."

    ask_choice \
        "Потрібно запустити скрипт cleanup.sh рівно через 2 години. Який інструмент?" \
        "cron (*/120 * * * *)|at now + 2 hours|systemd timer з OnBootSec=2h|sleep 7200 && cleanup.sh" \
        "b" \
        "at now + 2 hours — саме для цього! cron — для регулярних завдань. sleep у background може загубитися при перезавантаженні."

    # Системні перевірки комплексу
    ask_live \
        "Структура /opt/dept21/ повністю створена (shared, instructors, cadets, scripts, logs)" \
        "Виконайте: sudo mkdir -p /opt/dept21/{shared,instructors,cadets,scripts,logs}" \
        "[ -d /opt/dept21/shared ] && [ -d /opt/dept21/scripts ] && [ -d /opt/dept21/logs ]" \
        "mkdir -p /opt/dept21/{shared,instructors,cadets,scripts,logs} — brace expansion створює всі каталоги"

    ask_live \
        "Файл results.log або будь-який .log існує в /opt/dept21/logs/" \
        "Запустіть будь-який скрипт що пише у /opt/dept21/logs/ або: touch /opt/dept21/logs/test.log" \
        "ls /opt/dept21/logs/*.log 2>/dev/null | grep -q ." \
        "touch /opt/dept21/logs/test.log — або запустіть disk_alert.sh"

    # Фінальне практичне
    echo ""
    echo -e "  ${BOLD}🔧 ФІНАЛЬНЕ ЗАВДАННЯ: Комплексна перевірка стану системи${NC}"
    echo -e "  ${DIM}Виконайте команди і відповідайте на запитання:${NC}"
    echo ""

    # Питання на основі реального стану
    local tz_actual
    tz_actual=$(timedatectl | grep "Time zone" | awk '{print $3}')
    echo -e "  ${DIM}1. Ваш поточний часовий пояс: ${BOLD}$tz_actual${NC}"
    echo -ne "  ${YELLOW}▶ Введіть назву поточного часового поясу (як показує timedatectl): ${NC}"
    read -r ans_tz
    if echo "$ans_tz" | grep -qiE "$(echo "$tz_actual" | tr '/' '.')"; then
        correct "Правильно! $tz_actual" "timezone check"
    else
        wrong "$tz_actual" "timedatectl | grep 'Time zone' → $tz_actual"
    fi

    local ntp_status
    ntp_status=$(timedatectl | grep "synchronized:" | awk '{print $NF}')
    echo ""
    echo -e "  ${DIM}2. Статус NTP-синхронізації: ${BOLD}$ntp_status${NC}"
    echo -ne "  ${YELLOW}▶ NTP синхронізований? [yes/no]: ${NC}"
    read -r ans_ntp
    if echo "$ans_ntp" | grep -qiE "^${ntp_status}$|^yes$|^no$"; then
        if [[ "$(echo "$ans_ntp" | tr '[:upper:]' '[:lower:]')" == "$ntp_status" ]]; then
            correct "Вірно! NTP: $ntp_status" "ntp status"
        else
            wrong "$ntp_status" "timedatectl | grep synchronized → $ntp_status"
        fi
    else
        wrong "$ntp_status" "Відповідайте 'yes' або 'no'"
    fi

    section_result
}

# ════════════════════════════════════════════════════════════
#  ЗБЕРЕЖЕННЯ РЕЗУЛЬТАТІВ
# ════════════════════════════════════════════════════════════

save_results() {
    mkdir -p "$RESULTS_DIR"
    local pct=0
    [[ $MAX_SCORE -gt 0 ]] && pct=$((SCORE * 100 / MAX_SCORE))

    local grade
    if   [[ $pct -ge 90 ]]; then grade="ВІДМІННО"
    elif [[ $pct -ge 75 ]]; then grade="ДОБРЕ"
    elif [[ $pct -ge 60 ]]; then grade="ЗАДОВІЛЬНО"
    else                         grade="НЕЗАДОВІЛЬНО"
    fi

    # ім'я файлу: транслітерація прізвища + мітка часу
    local safe_name
    safe_name=$(echo "$CADET_NAME" | tr ' ' '_' | tr -cd '[:alnum:]_-')
    local result_file="${RESULTS_DIR}/result_${safe_name}_$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "═══════════════════════════════════════════"
        echo "  РЕЗУЛЬТАТ ТЕСТУВАННЯ — М5З2"
        echo "═══════════════════════════════════════════"
        echo "  Курсант:   $CADET_NAME"
        echo "  Група:     $CADET_GROUP"
        echo "  Завершено: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "  Хост:      $(hostname)"
        echo "───────────────────────────────────────────"
        echo "  Правильно: $SCORE"
        echo "  Всього:    $MAX_SCORE"
        echo "  Результат: $pct%"
        echo "  Оцінка:    $grade"
        echo "═══════════════════════════════════════════"
    } | tee -a "$LOG_FILE" > "$result_file"

    echo "$result_file"
}

# ════════════════════════════════════════════════════════════
#  ФІНАЛЬНИЙ ЗВІТ
# ════════════════════════════════════════════════════════════

final_report() {
    clear
    print_header
    echo ""

    local pct=0
    [[ $MAX_SCORE -gt 0 ]] && pct=$((SCORE * 100 / MAX_SCORE))

    local grade emoji comment grade_color
    if   [[ $pct -ge 90 ]]; then grade="ВІДМІННО";      emoji="🏆"; grade_color="$GREEN";   comment="Блискучий результат! Матеріал засвоєно на відмінно."
    elif [[ $pct -ge 75 ]]; then grade="ДОБРЕ";         emoji="🎯"; grade_color="$CYAN";    comment="Гарна робота! Повторіть теми де були помилки."
    elif [[ $pct -ge 60 ]]; then grade="ЗАДОВІЛЬНО";    emoji="📚"; grade_color="$YELLOW";  comment="Задовільний результат. Рекомендується додаткове опрацювання."
    else                         grade="НЕЗАДОВІЛЬНО";  emoji="⚠️";  grade_color="$RED";     comment="Необхідне повторення матеріалу. Зверніться до викладача."
    fi

    echo -e "  ${BOLD}📊 ПІДСУМКОВИЙ ЗВІТ — Модуль 5, Заняття 2${NC}"
    echo ""
    echo -e "  ${BOLD}Курсант:${NC} $CADET_NAME | Група: $CADET_GROUP"
    echo -e "  ${BOLD}Дата:   ${NC} $(date '+%d.%m.%Y %H:%M:%S')"
    echo ""
    echo -ne "  Прогрес: "
    progress_bar "$SCORE" "$MAX_SCORE"
    echo ""
    echo ""

    # Результат
    echo -e "  ${BOLD}Правильних: ${GREEN}$SCORE${NC}  ${BOLD}Неправильних: ${RED}$WRONG${NC}  ${BOLD}Всього: $MAX_SCORE${NC}"
    echo ""
    echo -e "  $emoji  ${grade_color}${BOLD}${grade} — $pct%${NC}"
    echo -e "  ${DIM}$comment${NC}"
    echo ""

    # Шпаргалка для повторення
    echo -e "  ${DIM}──────────────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}📝 Ключові команди для повторення:${NC}"
    echo ""
    echo -e "  ${DIM}sudo useradd -m -s /bin/bash -g GROUP USER  — створити користувача"
    echo -e "  sudo usermod -aG GROUP USER                 — додати до групи (НЕ забудь -a!)"
    echo -e "  crontab -e / -l / -r                        — edit/list/remove crontab"
    echo -e "  systemctl list-timers --all                 — systemd таймери"
    echo -e "  sudo localectl set-locale LANG=uk_UA.UTF-8  — locale"
    echo -e "  sudo timedatectl set-timezone Europe/Kyiv   — часовий пояс"
    echo -e "  sudo timedatectl set-ntp true               — увімкнути NTP"
    echo -e "  sudo hwclock --systohc                      — зберегти час у RTC${NC}"
    echo ""

    # Зберегти файл результатів
    local saved
    saved=$(save_results)
    echo -e "  ${DIM}Результат збережено: $saved${NC}"
    echo -e "  ${DIM}Детальний лог:       $LOG_FILE${NC}"
    echo ""

    echo -ne "  ${YELLOW}▶ Пройти тест повторно? [y/N]: ${NC}"
    read -r rep
    if [[ "$rep" =~ ^[yYтТ] ]]; then
        SCORE=0; MAX_SCORE=0; WRONG=0; SEC_SCORE=0; SEC_MAX=0
        section_menu
    else
        echo ""
        echo -e "  ${GREEN}${BOLD}Дякуємо за роботу, $CADET_NAME!${NC}"
        echo -e "  ${DIM}Слава Україні! 🇺🇦${NC}"
        echo ""
    fi
}

# ════════════════════════════════════════════════════════════
#  МЕНЮ РОЗДІЛІВ
# ════════════════════════════════════════════════════════════

section_menu() {
    clear
    print_header
    echo ""
    echo -e "  ${BOLD}Оберіть режим тестування:${NC}"
    echo ""
    echo -e "  ${CYAN}1)${NC} 📋 Повне тестування (всі 5 розділів)"
    echo -e "  ${CYAN}2)${NC} 👥 Розділ 1: Користувачі та групи"
    echo -e "  ${CYAN}3)${NC} ⏰ Розділ 2: Планування завдань (cron/at/systemd)"
    echo -e "  ${CYAN}4)${NC} 🌐 Розділ 3: Локалізація"
    echo -e "  ${CYAN}5)${NC} 🕐 Розділ 4: Системний час"
    echo -e "  ${CYAN}6)${NC} 🔬 Розділ 5: Комплексний блок"
    echo -e "  ${CYAN}0)${NC} 🚪 Вийти"
    echo ""
    echo -ne "  ${YELLOW}▶ Ваш вибір [0-6]: ${NC}"
    read -r choice

    case "$choice" in
        1) section_users; section_cron; section_locale; section_time; section_complex; final_report ;;
        2) section_users;   final_report ;;
        3) section_cron;    final_report ;;
        4) section_locale;  final_report ;;
        5) section_time;    final_report ;;
        6) section_complex; final_report ;;
        0) echo -e "\n  ${DIM}До побачення!${NC}\n"; exit 0 ;;
        *) echo -e "  ${RED}Невірний вибір${NC}"; sleep 1; section_menu ;;
    esac
}

# ════════════════════════════════════════════════════════════
#  ЗАПУСК
# ════════════════════════════════════════════════════════════

main() {
    intro
    section_menu
}

main
