#!/bin/bash
# ============================================================
#  check_m5l6.sh — Інтерактивний скрипт самоперевірки
#  Змістовий модуль 5, Заняття 6 (Практичне)
#  Тема: Мережева конфігурація та діагностика
# ============================================================

# ─── Кольори ────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m';  YELLOW='\033[1;33m'
BLUE='\033[0;34m';   CYAN='\033[0;36m';   MAGENTA='\033[0;35m'
BOLD='\033[1m';      DIM='\033[2m';        NC='\033[0m'

# ─── Конфігурація ───────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"
LOG_FILE="/tmp/check_m5l6_$(date +%Y%m%d_%H%M%S).log"

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
    echo "║  🌐  М5З6 — Мережева конфігурація та діагностика           ║"
    echo "║      Самоперевірка знань | Кафедра 21, ВІТІ                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  Скрипт перевіряє знання з двох тем:"
    echo -e "  ${BOLD}1.${NC} Мережеві налаштування Linux"
    echo -e "  ${BOLD}2.${NC} Сканування та діагностика мережі"
    echo ""
    echo -e "  ${DIM}Для пропуску практичного завдання введіть: s${NC}"
    echo ""

    echo -ne "  ${BOLD}Ваше прізвище та ім'я:${NC} "
    read -r CADET_NAME
    [[ -z "$CADET_NAME" ]] && CADET_NAME="Курсант"

    echo -ne "  ${BOLD}Навчальна група:${NC} "
    read -r CADET_GROUP
    [[ -z "$CADET_GROUP" ]] && CADET_GROUP="—"

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
    echo "║  🌐  М5З6 — Мережева конфігурація та діагностика           ║"
    printf "║  %-60s║\n" "  $CADET_NAME | гр. $CADET_GROUP"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  📌 $1${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    SEC_SCORE=0; SEC_MAX=0
}

section_summary() {
    echo ""
    echo -e "  ${DIM}Результат розділу: ${SEC_SCORE}/${SEC_MAX}${NC}"
    sleep 0.5
}

correct() {
    echo -e "  ${GREEN}${BOLD}✅  Правильно!${NC} ${DIM}$1${NC}"
    ((SCORE++)); ((SEC_SCORE++)); ((MAX_SCORE++)); ((SEC_MAX++))
    echo "[CORRECT] $2" >> "$LOG_FILE"
    sleep 0.4
}

wrong() {
    echo -e "  ${RED}${BOLD}❌  Неправильно.${NC}"
    echo -e "  ${YELLOW}💡  Правильна відповідь: ${BOLD}$1${NC}"
    [ -n "$2" ] && echo -e "  ${DIM}$2${NC}"
    ((WRONG++)); ((MAX_SCORE++)); ((SEC_MAX++))
    echo "[WRONG] Correct: $1" >> "$LOG_FILE"
    sleep 0.8
}

hint() {
    echo -e "  ${MAGENTA}${DIM}💭 Підказка: $1${NC}"
}

ask_question() {
    # $1 — питання, $2 — regex відповіді, $3 — пояснення, $4 — підказка (опц.)
    echo -e "\n  ${BOLD}❓ $1${NC}"
    [ -n "$4" ] && hint "$4"
    echo -ne "  ${YELLOW}▶ Ваша відповідь: ${NC}"
    read -r USER_ANSWER
    local ANSWER_LOWER
    ANSWER_LOWER=$(echo "$USER_ANSWER" | tr '[:upper:]' '[:lower:]' | xargs)
    if echo "$ANSWER_LOWER" | grep -qiE "$2"; then
        correct "$3" "$1"
    else
        wrong "$2" "$3"
    fi
}

ask_mc() {
    # $1 — питання, $2 — варіанти, $3 — правильний, $4 — пояснення
    echo -e "\n  ${BOLD}❓ $1${NC}"
    echo -e "$2"
    echo -ne "  ${YELLOW}▶ Ваш вибір: ${NC}"
    read -r USER_ANSWER
    local ANSWER_LOWER
    ANSWER_LOWER=$(echo "$USER_ANSWER" | tr '[:upper:]' '[:lower:]' | xargs)
    if [[ "$ANSWER_LOWER" == "$3" ]]; then
        correct "$4" "$1"
    else
        wrong "$3" "$4"
    fi
}

# ════════════════════════════════════════════════════════════
#  РОЗДІЛ 1: МЕРЕЖЕВІ ІНТЕРФЕЙСИ ТА КОМАНДА IP
# ════════════════════════════════════════════════════════════

section_interfaces() {
    print_header
    print_section "РОЗДІЛ 1: Мережеві інтерфейси та команда ip"

    ask_question \
        "Яка команда показує всі мережеві інтерфейси з IP-адресами?" \
        "^ip a$|^ip addr$|ip address show|ip -a|ip addr show" \
        '"ip a" або "ip address show" — виводить усі інтерфейси з адресами IPv4 та IPv6.' \
        "Скорочення від ip address"

    ask_mc \
        "Що означає позначка 'dynamic' у виводі 'ip a' поряд з IP-адресою?" \
        "  a) Адреса постійна і не зміниться\n  b) Адреса отримана по DHCP і може змінитись\n  c) Адреса призначена вручну через ip address add\n  d) Адреса IPv6 link-local" \
        "b" \
        '"dynamic" — адреса призначена DHCP-сервером і має обмежений термін дії (valid_lft). Після закінчення буде оновлена або змінена.'

    ask_question \
        "Якою командою можна ТИМЧАСОВО додати IP-адресу 10.0.0.1/24 до інтерфейсу eth0?" \
        "ip address add 10\.0\.0\.1/24 dev eth0|ip addr add" \
        '"sudo ip address add 10.0.0.1/24 dev eth0" — зміна тимчасова, зникне після перезавантаження.' \
        "ip address add <адреса/маска> dev <інтерфейс>"

    ask_mc \
        "Де в Ubuntu зберігаються файли постійної конфігурації мережі (Netplan)?" \
        "  a) /etc/network/interfaces\n  b) /etc/sysconfig/network\n  c) /etc/netplan/\n  d) /etc/NetworkManager/system-connections/" \
        "c" \
        '/etc/netplan/ — директорія з YAML-файлами конфігурації Netplan. Зміни тут є постійними.'

    ask_question \
        "Яка команда Netplan застосовує конфігурацію З МОЖЛИВІСТЮ АВТОМАТИЧНОГО ВІДКАТУ?" \
        "netplan try" \
        '"sudo netplan try" — застосовує конфігурацію і чекає підтвердження. Якщо не підтвердити протягом 120 с — автоматично повертає попередню конфігурацію. Безпечно при роботі по SSH.'

    ask_question \
        "Яка команда показує таблицю маршрутизації?" \
        "ip r|ip route|ip route show" \
        '"ip route" або "ip r" — показує таблицю маршрутизації: connected routes та шлюз за замовчуванням.'

    ask_question \
        "Як перевірити поточні DNS-сервери у системі з systemd-resolved?" \
        "resolvectl status|resolvectl|cat /etc/resolv.conf|resolvectl query" \
        '"resolvectl status" — показує поточні DNS-сервери по інтерфейсах. Також: cat /etc/resolv.conf.' \
        "Інструмент systemd для DNS"

    section_summary
}

# ════════════════════════════════════════════════════════════
#  РОЗДІЛ 2: NETPLAN ТА СТАТИЧНА АДРЕСАЦІЯ
# ════════════════════════════════════════════════════════════

section_netplan() {
    print_header
    print_section "РОЗДІЛ 2: Netplan та статична адресація"

    ask_mc \
        "У файлі Netplan вказано: addresses: [192.168.1.10/24]. Що означає /24?" \
        "  a) Кількість хостів у мережі — 24\n  b) Маска підмережі 255.255.255.0 (перші 24 біти — мережа)\n  c) Максимальна швидкість 24 Мбіт/с\n  d) Ідентифікатор VLAN" \
        "b" \
        '/24 — CIDR-нотація маски підмережі. Означає 255.255.255.0: перші 24 біти адреси — номер мережі, останні 8 — номер хоста. Необхідна ядру для побудови локального маршруту.'

    ask_question \
        "Яка команда перевіряє синтаксис Netplan БЕЗ застосування змін?" \
        "netplan generate|sudo netplan generate" \
        '"sudo netplan generate" — перевіряє синтаксис і генерує конфігурацію для бекенду без її застосування.'

    ask_mc \
        "Які права повинен мати файл /etc/netplan/*.yaml?" \
        "  a) 644 (читання для всіх)\n  b) 755 (виконання для всіх)\n  c) 600 (читання/запис тільки root)\n  d) 777 (всі права для всіх)" \
        "c" \
        '600 — файл Netplan повинен бути доступний тільки root (rw-------). Більш широкі права призведуть до попередження і відмови застосування.'

    ask_mc \
        "В якому полі Netplan вказується шлюз за замовчуванням?" \
        "  a) gateway4: 192.168.1.1\n  b) routes: [{to: default, via: 192.168.1.1}]\n  c) default-route: 192.168.1.1\n  d) gw: 192.168.1.1" \
        "b" \
        'routes: [{to: default, via: 192.168.1.1}] — сучасний спосіб вказати шлюз у Netplan. Поле gateway4 застаріло.'

    ask_question \
        "Яка команда змінює hostname системи ПОСТІЙНО (зберігається після перезавантаження)?" \
        "hostnamectl set-hostname|hostnamectl" \
        '"sudo hostnamectl set-hostname <ім'\''я>" — встановлює hostname постійно через systemd. Застаріла альтернатива: редагування /etc/hostname.' \
        "Команда з hostnamectl"

    section_summary
}

# ════════════════════════════════════════════════════════════
#  РОЗДІЛ 3: ДІАГНОСТИКА З'ЄДНАННЯ
# ════════════════════════════════════════════════════════════

section_diagnostics() {
    print_header
    print_section "РОЗДІЛ 3: Діагностика мережевого з'єднання"

    ask_question \
        "Яка команда відправляє рівно 4 ICMP-пакети до хоста 192.168.1.1?" \
        "ping -c 4 192\.168\.1\.1|ping -c4" \
        '"ping -c 4 192.168.1.1" — прапор -c задає кількість пакетів. Без -c ping працює нескінченно.'

    ask_mc \
        "Що показує команда 'traceroute 8.8.8.8'?" \
        "  a) Відкриті порти на хості 8.8.8.8\n  b) Кожен маршрутизатор (хоп) на шляху до 8.8.8.8 з затримками\n  c) MAC-адресу хоста 8.8.8.8\n  d) Версію ОС на 8.8.8.8" \
        "b" \
        'traceroute — виводить кожен проміжний маршрутизатор (хоп) на шляху до цілі та RTT для кожного. Зірочки (*) означають, що хоп не відповідає.'

    ask_question \
        "Якою командою перевірити доступність TCP-порту 22 на хості 10.0.0.1 БЕЗ встановлення з'єднання?" \
        "nc -zv 10\.0\.0\.1 22|nc -z|nmap.*-p 22|nmap -p22" \
        '"nc -zv 10.0.0.1 22" — nc (netcat) з прапором -z лише перевіряє порт без передачі даних. -v — детальний вивід.'

    ask_mc \
        "Яка команда показує всі TCP-порти у стані LISTEN із зазначенням процесу?" \
        "  a) netstat -a\n  b) ss -tlnp\n  c) ip port list\n  d) lsof -i" \
        "b" \
        '"ss -tlnp" — t:TCP, l:LISTEN, n:числові адреси (без DNS), p:процес. Замінює застарілий netstat.'

    ask_question \
        "Яка команда захоплює пакети на інтерфейсі eth0, фільтруючи тільки ICMP-трафік?" \
        "tcpdump -i eth0.*icmp|tcpdump.*icmp.*eth0|tcpdump -i eth0 icmp" \
        '"sudo tcpdump -i eth0 icmp" — захоплення ICMP на eth0. Ctrl+C зупиняє. Додайте -n щоб не резолвити імена.'

    ask_mc \
        "Чому пінг 8.8.8.8 може працювати, а 'ping google.com' — ні?" \
        "  a) google.com знаходиться за firewall\n  b) DNS не налаштований або не працює\n  c) ICMP заблокований для доменних імен\n  d) google.com не підтримує IPv4" \
        "b" \
        'Якщо IP досяжний, але ім'\''я не резолвиться — проблема в DNS. Перевірте: resolvectl status, cat /etc/resolv.conf, dig google.com.'

    section_summary
}

# ════════════════════════════════════════════════════════════
#  РОЗДІЛ 4: NMAP ТА СКАНУВАННЯ
# ════════════════════════════════════════════════════════════

section_nmap() {
    print_header
    print_section "РОЗДІЛ 4: nmap — сканування мережі"

    ask_question \
        "Яка команда nmap сканує ТІЛЬКИ відкриті порти хоста 10.0.0.1 (базове TCP-сканування)?" \
        "nmap 10\.0\.0\.1|nmap -sT|nmap -sS" \
        '"nmap 10.0.0.1" — базове TCP-сканування найпоширеніших 1000 портів. Для всіх портів: nmap -p- 10.0.0.1'

    ask_mc \
        "Який прапор nmap дозволяє визначити версії сервісів на відкритих портах?" \
        "  a) -O\n  b) -sV\n  c) -sn\n  d) -A" \
        "b" \
        '"-sV" — service version detection. -O — визначення ОС. -sn — лише ping scan (без портів). -A — агресивний режим (ОС + версії + скрипти).'

    ask_question \
        "Яка команда nmap виконує лише виявлення хостів у мережі 192.168.1.0/24 БЕЗ сканування портів?" \
        "nmap -sn 192\.168\.|nmap -sP|nmap.*ping.*scan" \
        '"nmap -sn 192.168.1.0/24" — ping scan: визначає які хости активні, не сканує порти. Швидко і ненав'\''язливо.' \
        "Прапор -sn (no port scan)"

    ask_mc \
        "Чому деякі хости можуть не відповідати на ping-scan nmap, навіть якщо вони увімкнені?" \
        "  a) nmap містить помилку\n  b) Брандмауер (firewall) блокує ICMP-пакети на цих хостах\n  c) Хости з Windows не підтримують ICMP\n  d) Ping-scan працює тільки в мережах /24" \
        "b" \
        'Firewall може блокувати ICMP. nmap -sn надсилає також TCP SYN на порт 443 і ACK на порт 80 — але якщо все заблоковано, хост виглядає як недоступний.'

    ask_question \
        "У якому файлі системного журналу SSH фіксує успішні та невдалі спроби входу?" \
        "journalctl|auth.log|/var/log/auth|journalctl -u ssh" \
        '"journalctl -u ssh" — журнал служби SSH. Або /var/log/auth.log. Шукати: "Accepted", "Failed password", "Invalid user".' \
        "journalctl або /var/log/..."

    section_summary
}

# ════════════════════════════════════════════════════════════
#  РОЗДІЛ 5: ПРАКТИЧНА ПЕРЕВІРКА
# ════════════════════════════════════════════════════════════

section_practical() {
    print_header
    print_section "РОЗДІЛ 5: Практична перевірка"

    echo -e "  ${DIM}Перевірка реального стану системи. Введіть 's' для пропуску.${NC}"

    # Завдання 1: hostname
    echo -e "\n  ${BOLD}🔧 Завдання 1. Hostname${NC}"
    echo -e "  Встановіть hostname цієї машини на 'server' або 'client' (залежно від VM)."
    echo -e "  Команда: ${CYAN}sudo hostnamectl set-hostname server${NC}"
    echo -ne "  ${YELLOW}▶ Натисніть Enter після виконання (або 's' для пропуску): ${NC}"
    read -r SKIP
    if [[ "$SKIP" != "s" && "$SKIP" != "S" ]]; then
        CURRENT_HOSTNAME=$(hostname)
        if [[ "$CURRENT_HOSTNAME" == "server" || "$CURRENT_HOSTNAME" == "client" ]]; then
            correct "Hostname встановлено: $CURRENT_HOSTNAME" "Практичне 1"
        else
            wrong "server або client" "Поточний hostname: $CURRENT_HOSTNAME. Виконайте: sudo hostnamectl set-hostname server"
        fi
    fi

    # Завдання 2: SSH-сервер
    echo -e "\n  ${BOLD}🔧 Завдання 2. SSH-сервер${NC}"
    echo -e "  Встановіть та запустіть openssh-server."
    echo -ne "  ${YELLOW}▶ Натисніть Enter після виконання (або 's' для пропуску): ${NC}"
    read -r SKIP
    if [[ "$SKIP" != "s" && "$SKIP" != "S" ]]; then
        if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
            correct "SSH-сервер запущений." "Практичне 2"
        else
            wrong "sudo systemctl start ssh" "SSH-сервер не запущений. Виконайте: sudo apt install openssh-server && sudo systemctl start ssh"
        fi
    fi

    # Завдання 3: порт 22
    echo -e "\n  ${BOLD}🔧 Завдання 3. Перевірка порту 22${NC}"
    echo -e "  Переконайтесь, що порт 22 прослуховується (LISTEN)."
    echo -ne "  ${YELLOW}▶ Натисніть Enter після виконання (або 's' для пропуску): ${NC}"
    read -r SKIP
    if [[ "$SKIP" != "s" && "$SKIP" != "S" ]]; then
        if ss -tlnp 2>/dev/null | grep -q ':22'; then
            correct "Порт 22 у стані LISTEN." "Практичне 3"
        else
            wrong "ss -tlnp | grep :22" "Порт 22 не прослуховується. Перевірте стан SSH: sudo systemctl status ssh"
        fi
    fi

    # Завдання 4: nmap
    echo -e "\n  ${BOLD}🔧 Завдання 4. nmap встановлено?${NC}"
    echo -e "  Встановіть nmap: ${CYAN}sudo apt install -y nmap${NC}"
    echo -ne "  ${YELLOW}▶ Натисніть Enter після виконання (або 's' для пропуску): ${NC}"
    read -r SKIP
    if [[ "$SKIP" != "s" && "$SKIP" != "S" ]]; then
        if command -v nmap &>/dev/null; then
            NMAP_VER=$(nmap --version 2>/dev/null | head -1)
            correct "nmap встановлено: $NMAP_VER" "Практичне 4"
        else
            wrong "sudo apt install nmap" "nmap не знайдено. Встановіть: sudo apt install -y nmap"
        fi
    fi

    # Завдання 5: /etc/hosts
    echo -e "\n  ${BOLD}🔧 Завдання 5. Записи у /etc/hosts${NC}"
    echo -e "  Додайте до /etc/hosts рядки для 'server' та 'client'."
    echo -e "  Приклад: ${CYAN}192.168.177.101  server${NC}"
    echo -ne "  ${YELLOW}▶ Натисніть Enter після виконання (або 's' для пропуску): ${NC}"
    read -r SKIP
    if [[ "$SKIP" != "s" && "$SKIP" != "S" ]]; then
        if grep -qE "server|client" /etc/hosts; then
            correct "Записи для server/client знайдено у /etc/hosts." "Практичне 5"
        else
            wrong "echo '192.168.177.101 server' >> /etc/hosts" "Записи не знайдено. Відредагуйте /etc/hosts через sudo nano /etc/hosts"
        fi
    fi

    # Завдання 6: Netplan — статична IP
    echo -e "\n  ${BOLD}🔧 Завдання 6. Статична IP-адреса${NC}"
    echo -e "  Перевірка: IP-адреса інтерфейсу НЕ повинна мати позначку 'dynamic'."
    echo -ne "  ${YELLOW}▶ Натисніть Enter для перевірки (або 's' для пропуску): ${NC}"
    read -r SKIP
    if [[ "$SKIP" != "s" && "$SKIP" != "S" ]]; then
        if ip a | grep -q "inet " && ! ip a | grep -q "dynamic"; then
            CURRENT_IP=$(ip -4 a show scope global | grep inet | awk '{print $2}' | head -1)
            correct "Статична адреса виявлена: $CURRENT_IP" "Практичне 6"
        else
            wrong "netplan try після редагування /etc/netplan/*.yaml" \
                "Адреса має позначку dynamic (DHCP) або не призначена. Налаштуйте статичну IP через Netplan."
        fi
    fi

    section_summary
}

# ════════════════════════════════════════════════════════════
#  ПІДСУМОК
# ════════════════════════════════════════════════════════════

show_results() {
    print_header
    echo ""
    echo -e "${BOLD}  ╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}  ║                  ПІДСУМОК ТЕСТУВАННЯ                ║${NC}"
    echo -e "${BOLD}  ╚══════════════════════════════════════════════════════╝${NC}"
    echo ""

    local PERCENT=0
    [ "$MAX_SCORE" -gt 0 ] && PERCENT=$(( SCORE * 100 / MAX_SCORE ))

    echo -e "  Курсант:      ${BOLD}$CADET_NAME${NC}"
    echo -e "  Група:        ${BOLD}$CADET_GROUP${NC}"
    echo -e "  Правильно:    ${GREEN}${BOLD}$SCORE${NC} з ${MAX_SCORE}"
    echo -e "  Неправильно:  ${RED}${BOLD}$WRONG${NC}"
    echo -e "  Відсоток:     ${BOLD}$PERCENT%${NC}"
    echo ""

    local GRADE
    if [ "$PERCENT" -ge 90 ]; then
        GRADE="${GREEN}${BOLD}Відмінно (5)${NC}"
    elif [ "$PERCENT" -ge 75 ]; then
        GRADE="${GREEN}Добре (4)${NC}"
    elif [ "$PERCENT" -ge 60 ]; then
        GRADE="${YELLOW}Задовільно (3)${NC}"
    else
        GRADE="${RED}Незадовільно (2)${NC}"
    fi

    echo -e "  Оцінка:       $GRADE"
    echo ""

    {
        echo "─────────────────────────"
        echo "Результат:  $SCORE / $MAX_SCORE ($PERCENT%)"
        echo "Оцінка:     $(echo -e "$GRADE" | sed 's/\x1b\[[0-9;]*m//g')"
        echo "Закінчено:  $(date '+%Y-%m-%d %H:%M:%S')"
        echo "─────────────────────────"
    } >> "$LOG_FILE"

    mkdir -p "$RESULTS_DIR"
    local RESULT_FILE="${RESULTS_DIR}/result_${CADET_NAME// /_}_$(date +%Y%m%d_%H%M%S).txt"
    cp "$LOG_FILE" "$RESULT_FILE" 2>/dev/null

    echo -e "  ${DIM}Лог збережено: $RESULT_FILE${NC}"
    echo ""
}

# ════════════════════════════════════════════════════════════
#  ГОЛОВНА ФУНКЦІЯ
# ════════════════════════════════════════════════════════════

main() {
    intro

    section_interfaces
    section_netplan
    section_diagnostics
    section_nmap
    section_practical

    show_results
}

main "$@"
