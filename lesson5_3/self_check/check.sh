#!/bin/bash
# ============================================================
#  check_m5l3.sh — Інтерактивний скрипт самоперевірки
#  Змістовий модуль 5, Заняття 3 (Групове)
#  Тема: BASH-скрипти та системи логування
# ============================================================

# ─── Кольори ────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m';  YELLOW='\033[1;33m'
BLUE='\033[0;34m';   CYAN='\033[0;36m';   MAGENTA='\033[0;35m'
BOLD='\033[1m';      DIM='\033[2m';        NC='\033[0m'

# ─── Конфігурація ───────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"
LOG_FILE="/tmp/check_m3l1_$(date +%Y%m%d_%H%M%S).log"

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
    echo "║  🐧  М5З3 — BASH-скрипти та системи логування              ║"
    echo "║      Самоперевірка знань | Кафедра 21, ВІТІ                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  Скрипт перевіряє знання з двох тем:"
    echo -e "  ${BOLD}1.${NC} BASH-скрипти"
    echo -e "  ${BOLD}2.${NC} Системи логування"
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
    echo "║  🐧  М5З3 — BASH-скрипти та системи логування              ║"
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
    # Питання з варіантами вибору
    # $1 — питання, $2 — варіанти (a/b/c/d), $3 — правильний, $4 — пояснення
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

practical_task() {
    # $1 — опис завдання, $2 — команда для перевірки, $3 — пояснення
    echo -e "\n  ${BOLD}🔧 Практичне завдання:${NC}"
    echo -e "  $1"
    echo -ne "  ${YELLOW}▶ Натисніть Enter після виконання (або 's' для пропуску): ${NC}"
    read -r SKIP
    if [[ "$SKIP" == "s" || "$SKIP" == "S" ]]; then
        echo -e "  ${DIM}Пропущено.${NC}"
        return
    fi
    if eval "$2" &>/dev/null; then
        correct "$3" "Практичне: $1"
    else
        wrong "Завдання не виконано" "$3"
    fi
}

# ════════════════════════════════════════════════════════════
#  РОЗДІЛ 1: BASH-СКРИПТИ — ОСНОВИ
# ════════════════════════════════════════════════════════════

section_bash_basics() {
    print_header
    print_section "РОЗДІЛ 1: BASH-скрипти — основи"

    ask_question \
        "Який рядок повинен бути ПЕРШИМ у bash-скрипті, щоб вказати інтерпретатор?" \
        "#!/bin/bash|#! /bin/bash|shebang|шебанг" \
        '#!/bin/bash — шебанг (shebang). Вказує системі, яким інтерпретатором виконувати файл.' \
        "Починається з #!"

    ask_question \
        "Яка команда дозволяє виконати скрипт script.sh?" \
        "chmod.*\+x|chmod.*7[0-9][0-9]|chmod.*[0-9]5[0-9]" \
        'chmod +x script.sh — додає право на виконання.' \
        "Потрібно змінити права доступу до файлу"

    ask_mc \
        "Як правильно оголосити змінну в bash?" \
        "  a) VAR = \"значення\"\n  b) VAR=\"значення\"\n  c) \$VAR=\"значення\"\n  d) set VAR=\"значення\"" \
        "b" \
        'VAR="значення" — без пробілів навколо знаку =. Пробіли призведуть до помилки.'

    ask_question \
        "Яка спеціальна змінна містить код повернення останньої команди?" \
        '^\$\?$|\$\?|\?\?|dollar.*question' \
        '$? — код повернення. 0 означає успіх, будь-яке інше число — помилку.'

    ask_question \
        "Як зберегти результат команди date у змінну TODAY?" \
        'today=\$\(date|today=`date' \
        'TODAY=$(date) — підстановка команди через $() або зворотні лапки ``.' \
        "Використовується підстановка команди \$()"

    ask_mc \
        "Яка змінна містить КІЛЬКІСТЬ аргументів, переданих скрипту?" \
        "  a) \$0\n  b) \$1\n  c) \$#\n  d) \$@" \
        "c" \
        '$# — кількість аргументів. $0 — ім'\''я скрипту, $1 — перший аргумент, $@ — всі аргументи.'

    ask_question \
        "Яка конструкція виконує команду і ЗБЕРІГАЄ рядок у змінну LINE з файлу file.txt?" \
        "while.*read.*line|while.*IFS.*read" \
        'while IFS= read -r LINE; do ...; done < file.txt — стандартний спосіб читання файлу рядок за рядком.'

    section_summary
}

# ════════════════════════════════════════════════════════════
#  РОЗДІЛ 2: УМОВИ ТА ОПЕРАТОРИ
# ════════════════════════════════════════════════════════════

section_bash_conditions() {
    print_header
    print_section "РОЗДІЛ 2: Умовні конструкції та оператори"

    ask_mc \
        "Який оператор перевіряє, що файл ІСНУЄ і є звичайним файлом?" \
        "  a) -d\n  b) -e\n  c) -f\n  d) -r" \
        "c" \
        '-f — існує і є звичайним файлом. -d — директорія, -e — будь-який тип, -r — доступний для читання.'

    ask_mc \
        "Який оператор перевіряє, що числа A і B РІВНІ?" \
        "  a) A == B\n  b) A -eq B\n  c) A = B\n  d) A -ne B" \
        "b" \
        '-eq — equal (рівно). Для чисел: -eq -ne -lt -le -gt -ge. Для рядків: = != -z -n.'

    ask_question \
        "Що означає умова [ -z \"\$VAR\" ] у bash?" \
        "порожн|empty|нульов|zero.*length|довжина.*нуль" \
        '[ -z "$VAR" ] — рядок VAR є порожнім (zero length). -n перевіряє непорожній рядок.'

    ask_mc \
        "Яка конструкція дозволяє порівнювати рядок з шаблоном (pattern matching) і підтримує &&, ||?" \
        "  a) [ condition ]\n  b) (( condition ))\n  c) [[ condition ]]\n  d) { condition }" \
        "c" \
        '[[ condition ]] — розширений test у bash. Підтримує =~, &&, ||, glob без додаткових лапок.'

    ask_question \
        "Яка конструкція case завершує кожну гілку варіанту?" \
        ";;" \
        ";; — подвійна крапка з комою завершує кожну гілку case..esac.'

    ask_mc \
        "Яку конструкцію використати для вибору з кількох рядкових значень (start|stop|restart)?" \
        "  a) if-elif-else\n  b) case\n  c) select\n  d) switch" \
        "b" \
        'case — найзручніша конструкція для перевірки рядкових значень. Аналог switch у інших мовах.'

    section_summary
}

# ════════════════════════════════════════════════════════════
#  РОЗДІЛ 3: ЦИКЛИ ТА ФУНКЦІЇ
# ════════════════════════════════════════════════════════════

section_bash_loops() {
    print_header
    print_section "РОЗДІЛ 3: Цикли та функції"

    ask_mc \
        "Яка команда ПЕРЕРИВАЄ цикл негайно?" \
        "  a) continue\n  b) exit\n  c) break\n  d) return" \
        "c" \
        'break — перериває цикл. continue — пропускає поточну ітерацію і переходить до наступної.'

    ask_question \
        "Як виглядає числовий цикл від 1 до 5 у bash?" \
        "for.*\{1\.\.5\}|for.*seq|for.*\(\(i=1" \
        'for i in {1..5}; do ... done — або for ((i=1; i<=5; i++)); do ... done'

    ask_mc \
        "Цикл while виконується..." \
        "  a) поки умова ХИБНА\n  b) поки умова ІСТИННА\n  c) рівно N разів\n  d) тільки один раз" \
        "b" \
        'while — виконується ПОКИ умова істинна. until — виконується ПОКИ умова хибна (протилежність while).'

    ask_question \
        "Як оголосити локальну змінну всередині функції bash?" \
        "^local |local [a-z]" \
        'local VAR="значення" — змінна існує тільки у межах функції. Без local — глобальна.'

    ask_question \
        "Яка команда повертає значення з функції bash (ціле число 0-255)?" \
        "^return$|return [0-9]" \
        'return N — повертає код виходу (0-255). Для повернення рядка використовують echo + підстановку команди.'

    ask_mc \
        "Як отримати результат функції my_func, що виводить рядок через echo?" \
        "  a) return \$(my_func)\n  b) RESULT=\$(my_func)\n  c) RESULT=my_func\n  d) get my_func RESULT" \
        "b" \
        'RESULT=$(my_func) — підстановка команди. Функція виводить значення через echo, викликач захоплює його через $().'

    section_summary
}

# ════════════════════════════════════════════════════════════
#  РОЗДІЛ 4: ПЕРЕНАПРАВЛЕННЯ ТА РЯДКИ
# ════════════════════════════════════════════════════════════

section_bash_io() {
    print_header
    print_section "РОЗДІЛ 4: Введення/виведення та рядкові операції"

    ask_mc \
        "Яке перенаправлення ДОПИСУЄ виведення у файл (не перезаписує)?" \
        "  a) >\n  b) >>\n  c) <\n  d) |" \
        "b" \
        '>> — дописати (append). > — перезаписати. < — вхід з файлу. | — pipe (передати далі).'

    ask_question \
        "Як перенаправити STDERR (помилки) у /dev/null?" \
        "2>/dev/null|2> /dev/null" \
        '2>/dev/null — дескриптор 2 це stderr. /dev/null — "чорна діра", ігнорує все записане.' \
        "Дескриптор stderr = 2"

    ask_question \
        "Як отримати ДОВЖИНУ рядка STR у bash?" \
        '\$\{#str\}|\$\{#STR\}|#str|#STR' \
        '${#STR} — довжина рядка STR у символах.'

    ask_question \
        "Яка операція витягує тільки ім'я файлу з шляху /var/log/syslog?" \
        '\$\{.*##\*/\}|basename|##\*/' \
        '${FILEPATH##*/} — видалити найдовший префікс до /. Або: basename "$FILEPATH".' \
        "Підстановка параметра: ##*/"

    ask_mc \
        "Що виведе: echo \"\${VAR:-default}\" якщо VAR не визначено?" \
        "  a) порожній рядок\n  b) \"-default\"\n  c) \"default\"\n  d) помилку" \
        "c" \
        '${VAR:-default} — якщо VAR не визначено або порожній, використати "default". Зручно для значень за замовчуванням.'

    section_summary
}

# ════════════════════════════════════════════════════════════
#  РОЗДІЛ 5: СИСТЕМИ ЛОГУВАННЯ — ОСНОВИ
# ════════════════════════════════════════════════════════════

section_logging_basics() {
    print_header
    print_section "РОЗДІЛ 5: Системи логування — основи"

    ask_question \
        "У якій директорії знаходяться основні файли логів Linux?" \
        "^/var/log$|var/log" \
        '/var/log/ — стандартна директорія для файлів логів у Linux.'

    ask_question \
        "Яка команда дозволяє стежити за оновленням файлу логу в реальному часі?" \
        "tail -f|tail.*-f|tail.*--follow" \
        'tail -f /var/log/syslog — відображає нові рядки в реальному часі (follow). Ctrl+C для виходу.'

    ask_mc \
        "Що таке рівень логування 'err' у syslog?" \
        "  a) Найвищий рівень критичності\n  b) Звичайне інформаційне повідомлення\n  c) Повідомлення про помилки (рівень 3)\n  d) Налагоджувальна інформація" \
        "c" \
        'err (error) — рівень 3, повідомлення про помилки. Вище за нього: crit(2), alert(1), emerg(0).'

    ask_mc \
        "Який файл містить логи авторизації, входів та sudo в Ubuntu?" \
        "  a) /var/log/syslog\n  b) /var/log/auth.log\n  c) /var/log/kern.log\n  d) /var/log/boot.log" \
        "b" \
        '/var/log/auth.log — авторизація, sudo, SSH входи. /var/log/syslog — загальний системний журнал.'

    ask_question \
        "Яка команда записує повідомлення у системний журнал (syslog) зі скрипту?" \
        "^logger$|logger " \
        'logger — записує повідомлення у syslog. Приклад: logger -t myapp -p local0.info "Повідомлення".'

    ask_question \
        "Яка утиліта відповідає за ротацію лог-файлів в Ubuntu?" \
        "logrotate" \
        'logrotate — автоматично архівує, стискає і видаляє старі лог-файли. Конфіг: /etc/logrotate.conf'

    section_summary
}

# ════════════════════════════════════════════════════════════
#  РОЗДІЛ 6: journalctl
# ════════════════════════════════════════════════════════════

section_journalctl() {
    print_header
    print_section "РОЗДІЛ 6: journalctl — керування systemd-журналом"

    ask_question \
        "Яка команда показує логи конкретного сервісу, наприклад nginx?" \
        "journalctl -u nginx|journalctl.*-u.*nginx" \
        'journalctl -u nginx — логи юніту (-u = --unit). Можна комбінувати: journalctl -u nginx -f'

    ask_question \
        "Як переглянути через journalctl тільки повідомлення рівня 'error' і вище?" \
        "journalctl -p err|journalctl.*-p.*err|journalctl.*priority" \
        'journalctl -p err — пріоритет err і вище (err, crit, alert, emerg). -p 0..7 або назва рівня.'

    ask_mc \
        "Яка команда показує логи journald за ОСТАННЮ ГОДИНУ?" \
        '  a) journalctl -n 60\n  b) journalctl --since "1 hour ago"\n  c) journalctl -h 1\n  d) journalctl -t 3600' \
        "b" \
        'journalctl --since "1 hour ago" — або --since "2024-03-13 08:00". --until для кінцевої межі.'

    ask_mc \
        "Яка команда показує загальний РОЗМІР журналу journald на диску?" \
        "  a) journalctl -s\n  b) journalctl --size\n  c) journalctl --disk-usage\n  d) du /var/log/journal" \
        "c" \
        'journalctl --disk-usage — показує загальний розмір журналу. Для очищення: --vacuum-time або --vacuum-size.'

    ask_question \
        "Де systemd-journald зберігає журнали для ПОСТІЙНОГО збереження (між перезавантаженнями)?" \
        "/var/log/journal" \
        '/var/log/journal/ — постійне зберігання. /run/log/journal/ — тимчасове (RAM, зникає при reboot).' \
        "Підказка: /var/log/..."

    ask_mc \
        "Яка команда виводить журнал у форматі JSON?" \
        "  a) journalctl -j\n  b) journalctl -o json\n  c) journalctl --format=json\n  d) journalctl -J" \
        "b" \
        'journalctl -o json або -o json-pretty — вивід у форматі JSON. Зручно для обробки скриптами.'

    section_summary
}

# ════════════════════════════════════════════════════════════
#  РОЗДІЛ 7: ПРАКТИЧНІ ЗАВДАННЯ
# ════════════════════════════════════════════════════════════

section_practical() {
    print_header
    print_section "РОЗДІЛ 7: Практичні завдання"

    echo -e "  ${DIM}Перевірка виконання реальних команд у системі.${NC}"
    echo -e "  ${DIM}Введіть 's' для пропуску будь-якого завдання.${NC}"

    # Завдання 1: Написати скрипт
    echo -e "\n  ${BOLD}🔧 Завдання 1. Написати та виконати скрипт${NC}"
    echo -e "  Створіть файл /tmp/test_script.sh з таким вмістом:"
    echo -e "  ${CYAN}#!/bin/bash${NC}"
    echo -e "  ${CYAN}echo \"Хост: \$(hostname)\"${NC}"
    echo -e "  ${CYAN}echo \"Дата: \$(date '+%Y-%m-%d')\"${NC}"
    echo -e "  Надайте права на виконання та запустіть."
    echo -ne "  ${YELLOW}▶ Натисніть Enter після виконання (або 's' для пропуску): ${NC}"
    read -r SKIP
    if [[ "$SKIP" != "s" && "$SKIP" != "S" ]]; then
        if [ -f /tmp/test_script.sh ] && [ -x /tmp/test_script.sh ]; then
            correct "Файл існує і є виконуваним." "Практичне 1"
        else
            wrong "chmod +x /tmp/test_script.sh" "Файл /tmp/test_script.sh не знайдено або без прав виконання."
        fi
    fi

    # Завдання 2: logger
    echo -e "\n  ${BOLD}🔧 Завдання 2. Записати повідомлення у syslog${NC}"
    echo -e "  Виконайте: ${CYAN}logger -t check_test \"Тестовий запис від курсанта\"${NC}"
    echo -ne "  ${YELLOW}▶ Натисніть Enter після виконання (або 's' для пропуску): ${NC}"
    read -r SKIP
    if [[ "$SKIP" != "s" && "$SKIP" != "S" ]]; then
        if journalctl -t check_test -n 1 --no-pager 2>/dev/null | grep -q "Тестовий"; then
            correct "Повідомлення знайдено у journald." "Практичне 2"
        elif grep -q "check_test" /var/log/syslog 2>/dev/null; then
            correct "Повідомлення знайдено у /var/log/syslog." "Практичне 2"
        else
            wrong "logger -t check_test \"Тестовий запис\"" "Повідомлення не знайдено. Виконайте команду logger та спробуйте знову."
        fi
    fi

    # Завдання 3: journalctl
    echo -e "\n  ${BOLD}🔧 Завдання 3. Перевірка journalctl${NC}"
    echo -e "  Виконайте: ${CYAN}journalctl --disk-usage${NC}"
    echo -e "  Введіть показаний розмір журналу (наприклад: 48.0M або 1.2G):"
    echo -ne "  ${YELLOW}▶ Ваша відповідь: ${NC}"
    read -r DISK_USAGE_ANS
    if [[ "$DISK_USAGE_ANS" =~ [0-9]+(\.[0-9]+)?[KMG]B? ]]; then
        correct "Команда journalctl --disk-usage виконана успішно." "Практичне 3"
    elif [[ "$DISK_USAGE_ANS" == "s" || "$DISK_USAGE_ANS" == "S" ]]; then
        echo -e "  ${DIM}Пропущено.${NC}"
    else
        wrong "journalctl --disk-usage" "Введіть розмір у форматі типу 48.0M або 1.2G."
    fi

    # Завдання 4: Аналіз логів
    echo -e "\n  ${BOLD}🔧 Завдання 4. Підрахунок рядків у syslog${NC}"
    echo -e "  Виконайте: ${CYAN}wc -l /var/log/syslog${NC}"
    echo -e "  Введіть кількість рядків:"
    echo -ne "  ${YELLOW}▶ Ваша відповідь: ${NC}"
    read -r LINE_COUNT
    REAL_COUNT=$(wc -l < /var/log/syslog 2>/dev/null || echo "0")
    if [[ "$LINE_COUNT" =~ ^[0-9]+$ ]] && [ "$LINE_COUNT" -gt 0 ]; then
        correct "Команда wc -l виконана успішно. Справжній розмір: $REAL_COUNT рядків." "Практичне 4"
    elif [[ "$LINE_COUNT" == "s" || "$LINE_COUNT" == "S" ]]; then
        echo -e "  ${DIM}Пропущено.${NC}"
    else
        wrong "wc -l /var/log/syslog" "Команда wc -l <файл> підраховує рядки."
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

    # Зберегти результат
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

    section_bash_basics
    section_bash_conditions
    section_bash_loops
    section_bash_io
    section_logging_basics
    section_journalctl
    section_practical

    show_results
}

main "$@"
