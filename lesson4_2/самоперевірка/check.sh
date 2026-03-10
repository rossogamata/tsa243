#!/bin/bash
# ============================================================
#  check.sh — Інтерактивний скрипт самоперевірки
#  Тема: Системне ПЗ — пакети, бібліотеки, редактори
#  Курс: 2-й курс | Ubuntu / WSL2
# ============================================================

# ─── Кольори та стилі ────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Глобальні змінні ────────────────────────────────────────
SCORE=0
MAX_SCORE=0
WRONG=0
SECTION_SCORE=0
SECTION_MAX=0
CADET_NAME=""
LOG_FILE="/tmp/pkg_check_$(date +%Y%m%d_%H%M%S).log"

# ─── Допоміжні функції ───────────────────────────────────────

print_header() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║    📦  САМОПЕРЕВІРКА ЗНАНЬ — СИСТЕМНЕ ПЗ  📦               ║"
    echo "║    APT · Бібліотеки · Збірка · Редактори · sed/awk         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  📌 $1${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

correct() {
    echo -e "  ${GREEN}${BOLD}✅  Правильно! ${NC}${DIM}$1${NC}"
    ((SCORE++))
    ((SECTION_SCORE++))
    ((MAX_SCORE++))
    ((SECTION_MAX++))
    echo "[CORRECT] $2" >> "$LOG_FILE"
    sleep 0.4
}

wrong() {
    echo -e "  ${RED}${BOLD}❌  Неправильно.${NC}"
    echo -e "  ${YELLOW}💡  Правильна відповідь: ${BOLD}$1${NC}"
    echo -e "  ${DIM}$2${NC}"
    ((WRONG++))
    ((MAX_SCORE++))
    ((SECTION_MAX++))
    echo "[WRONG] Correct: $1" >> "$LOG_FILE"
    sleep 0.8
}

hint() {
    echo -e "  ${MAGENTA}${DIM}💭 Підказка: $1${NC}"
}

ask_question() {
    # $1 — питання, $2 — regex відповіді, $3 — пояснення, $4 — підказка
    echo -e "\n  ${BOLD}❓ $1${NC}"
    [ -n "$4" ] && hint "$4"
    echo -ne "  ${YELLOW}▶ Ваша відповідь: ${NC}"
    read -r USER_ANSWER
    USER_ANSWER_LOWER=$(echo "$USER_ANSWER" | tr '[:upper:]' '[:lower:]' | xargs)
    if echo "$USER_ANSWER_LOWER" | grep -qiE "$2"; then
        correct "$3" "$1"
        return 0
    else
        wrong "$2" "$3"
        return 1
    fi
}

ask_choice() {
    # $1 — питання, $2 — варіанти через |, $3 — правильна літера, $4 — пояснення
    echo -e "\n  ${BOLD}❓ $1${NC}"
    echo ""
    IFS='|' read -ra OPTIONS <<< "$2"
    LETTERS=("a" "b" "c" "d" "e")
    for i in "${!OPTIONS[@]}"; do
        echo -e "    ${BOLD}${LETTERS[$i]})${NC} ${OPTIONS[$i]}"
    done
    echo ""
    echo -ne "  ${YELLOW}▶ Ваш вибір [${LETTERS[0]}-${LETTERS[$((${#OPTIONS[@]}-1))]}]: ${NC}"
    read -r USER_CHOICE
    USER_CHOICE_LOWER=$(echo "$USER_CHOICE" | tr '[:upper:]' '[:lower:]' | xargs)
    CORRECT_LOWER=$(echo "$3" | tr '[:upper:]' '[:lower:]')
    if [[ "$USER_CHOICE_LOWER" == "$CORRECT_LOWER" ]]; then
        correct "$4" "$1"
        return 0
    else
        CORRECT_IDX=$(echo "$CORRECT_LOWER" | tr 'a-e' '0-4')
        wrong "$3) ${OPTIONS[$CORRECT_IDX]}" "$4"
        return 1
    fi
}

ask_multichoice() {
    echo -e "\n  ${BOLD}❓ $1${NC}"
    echo -e "  ${DIM}(Введіть літери через кому, наприклад: a,c)${NC}"
    echo ""
    IFS='|' read -ra OPTIONS <<< "$2"
    LETTERS=("a" "b" "c" "d" "e")
    for i in "${!OPTIONS[@]}"; do
        echo -e "    ${BOLD}${LETTERS[$i]})${NC} ${OPTIONS[$i]}"
    done
    echo ""
    echo -ne "  ${YELLOW}▶ Ваш вибір: ${NC}"
    read -r USER_CHOICES
    USER_SORTED=$(echo "$USER_CHOICES" | tr -d ' ' | tr ',' '\n' | tr '[:upper:]' '[:lower:]' | sort | tr '\n' ',' | sed 's/,$//')
    CORRECT_SORTED=$(echo "$3" | tr -d ' ' | tr ',' '\n' | tr '[:upper:]' '[:lower:]' | sort | tr '\n' ',' | sed 's/,$//')
    if [[ "$USER_SORTED" == "$CORRECT_SORTED" ]]; then
        correct "$4" "$1"
    else
        wrong "$3" "$4"
    fi
}

ask_practical() {
    echo -e "\n  ${BOLD}🔧 ПРАКТИЧНЕ ЗАВДАННЯ: $1${NC}"
    echo -e "  ${DIM}$2${NC}"
    echo ""
    echo -ne "  ${YELLOW}▶ Натисніть Enter після виконання (або 's' для пропуску): ${NC}"
    read -r PRAC_ANSWER
    if [[ "$PRAC_ANSWER" == "s" || "$PRAC_ANSWER" == "S" ]]; then
        echo -e "  ${DIM}⏭  Завдання пропущено${NC}"
        return 2
    fi
    if eval "$3" &>/dev/null; then
        correct "$4" "$1"
        echo -e "  ${GREEN}${DIM}Перевірка пройшла успішно!${NC}"
        return 0
    else
        echo -e "  ${RED}Перевірка не пройдена.${NC}"
        echo -e "  ${YELLOW}💡 Підказка: $4${NC}"
        ((WRONG++))
        ((MAX_SCORE++))
        ((SECTION_MAX++))
        return 1
    fi
}

section_result() {
    echo ""
    echo -e "  ${DIM}──────────────────────────────────────────${NC}"
    PERCENT=0
    [ "$SECTION_MAX" -gt 0 ] && PERCENT=$((SECTION_SCORE * 100 / SECTION_MAX))
    if [ "$PERCENT" -ge 80 ]; then
        echo -e "  ${GREEN}${BOLD}Результат розділу: $SECTION_SCORE/$SECTION_MAX ($PERCENT%) ✨${NC}"
    elif [ "$PERCENT" -ge 50 ]; then
        echo -e "  ${YELLOW}${BOLD}Результат розділу: $SECTION_SCORE/$SECTION_MAX ($PERCENT%) 📚${NC}"
    else
        echo -e "  ${RED}${BOLD}Результат розділу: $SECTION_SCORE/$SECTION_MAX ($PERCENT%) — Потрібне повторення!${NC}"
    fi
    SECTION_SCORE=0
    SECTION_MAX=0
    echo ""
    echo -ne "  ${DIM}Натисніть Enter для продовження...${NC}"
    read -r
}

progress_bar() {
    local current=$1
    local total=$2
    local width=40
    local filled=$((current * width / total))
    local empty=$((width - filled))
    echo -ne "  ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    echo -ne "] $current/$total"
}

# ═══════════════════════════════════════════════════════════════
#  ВСТУП
# ═══════════════════════════════════════════════════════════════

intro() {
    print_header
    echo -e "  ${BOLD}Вітаємо у скрипті самоперевірки!${NC}"
    echo ""
    echo -e "  Цей скрипт перевірить ваші знання з п'яти тем:"
    echo -e "    ${CYAN}1.${NC} APT — пакетний менеджер"
    echo -e "    ${CYAN}2.${NC} Спільні бібліотеки та залежності"
    echo -e "    ${CYAN}3.${NC} Встановлення з вихідного коду"
    echo -e "    ${CYAN}4.${NC} Текстові редактори (nano та vim)"
    echo -e "    ${CYAN}5.${NC} Потокові редактори (sed та awk)"
    echo -e "    ${CYAN}6.${NC} Практичний блок — дослідження системи"
    echo -e "    ${CYAN}7.${NC} Блискавичне опитування"
    echo ""
    echo -e "  ${DIM}Для практичних завдань введіть 's' щоб пропустити${NC}"
    echo ""
    echo -ne "  ${YELLOW}▶ Введіть ваше прізвище та ім'я: ${NC}"
    read -r CADET_NAME
    [ -z "$CADET_NAME" ] && CADET_NAME="Курсант"
    echo ""
    echo -e "  ${GREEN}Вітаємо, ${BOLD}$CADET_NAME${NC}${GREEN}! Починаємо тестування.${NC}"
    echo ""
    echo "=== Тестування: $CADET_NAME | $(date) ===" >> "$LOG_FILE"
    sleep 1
}

# ═══════════════════════════════════════════════════════════════
#  РОЗДІЛ 1: APT — ПАКЕТНИЙ МЕНЕДЖЕР
# ═══════════════════════════════════════════════════════════════

section1() {
    print_section "РОЗДІЛ 1: APT — пакетний менеджер"

    ask_question \
        "Яка команда APT оновлює індекс доступних пакетів (але НЕ сам пакети)?" \
        "apt update|sudo apt update" \
        "'apt update' завантажує актуальний список пакетів з репозиторіїв. Без цього 'apt install' може встановити застарілу версію." \
        "apt ..."

    ask_choice \
        "Яка різниця між 'apt remove' та 'apt purge'?" \
        "Немає різниці — обидві однакові|remove видаляє пакет, purge — пакет разом з конфіг-файлами|purge видаляє тільки конфіги, remove — тільки бінарники|remove швидший, purge — повільніший" \
        "b" \
        "'apt remove' залишає конфіг-файли (статус dpkg: 'rc'). 'apt purge' видаляє і пакет, і всі конфіги. Після purge + autoremove пакет зникає повністю."

    ask_question \
        "Яка команда показує детальну інформацію про пакет (версія, залежності, розмір) до встановлення?" \
        "apt show" \
        "'apt show <пакет>' виводить: Version, Depends, Installed-Size, Description тощо." \
        "apt ..."

    ask_choice \
        "Що відображає команда 'dpkg -L htop'?" \
        "Залежності пакету htop|Список файлів, які встановив пакет htop|Статус встановлення htop|Версію пакету htop" \
        "b" \
        "'dpkg -L <пакет>' (List) — показує всі файли, що входять до пакету: бінарники, man-сторінки, іконки тощо."

    ask_question \
        "Яка команда dpkg знаходить, якому пакету належить конкретний файл?" \
        "dpkg -S|dpkg -s" \
        "'dpkg -S /шлях/до/файлу' (Search) — знаходить пакет-власник файлу. Наприклад: dpkg -S /usr/bin/git" \
        "dpkg з ключем -S (Search)"

    ask_choice \
        "Яка команда показує ЗВОРОТНІ залежності — хто залежить від пакету 'libssl3'?" \
        "apt-cache depends libssl3|apt-cache rdepends libssl3|dpkg -l libssl3|apt show --reverse libssl3" \
        "b" \
        "'apt-cache rdepends <пакет>' (reverse depends) — список пакетів, що залежать від вказаного. Корисно перед видаленням бібліотеки."

    ask_question \
        "Яка команда APT симулює встановлення без реального виконання?" \
        "apt-get install -s|apt install -s|apt-get.*-s" \
        "'apt-get install -s <пакет>' (simulate) виводить, що БУДЕ встановлено, без жодних змін у системі." \
        "apt-get install з певним ключем"

    ask_choice \
        "Який статус dpkg означає, що пакет видалено, але конфіги залишились?" \
        "ii — installed|rc — removed, config-files remain|un — unknown|ph — half-installed" \
        "b" \
        "'rc' = Removed + Config files remain. Після 'apt purge' статус змінюється на 'un' і пакет зникає зі списку dpkg -l."

    ask_practical \
        "Переглядання інформації про встановлений пакет" \
        "Виконайте: apt show git | grep -E 'Version|Depends|Size'" \
        "command -v git" \
        "apt show git виводить усі метадані пакету git"

    ask_multichoice \
        "Оберіть ВСІ правильні команди для перегляду залежностей пакету curl:" \
        "apt-cache depends curl|apt show curl|dpkg -l curl|apt-get install -s curl" \
        "a,b" \
        "'apt-cache depends curl' та 'apt show curl' (поле Depends) — показують залежності. dpkg -l — статус, apt-get install -s — симуляція встановлення."

    section_result
}

# ═══════════════════════════════════════════════════════════════
#  РОЗДІЛ 2: СПІЛЬНІ БІБЛІОТЕКИ ТА ЗАЛЕЖНОСТІ
# ═══════════════════════════════════════════════════════════════

section2() {
    print_section "РОЗДІЛ 2: Спільні бібліотеки та залежності"

    ask_choice \
        "Яка утиліта показує список динамічних бібліотек, від яких залежить бінарний файл?" \
        "ldconfig|ldd|nm|objdump" \
        "b" \
        "'ldd /usr/bin/git' — виводить усі .so бібліотеки та шляхи до них. Незамінний інструмент для діагностики 'not found' помилок."

    ask_question \
        "Яка розширення мають динамічні (спільні) бібліотеки у Linux?" \
        "\.so|\.so\." \
        "Спільні бібліотеки мають розширення .so (Shared Object): libssl.so, libncurses.so.6 тощо. У Windows — .dll." \
        "Скорочення від Shared Object"

    ask_choice \
        "У чому ГОЛОВНА перевага динамічних бібліотек перед статичними?" \
        "Статичні швидше завантажуються|Одна копія бібліотеки у пам'яті використовується всіма програмами|Динамічні не потребують ОС|Статичні займають менше місця на диску" \
        "b" \
        "Динамічні (.so): одна копія в пам'яті для всіх процесів, оновлення без перекомпіляції. Статичні (.a): код вбудований у кожен бінарник — більший розмір файлу."

    ask_question \
        "Яка команда оновлює кеш динамічних бібліотек після встановлення нової бібліотеки?" \
        "ldconfig|sudo ldconfig" \
        "'sudo ldconfig' перечитує конфіги (/etc/ld.so.conf.d/) та оновлює /etc/ld.so.cache. Потрібно запускати після встановлення бібліотек вручну." \
        "ld..."

    ask_choice \
        "Яка змінна середовища дозволяє тимчасово вказати нестандартний шлях до бібліотек?" \
        "LIBRARY_PATH|LD_LIBRARY_PATH|LD_PRELOAD|LIBDIR" \
        "b" \
        "LD_LIBRARY_PATH=/мій/шлях:$LD_LIBRARY_PATH — але використовувати лише тимчасово! У продакшені краще додати шлях до /etc/ld.so.conf.d/ і виконати ldconfig."

    ask_question \
        "Яка команда показує всі бібліотеки, відомі системі (кеш ldconfig)?" \
        "ldconfig -p" \
        "'ldconfig -p' (print cache) виводить повний список бібліотек з кешу. Можна фільтрувати: ldconfig -p | grep libssl" \
        "ldconfig з певним ключем"

    ask_choice \
        "Де зазвичай зберігаються системні динамічні бібліотеки у 64-бітному Linux?" \
        "/usr/local/bin/|/lib/x86_64-linux-gnu/ та /usr/lib/|/etc/lib/|/var/lib/" \
        "b" \
        "Стандартні шляхи: /lib/, /usr/lib/, /lib/x86_64-linux-gnu/. Бібліотеки, встановлені вручну — /usr/local/lib/."

    ask_practical \
        "Аналіз залежностей бінарного файлу ls" \
        "Виконайте: ldd $(which ls)" \
        "ldd $(which ls) | grep -q 'libc'" \
        "ldd показує всі .so файли, від яких залежить бінарник. ls залежить від libc.so — основної бібліотеки C."

    section_result
}

# ═══════════════════════════════════════════════════════════════
#  РОЗДІЛ 3: ВСТАНОВЛЕННЯ З ВИХІДНОГО КОДУ
# ═══════════════════════════════════════════════════════════════

section3() {
    print_section "РОЗДІЛ 3: Встановлення з вихідного коду"

    ask_question \
        "Назвіть три кроки класичної збірки програми з вихідного коду у правильному порядку:" \
        "configure.*make.*install|configure.*make.*make install" \
        "./configure → make → sudo make install. Кожен крок: перевірка середовища, компіляція, копіювання файлів." \
        "Три команди через →"

    ask_choice \
        "Що робить команда './configure --prefix=/usr/local'?" \
        "Компілює програму у /usr/local|Перевіряє середовище та задає директорію встановлення|Встановлює програму без компіляції|Видаляє попередню версію програми" \
        "b" \
        "'./configure' перевіряє наявність компілятора, бібліотек та генерує Makefile. '--prefix' вказує куди встановити: бінарники → /usr/local/bin/, бібліотеки → /usr/local/lib/."

    ask_question \
        "Яка опція команди 'make' дозволяє компілювати з використанням усіх ядер процесора?" \
        "-j\$(nproc)|-j|--jobs" \
        "'make -j\$(nproc)' запускає паралельну компіляцію у стільки потоків, скільки ядер CPU. Значно прискорює збірку великих проектів." \
        "make з ключем -j"

    ask_choice \
        "Яка ГОЛОВНА відмінність програми, встановленої з вихідного коду, від встановленої через apt?" \
        "Немає відмінності — результат однаковий|apt не відстежує програму, встановлену з коду, і не може її оновити через apt upgrade|apt відстежує все, незалежно від способу встановлення|Програми з коду не можна видалити" \
        "b" \
        "Пакетний менеджер нічого не знає про програми, встановлені вручну. Для видалення потрібен 'sudo make uninstall' у тій самій директорії збірки."

    ask_question \
        "Яка команда видаляє програму, встановлену через 'make install'?" \
        "sudo make uninstall|make uninstall" \
        "'sudo make uninstall' — потрібно виконувати у тій самій директорії збірки, де є Makefile. Не всі проекти підтримують цю ціль." \
        "make ..."

    ask_choice \
        "Який пакет необхідно встановити для наявності компілятора gcc та утиліти make?" \
        "gcc-tools|build-essential|compiler-suite|dev-tools" \
        "b" \
        "'sudo apt install build-essential' встановлює: gcc, g++, make, libc-dev та інші базові інструменти розробника."

    ask_choice \
        "Що таке файл 'Makefile'?" \
        "Архів з вихідним кодом|Конфігураційний файл, що описує правила збірки та встановлення|Лог-файл компіляції|Список залежностей у форматі JSON" \
        "b" \
        "Makefile містить правила (targets): all, clean, install, uninstall. Команда 'make' читає Makefile і виконує відповідні команди."

    ask_question \
        "У яку директорію зазвичай встановлюються бінарники при './configure --prefix=/usr/local'?" \
        "/usr/local/bin" \
        "При prefix=/usr/local: бінарники → /usr/local/bin/, бібліотеки → /usr/local/lib/, заголовки → /usr/local/include/." \
        "Повний шлях до директорії з бінарниками"

    ask_practical \
        "Перевірте наявність компілятора gcc" \
        "Виконайте: gcc --version" \
        "command -v gcc" \
        "gcc --version виводить версію компілятора. Якщо відсутній — sudo apt install build-essential"

    section_result
}

# ═══════════════════════════════════════════════════════════════
#  РОЗДІЛ 4: ТЕКСТОВІ РЕДАКТОРИ
# ═══════════════════════════════════════════════════════════════

section4() {
    print_section "РОЗДІЛ 4: Текстові редактори (nano та vim)"

    # nano
    echo -e "  ${BOLD}─── nano ───────────────────────────────────────────${NC}"

    ask_question \
        "Яка комбінація клавіш у nano ЗБЕРІГАЄ файл?" \
        "ctrl\+o|ctrl-o|\^o" \
        "Ctrl+O (Write Out) — зберігає файл. Після натискання nano запитає ім'я файлу (або підтвердить поточне)." \
        "Ctrl+?"

    ask_question \
        "Яка комбінація клавіш у nano ВИХОДИТЬ з редактора?" \
        "ctrl\+x|ctrl-x|\^x" \
        "Ctrl+X (eXit) — виходить з nano. Якщо є незбережені зміни, nano запропонує зберегти." \
        "Ctrl+?"

    ask_choice \
        "Яка комбінація у nano відкриває ПОШУК?" \
        "Ctrl+F|Ctrl+W|Ctrl+S|Ctrl+G" \
        "b" \
        "Ctrl+W (Where is) — запускає пошук у nano. Ctrl+\\ — пошук і заміна. Ctrl+G — довідка."

    ask_question \
        "Яка комбінація у nano ВИРІЗАЄ поточний рядок у буфер?" \
        "ctrl\+k|ctrl-k|\^k" \
        "Ctrl+K (Kill line) — вирізає рядок. Ctrl+U (Unpaste) — вставляє вирізане. Так можна переміщати рядки." \
        "Ctrl+K"

    # vim
    echo ""
    echo -e "  ${BOLD}─── vim ────────────────────────────────────────────${NC}"

    ask_choice \
        "Скільки основних режимів роботи має vim?" \
        "1 (тільки введення тексту)|2 (Normal та Insert)|3 (Normal, Insert та Command/Visual)|5 (Normal, Insert, Visual, Command, Replace)" \
        "c" \
        "Головні режими: Normal (навігація, команди), Insert (введення тексту), Command (: команди), Visual (виділення). Replace — окремий підрежим."

    ask_question \
        "Яка клавіша у vim переводить у INSERT mode (вставка перед курсором)?" \
        "^i$" \
        "Клавіша 'i' (insert) — вхід в INSERT mode перед курсором. 'a' — після курсора, 'o' — новий рядок нижче, 'I' — початок рядка." \
        "Одна літера"

    ask_question \
        "Яка команда у vim ЗБЕРІГАЄ файл і ВИХОДИТЬ з редактора?" \
        ":wq|:wq!|zz" \
        "':wq' (write + quit) або 'ZZ' у Normal mode — зберегти і вийти. ':q!' — вийти без збереження. ':w' — тільки зберегти." \
        "Двокрапка + дві літери"

    ask_choice \
        "Яка команда у vim ВИДАЛЯЄ поточний рядок?" \
        "x|dd|yy|pp" \
        "b" \
        "'dd' (delete line) — видаляє (вирізає) рядок. '2dd' — видаляє 2 рядки. 'yy' — копіює, 'p' — вставляє, 'x' — видаляє символ."

    ask_question \
        "Яка команда vim замінює всі входження 'old' на 'new' у ВСЬОМУ файлі?" \
        ":%s/old/new/g" \
        "':%s/old/new/g': % — весь файл, s — substitute, /old/new/ — що на що, g — глобально (всі входження у рядку)." \
        ":%s/..."

    ask_choice \
        "Яку послідовність клавіш натиснути, щоб АВАРІЙНО вийти з vim без збереження?" \
        "Ctrl+C|Esc потім :q! потім Enter|Ctrl+Z|Shift+Q" \
        "b" \
        "Esc (повернутись у Normal mode) → :q! → Enter. Це 'рятувальна' комбінація — завжди працює незалежно від поточного режиму."

    section_result
}

# ═══════════════════════════════════════════════════════════════
#  РОЗДІЛ 5: ПОТОКОВІ РЕДАКТОРИ (sed та awk)
# ═══════════════════════════════════════════════════════════════

section5() {
    print_section "РОЗДІЛ 5: Потокові редактори (sed та awk)"

    ask_question \
        "Яка команда sed замінює 'http' на 'https' у всіх рядках файлу config.txt (з записом у файл)?" \
        "sed -i 's/http/https/g' config.txt|sed.*-i.*s/http/https" \
        "'sed -i 's/http/https/g' config.txt': -i (in-place) — зміни зберігаються у файл, g — глобально (всі входження у кожному рядку)." \
        "sed з ключем -i"

    ask_choice \
        "Що робить команда 'sed -n '3,6p' file.txt'?" \
        "Видаляє рядки 3-6|Замінює рядки 3-6|Виводить тільки рядки 3-6|Нумерує рядки 3-6" \
        "c" \
        "'-n' (no print — не виводити нічого автоматично) + '3,6p' (print рядки 3-6). Без -n 'p' дублює, тому їх використовують разом."

    ask_question \
        "Яка sed-команда ВИДАЛЯЄ всі рядки, що починаються з '#' (коментарі)?" \
        "sed '/\^#/d'|sed.*\^#.*d|'/^#/d'" \
        "'sed '/^#/d' file': ^ — початок рядка, # — символ коментаря, d — delete (видалити рядок)." \
        "sed з командою d (delete)"

    ask_choice \
        "Яка опція awk вказує розділювач полів (наприклад, кому для CSV)?" \
        "-d|--delimiter|-F|--sep" \
        "c" \
        "awk -F',' '{print $1}' file — опція -F (Field separator) задає розділювач. За замовчуванням — пробіл або табуляція."

    ask_question \
        "Яка awk-команда виводить перший стовпець CSV-файлу (розділювач — кома)?" \
        "awk -F',' '{print \$1}'|awk.*-F.*,.*print.*\\\$1" \
        "awk -F',' '{print \$1}' file: \$1 — перше поле, \$2 — друге, \$NF — останнє, \$0 — весь рядок." \
        "awk -F',' ..."

    ask_choice \
        "Що означає 'NR' у awk?" \
        "Кількість полів у рядку|Номер поточного рядку (Number of Record)|Назва файлу|Розділювач полів" \
        "b" \
        "NR — Number of Record (номер рядка). NF — Number of Fields (кількість полів). Приклад: 'NR>1' — пропустити заголовок CSV."

    ask_question \
        "Яка awk-конструкція виконує дію ПІСЛЯ обробки всіх рядків файлу?" \
        "END\s*\{|END {" \
        "'END { ... }' виконується після останнього рядка. 'BEGIN { ... }' — до першого. Приклад: вивести суму: 'END {print sum}'." \
        "Ключове слово у фігурних дужках"

    ask_multichoice \
        "Оберіть ВСІ правильні твердження про sed:" \
        "sed -i змінює файл безпосередньо|sed без -i не змінює оригінальний файл|sed може видаляти рядки командою d|sed може замінювати текст тільки в першому рядку" \
        "a,b,c" \
        "sed -i — in-place редагування. Без -i — вивід у stdout, файл не змінюється. Команда d — видалення рядків. Прапор g дозволяє замінювати у всьому рядку."

    ask_practical \
        "Практика sed — заміна тексту" \
        "Виконайте: echo 'Hello World' | sed 's/World/Linux/'" \
        "echo 'test' | sed 's/test/ok/'" \
        "sed 's/old/new/' замінює перше входження. sed 's/old/new/g' — всі входження у рядку."

    section_result
}

# ═══════════════════════════════════════════════════════════════
#  РОЗДІЛ 6: ПРАКТИЧНИЙ БЛОК (перевірка системи)
# ═══════════════════════════════════════════════════════════════

section6() {
    print_section "РОЗДІЛ 6: Практичний блок — дослідження системи"

    echo -e "  ${DIM}Цей розділ перевіряє реальний стан вашої системи.${NC}"
    echo -e "  ${DIM}Виконайте вказані команди та дайте відповіді на питання.${NC}"
    echo ""

    # Практичне 1 — підрахунок встановлених пакетів
    echo -e "  ${BOLD}🔧 Завдання 1: Кількість встановлених пакетів${NC}"
    echo -e "  ${DIM}Виконайте: dpkg -l | grep '^ii' | wc -l${NC}"
    echo ""
    REAL_PKG_COUNT=$(dpkg -l 2>/dev/null | grep '^ii' | wc -l)
    echo -ne "  ${YELLOW}▶ Скільки пакетів зі статусом 'ii' (встановлено) є у системі? ${NC}"
    read -r ANS1
    if [[ "$ANS1" == "$REAL_PKG_COUNT" ]]; then
        correct "Правильно! У системі $REAL_PKG_COUNT встановлених пакетів." "pkg count"
    else
        wrong "$REAL_PKG_COUNT" "dpkg -l | grep '^ii' | wc -l → $REAL_PKG_COUNT"
    fi

    # Практичне 2 — версія git
    echo ""
    echo -e "  ${BOLD}🔧 Завдання 2: Версія git${NC}"
    echo -e "  ${DIM}Виконайте: git --version${NC}"
    echo ""
    if command -v git &>/dev/null; then
        GIT_VERSION=$(git --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')
        echo -e "  ${DIM}Фактична версія git: ${BOLD}$GIT_VERSION${NC}"
        echo -ne "  ${YELLOW}▶ Введіть версію git у вашій системі (наприклад: 2.34.1): ${NC}"
        read -r ANS2
        if [[ "$ANS2" == "$GIT_VERSION" ]]; then
            correct "Правильно! git version $GIT_VERSION" "git version"
        else
            wrong "$GIT_VERSION" "git --version | grep -oP '\d+\.\d+\.\d+' → $GIT_VERSION"
        fi
    else
        echo -e "  ${YELLOW}⚠️  git не встановлено. Встановіть: sudo apt install git${NC}"
        echo -ne "  ${YELLOW}▶ Натисніть Enter для продовження...${NC}"
        read -r
    fi

    # Практичне 3 — кількість залежностей ls
    echo ""
    echo -e "  ${BOLD}🔧 Завдання 3: Бібліотеки команди ls${NC}"
    echo -e "  ${DIM}Виконайте: ldd \$(which ls)${NC}"
    echo ""
    LS_DEPS=$(ldd "$(which ls)" 2>/dev/null | wc -l)
    echo -ne "  ${YELLOW}▶ Скільки рядків виводить 'ldd \$(which ls)'? ${NC}"
    read -r ANS3
    if [[ "$ANS3" == "$LS_DEPS" ]]; then
        correct "Правильно! ldd ls виводить $LS_DEPS рядків." "ldd ls"
    else
        wrong "$LS_DEPS" "ldd \$(which ls) | wc -l → $LS_DEPS"
    fi

    # Практичне 4 — шлях до бінарника
    echo ""
    echo -e "  ${BOLD}🔧 Завдання 4: Де живе команда apt?${NC}"
    echo -e "  ${DIM}Виконайте: which apt${NC}"
    echo ""
    APT_PATH=$(which apt 2>/dev/null)
    echo -ne "  ${YELLOW}▶ Введіть повний шлях до бінарника apt: ${NC}"
    read -r ANS4
    ANS4=$(echo "$ANS4" | xargs)
    if [[ "$ANS4" == "$APT_PATH" ]]; then
        correct "Правильно! apt знаходиться у $APT_PATH" "apt path"
    else
        wrong "$APT_PATH" "which apt → $APT_PATH"
    fi

    # Практичне 5 — якому пакету належить /usr/bin/ls
    echo ""
    echo -e "  ${BOLD}🔧 Завдання 5: Власник файлу /usr/bin/ls${NC}"
    echo -e "  ${DIM}Виконайте: dpkg -S /usr/bin/ls${NC}"
    echo ""
    LS_PKG=$(dpkg -S /usr/bin/ls 2>/dev/null | cut -d: -f1)
    echo -ne "  ${YELLOW}▶ Якому пакету належить файл /usr/bin/ls? ${NC}"
    read -r ANS5
    ANS5=$(echo "$ANS5" | xargs | tr '[:upper:]' '[:lower:]')
    LS_PKG_LOWER=$(echo "$LS_PKG" | tr '[:upper:]' '[:lower:]')
    if [[ "$ANS5" == "$LS_PKG_LOWER" ]]; then
        correct "Правильно! /usr/bin/ls належить пакету: $LS_PKG" "ls owner"
    else
        wrong "$LS_PKG" "dpkg -S /usr/bin/ls → $LS_PKG"
    fi

    section_result
}

# ═══════════════════════════════════════════════════════════════
#  РОЗДІЛ 7: БЛИСКАВИЧНЕ ОПИТУВАННЯ
# ═══════════════════════════════════════════════════════════════

section7() {
    print_section "РОЗДІЛ 7: ⚡ Блискавичне опитування"
    echo -e "  ${DIM}Швидкі питання — відповідайте одним словом або командою${NC}"
    echo ""

    ask_question "Яка команда встановлює пакет і не задає питань (тихий режим)?" \
        "apt install.*-y|sudo apt install.*-y" \
        "apt install <пакет> -y (yes to all) — підтверджує всі питання автоматично." \
        "apt install ... з ключем"

    ask_question "Яка команда видаляє пакети, встановлені як залежності і більше не потрібні?" \
        "apt autoremove|sudo apt autoremove" \
        "'apt autoremove' видаляє осиротілі залежності — пакети, які були встановлені автоматично, але більше не потрібні." \
        "apt ..."

    ask_question "Яка клавіша vim переводить у INSERT mode і додає новий рядок НИЖЧЕ поточного?" \
        "^o$" \
        "Клавіша 'o' (open line below) — у Normal mode додає порожній рядок під курсором і входить у INSERT mode." \
        "Одна мала літера"

    ask_question "Яка sed-команда виводить рядки з 2-го по 5-й без модифікації файлу?" \
        "sed -n '2,5p'" \
        "'sed -n '2,5p' file' — виводить рядки 2-5. -n = тиха робота, p = print." \
        "sed -n ..."

    ask_question "Яка awk-змінна містить кількість полів у поточному рядку?" \
        "^NF$" \
        "NF (Number of Fields) — кількість полів. \$NF — значення останнього поля. NR — номер рядка." \
        "Дві великі літери"

    ask_question "Яка команда показує, чи встановлений пакет curl і яка його версія?" \
        "apt show curl|dpkg -l curl|dpkg -l.*curl" \
        "'dpkg -l curl' або 'apt show curl' — перевіряють наявність та версію пакету curl." \
        "dpkg або apt"

    ask_question "Яка утиліта vim дозволяє замінити одне слово під курсором у Normal mode?" \
        "^cw$" \
        "'cw' (change word) — видаляє слово під курсором і переходить у INSERT mode для введення нового." \
        "c + w"

    section_result
}

# ═══════════════════════════════════════════════════════════════
#  ПІДСУМКОВИЙ ЗВІТ
# ═══════════════════════════════════════════════════════════════

final_report() {
    clear
    print_header

    PERCENT=0
    [ "$MAX_SCORE" -gt 0 ] && PERCENT=$((SCORE * 100 / MAX_SCORE))

    echo -e "  ${BOLD}📊 ПІДСУМКОВИЙ ЗВІТ${NC}"
    echo ""
    echo -e "  Курсант: ${BOLD}$CADET_NAME${NC}"
    echo -e "  Дата:    $(date '+%d.%m.%Y %H:%M')"
    echo ""
    echo -ne "  Прогрес: "
    progress_bar "$SCORE" "$MAX_SCORE"
    echo ""
    echo ""
    echo -e "  ${BOLD}Правильних відповідей: ${GREEN}$SCORE${NC} ${BOLD}з ${MAX_SCORE}${NC}"
    echo -e "  ${BOLD}Неправильних:          ${RED}$WRONG${NC}"
    echo -e "  ${BOLD}Результат:             ${BOLD}$PERCENT%${NC}"
    echo ""

    echo -e "  ──────────────────────────────────────────────"
    if [ "$PERCENT" -ge 90 ]; then
        GRADE="ВІДМІННО"
        GRADE_COLOR="$GREEN"
        EMOJI="🏆"
        COMMENT="Чудова робота! Ви відмінно знаєте системне ПЗ Linux."
    elif [ "$PERCENT" -ge 75 ]; then
        GRADE="ДОБРЕ"
        GRADE_COLOR="$CYAN"
        EMOJI="🎯"
        COMMENT="Гарний результат! Повторіть теми, де були помилки."
    elif [ "$PERCENT" -ge 60 ]; then
        GRADE="ЗАДОВІЛЬНО"
        GRADE_COLOR="$YELLOW"
        EMOJI="📚"
        COMMENT="Матеріал засвоєно частково. Рекомендується додаткове опрацювання."
    else
        GRADE="НЕЗАДОВІЛЬНО"
        GRADE_COLOR="$RED"
        EMOJI="⚠️"
        COMMENT="Необхідно повторити матеріал. Перечитайте README.md та виконайте практичні завдання."
    fi

    echo ""
    echo -e "  $EMOJI  ${GRADE_COLOR}${BOLD}$GRADE ($PERCENT%)${NC}"
    echo ""
    echo -e "  ${DIM}$COMMENT${NC}"
    echo ""

    echo -e "  ──────────────────────────────────────────────"
    echo -e "  ${BOLD}📝 Шпаргалка ключових команд:${NC}"
    echo ""
    echo -e "  ${DIM}# APT${NC}"
    echo -e "  ${DIM}apt show <pkg>            — інформація про пакет${NC}"
    echo -e "  ${DIM}dpkg -L <pkg>             — файли пакету${NC}"
    echo -e "  ${DIM}dpkg -S <file>            — власник файлу${NC}"
    echo -e "  ${DIM}apt-cache rdepends <pkg>  — зворотні залежності${NC}"
    echo ""
    echo -e "  ${DIM}# Бібліотеки${NC}"
    echo -e "  ${DIM}ldd \$(which <cmd>)        — залежності бінарника${NC}"
    echo -e "  ${DIM}ldconfig -p | grep <lib>  — пошук у кеші${NC}"
    echo ""
    echo -e "  ${DIM}# Збірка${NC}"
    echo -e "  ${DIM}./configure --prefix=/usr/local && make -j\$(nproc) && sudo make install${NC}"
    echo ""
    echo -e "  ${DIM}# vim: i=insert  Esc=normal  :wq=save+quit  :q!=quit${NC}"
    echo -e "  ${DIM}# sed: -i in-place  s/old/new/g заміна  /pat/d видалення${NC}"
    echo -e "  ${DIM}# awk: -F роздільник  \$1 перше поле  NR номер рядка  NF кількість полів${NC}"
    echo ""

    {
        echo "=== ПІДСУМОК ==="
        echo "Курсант: $CADET_NAME"
        echo "Дата: $(date)"
        echo "Результат: $SCORE/$MAX_SCORE ($PERCENT%)"
        echo "Оцінка: $GRADE"
    } >> "$LOG_FILE"

    echo -e "  ${DIM}Детальний журнал збережено: $LOG_FILE${NC}"
    echo ""

    echo -ne "  ${YELLOW}▶ Бажаєте пройти тест повторно? [y/N]: ${NC}"
    read -r REPEAT
    if [[ "$REPEAT" =~ ^[yYтТ] ]]; then
        SCORE=0; MAX_SCORE=0; WRONG=0; SECTION_SCORE=0; SECTION_MAX=0
        main
    else
        echo ""
        echo -e "  ${GREEN}${BOLD}Дякуємо за роботу, $CADET_NAME!${NC}"
        echo -e "  ${DIM}Практикуйтесь щодня — і Linux стане другою натурою. 🐧${NC}"
        echo ""
    fi
}

# ═══════════════════════════════════════════════════════════════
#  МЕНЮ ВИБОРУ РОЗДІЛІВ
# ═══════════════════════════════════════════════════════════════

section_menu() {
    clear
    print_header
    echo -e "  ${BOLD}Оберіть режим тестування, ${CADET_NAME}:${NC}"
    echo ""
    echo -e "  ${CYAN}1)${NC} Повне тестування (всі розділи)"
    echo -e "  ${CYAN}2)${NC} Розділ 1: APT — пакетний менеджер"
    echo -e "  ${CYAN}3)${NC} Розділ 2: Спільні бібліотеки"
    echo -e "  ${CYAN}4)${NC} Розділ 3: Встановлення з вихідного коду"
    echo -e "  ${CYAN}5)${NC} Розділ 4: Текстові редактори (nano та vim)"
    echo -e "  ${CYAN}6)${NC} Розділ 5: Потокові редактори (sed та awk)"
    echo -e "  ${CYAN}7)${NC} Розділ 6: Практичний блок"
    echo -e "  ${CYAN}8)${NC} Розділ 7: Блискавичне опитування"
    echo -e "  ${CYAN}0)${NC} Вихід"
    echo ""
    echo -ne "  ${YELLOW}▶ Ваш вибір [0-8]: ${NC}"
    read -r MENU_CHOICE

    case "$MENU_CHOICE" in
        1)
            section1
            section2
            section3
            section4
            section5
            section6
            section7
            final_report
            ;;
        2) section1; final_report ;;
        3) section2; final_report ;;
        4) section3; final_report ;;
        5) section4; final_report ;;
        6) section5; final_report ;;
        7) section6; final_report ;;
        8) section7; final_report ;;
        0)
            echo -e "\n  ${DIM}До побачення!${NC}\n"
            exit 0
            ;;
        *)
            echo -e "  ${RED}Невірний вибір${NC}"
            sleep 1
            section_menu
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════
#  ГОЛОВНА ФУНКЦІЯ
# ═══════════════════════════════════════════════════════════════

main() {
    intro
    section_menu
}

# Запуск
main
