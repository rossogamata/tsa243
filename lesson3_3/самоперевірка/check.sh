#!/bin/bash
# ============================================================
#  check.sh — Інтерактивний скрипт самоперевірки
#  Тема: Розмітка, монтування та моніторинг ФС Linux
#  Курс: 2-й курс | Ubuntu Server 24.04.4 LTS
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
NC='\033[0m' # No Color

# ─── Глобальні змінні ────────────────────────────────────────
SCORE=0
MAX_SCORE=0
WRONG=0
SECTION_SCORE=0
SECTION_MAX=0
CADET_NAME=""
LOG_FILE="/tmp/linux_check_$(date +%Y%m%d_%H%M%S).log"

# ─── Допоміжні функції ───────────────────────────────────────

print_header() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║     🐧  LINUX — САМОПЕРЕВІРКА ЗНАНЬ  🐧                    ║"
    echo "║     Файлова система: розмітка, монтування, моніторинг       ║"
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
    # $1 — текст питання, $2 — правильна відповідь (regex), $3 — пояснення, $4 — підказка
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
    # $1 — питання, $2 — варіанти (a|b|c|d), $3 — правильна літера, $4 — пояснення
    echo -e "\n  ${BOLD}❓ $1${NC}"
    echo ""
    # Виводимо варіанти
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
    # Питання з множинним вибором (введіть через кому)
    echo -e "\n  ${BOLD}❓ $1${NC}"
    echo -e "  ${DIM}(Введіть літери відповідей через кому, наприклад: a,c)${NC}"
    echo ""
    IFS='|' read -ra OPTIONS <<< "$2"
    LETTERS=("a" "b" "c" "d" "e")
    for i in "${!OPTIONS[@]}"; do
        echo -e "    ${BOLD}${LETTERS[$i]})${NC} ${OPTIONS[$i]}"
    done
    echo ""
    echo -ne "  ${YELLOW}▶ Ваш вибір: ${NC}"
    read -r USER_CHOICES
    # Нормалізуємо: видаляємо пробіли, сортуємо
    USER_SORTED=$(echo "$USER_CHOICES" | tr -d ' ' | tr ',' '\n' | tr '[:upper:]' '[:lower:]' | sort | tr '\n' ',' | sed 's/,$//')
    CORRECT_SORTED=$(echo "$3" | tr -d ' ' | tr ',' '\n' | tr '[:upper:]' '[:lower:]' | sort | tr '\n' ',' | sed 's/,$//')
    if [[ "$USER_SORTED" == "$CORRECT_SORTED" ]]; then
        correct "$4" "$1"
    else
        wrong "$3" "$4"
    fi
}

ask_practical() {
    # Практичне завдання — перевіряємо реальний стан системи
    echo -e "\n  ${BOLD}🔧 ПРАКТИЧНЕ ЗАВДАННЯ: $1${NC}"
    echo -e "  ${DIM}$2${NC}"
    echo ""
    echo -ne "  ${YELLOW}▶ Натисніть Enter після виконання (або 's' для пропуску): ${NC}"
    read -r PRAC_ANSWER
    if [[ "$PRAC_ANSWER" == "s" || "$PRAC_ANSWER" == "S" ]]; then
        echo -e "  ${DIM}⏭  Завдання пропущено${NC}"
        return 2
    fi
    # Перевіряємо результат за допомогою $3 — команда перевірки
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
    echo -e "  Цей скрипт перевірить ваші знання з трьох тем:"
    echo -e "    ${CYAN}1.${NC} Розмітка дискового простору"
    echo -e "    ${CYAN}2.${NC} Монтування розділів"
    echo -e "    ${CYAN}3.${NC} Моніторинг файлової системи"
    echo ""
    echo -e "  ${DIM}Формат: теоретичні питання + практичні перевірки${NC}"
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
#  РОЗДІЛ 1: РОЗМІТКА ДИСКОВОГО ПРОСТОРУ
# ═══════════════════════════════════════════════════════════════

section1() {
    print_section "РОЗДІЛ 1: Розмітка дискового простору"

    ask_choice \
        "Яка утиліта використовується для розмітки дисків з підтримкою GPT і MBR?" \
        "fdisk|parted|mkfs|lsblk" \
        "b" \
        "parted підтримує обидва формати (MBR та GPT), тоді як fdisk традиційно асоціюється з MBR, хоча сучасні версії також підтримують GPT."

    ask_choice \
        "Яка команда в інтерактивному режимі fdisk ЗАПИСУЄ зміни на диск?" \
        "q — вийти без збереження|p — показати розділи|w — записати і вийти|n — новий розділ" \
        "c" \
        "Команда 'w' (write) записує нову таблицю розділів на диск. 'q' виходить БЕЗ збереження."

    ask_question \
        "Яка команда fdisk показує список доступних підкоманд у інтерактивному режимі?" \
        "^m$" \
        "Клавіша 'm' відображає меню допомоги (menu) з усіма доступними командами." \
        "Одна літера, викликає меню довідки"

    ask_choice \
        "Яка файлова система використовується для розділу EFI (ESP)?" \
        "ext4|xfs|FAT32 (vfat)|swap" \
        "c" \
        "Розділ EFI System Partition ЗАВЖДИ форматується у FAT32. Це вимога стандарту UEFI."

    ask_question \
        "Яка команда форматує розділ у файлову систему ext4?" \
        "mkfs\.ext4|mkfs -t ext4" \
        "mkfs.ext4 /dev/sdXN — основна команда для форматування у ext4." \
        "Починається з 'mkfs'"

    ask_choice \
        "Яка схема розмітки підтримує диски більше 2 ТБ?" \
        "MBR (Master Boot Record)|GPT (GUID Partition Table)|FAT16|Extended partition" \
        "b" \
        "GPT (GUID Partition Table) підтримує диски до 9.4 ЗБ і до 128 основних розділів. MBR обмежений 2 ТБ і 4 основними розділами."

    ask_multichoice \
        "Оберіть ВСІ правильні команди для перегляду таблиці розділів:" \
        "fdisk -l|mkfs -l|parted -l|lsblk" \
        "a,c,d" \
        "fdisk -l, parted -l та lsblk — коректні команди для перегляду розділів. mkfs — команда форматування, без опції -l для розділів."

    ask_question \
        "Яка команда використовується для створення swap-розділу на /dev/sdb3?" \
        "mkswap" \
        "mkswap /dev/sdb3 — підготовлює розділ як swap. Після цього swapon /dev/sdb3 активує його." \
        "Починається з 'mk...'"

    ask_choice \
        "Яка опція mkfs.ext4 встановлює мітку (label) тому?" \
        "-L|--label разом|тільки -n|-t" \
        "a" \
        "Опція -L задає мітку: mkfs.ext4 -L 'MYDATA' /dev/sdb1"

    ask_practical \
        "Перегляньте список блокових пристроїв" \
        "Виконайте команду: lsblk" \
        "lsblk" \
        "lsblk виводить дерево блокових пристроїв (диски та розділи)"

    section_result
}

# ═══════════════════════════════════════════════════════════════
#  РОЗДІЛ 2: МОНТУВАННЯ РОЗДІЛІВ
# ═══════════════════════════════════════════════════════════════

section2() {
    print_section "РОЗДІЛ 2: Монтування розділів"

    ask_choice \
        "Де зазвичай розміщують тимчасові точки монтування в Linux?" \
        "/dev/|/mnt/ або /media/|/etc/|/sys/" \
        "b" \
        "/mnt/ — стандартне місце для тимчасового монтування адміністратором. /media/ — для знімних носіїв (USB, CD)."

    ask_question \
        "Яка команда монтує всі файлові системи, вказані у /etc/fstab?" \
        "mount -a" \
        "'mount -a' (all) зчитує /etc/fstab і монтує всі незмонтовані системи. Корисно після редагування fstab." \
        "mount з певним ключем"

    ask_choice \
        "Що ОБОВ'ЯЗКОВО потрібно зробити перед розмонтуванням розділу?" \
        "Вимкнути комп'ютер|Переконатися, що розділ не використовується|Відформатувати розділ|Видалити всі файли"  \
        "b" \
        "Якщо файлова система зайнята (open files, активний каталог), umount поверне помилку 'target is busy'. Використовуйте lsof або fuser для пошуку."

    ask_question \
        "Яка команда показує дерево всіх точок монтування?" \
        "findmnt" \
        "findmnt виводить зручне дерево монтування. Можна фільтрувати: findmnt /dev/sda1" \
        "Утиліта, яка 'знаходить' точки монтування"

    ask_question \
        "Який файл відповідає за автоматичне монтування розділів при завантаженні системи?" \
        "/etc/fstab" \
        "/etc/fstab (filesystem table) — таблиця файлових систем. Systemd читає його при завантаженні та виконує монтування." \
        "Знаходиться у /etc/"

    ask_choice \
        "Який ідентифікатор КРАЩЕ використовувати у fstab для надійного монтування?" \
        "/dev/sdb1 (назва пристрою)|UUID=... (унікальний ідентифікатор)|Мітка тому (LABEL=)|Будь-який варіант однаковий" \
        "b" \
        "UUID — найнадійніший варіант. Назви /dev/sdX можуть змінюватися після перезавантаження або додавання нових дисків. UUID завжди унікальний."

    ask_choice \
        "Яка опція монтування у fstab запобігає зупинці завантаження при відсутності розділу?" \
        "defaults|noauto|nofail|ro" \
        "c" \
        "'nofail' — якщо пристрій недоступний, система завантажиться без помилок. Корисно для змінних дисків або NAS."

    ask_question \
        "Яка команда показує UUID усіх розділів?" \
        "blkid|sudo blkid" \
        "sudo blkid виводить UUID, тип ФС та мітку кожного розділу. Без sudo може не бачити деякі пристрої." \
        "Починається з 'bl...'"

    ask_practical \
        "Перегляньте поточні точки монтування" \
        "Виконайте команду: findmnt або mount | grep sda" \
        "findmnt" \
        "findmnt — зручне дерево, mount — класичний список"

    ask_choice \
        "Яка команда отримує UUID конкретного розділу /dev/sdb1?" \
        "lsblk /dev/sdb1|blkid -s UUID -o value /dev/sdb1|fdisk -l /dev/sdb1|tune2fs /dev/sdb1" \
        "b" \
        "blkid -s UUID -o value /dev/sdb1 виводить ТІЛЬКИ UUID без зайвого тексту. Зручно для скриптів: UUID=\$(blkid -s UUID -o value /dev/sdb1)"

    ask_practical \
        "Перевірте вміст файлу /etc/fstab" \
        "Виконайте: cat /etc/fstab" \
        "[ -f /etc/fstab ]" \
        "cat /etc/fstab — вивести вміст, або less /etc/fstab для великих файлів"

    section_result
}

# ═══════════════════════════════════════════════════════════════
#  РОЗДІЛ 3: МОНІТОРИНГ ФАЙЛОВОЇ СИСТЕМИ
# ═══════════════════════════════════════════════════════════════

section3() {
    print_section "РОЗДІЛ 3: Моніторинг файлової системи"

    ask_choice \
        "Яка команда показує ВІЛЬНЕ місце на всіх змонтованих дисках у зручному форматі?" \
        "du -h|df -h|ls -lh|free -h" \
        "b" \
        "df -h (disk free, human-readable) — класична команда для перегляду вільного місця. du — для розміру каталогів."

    ask_question \
        "Яка команда показує розмір каталогу /var у зручному вигляді?" \
        "du -sh /var" \
        "du -sh /var: -s (summary — підсумок без вкладень), -h (human-readable: KB/MB/GB)." \
        "Утиліта du з двома ключами"

    ask_choice \
        "Що показує команда 'df -hT'?" \
        "Тільки розмір у терабайтах|Вільне місце + тип файлової системи|Список тимчасових файлів|Деталі конкретного тому" \
        "b" \
        "Опція -T додає колонку з типом ФС (ext4, xfs, tmpfs тощо). -h — людиночитаний формат."

    ask_question \
        "Яка команда знаходить топ-10 найбільших каталогів у корені / ?" \
        "du -h --max-depth=1 / .*sort -rh.*head|du -h --max-depth=1 /.*sort.*head" \
        "du -h --max-depth=1 / 2>/dev/null | sort -rh | head -10" \
        "Комбінація du + sort + head"

    ask_choice \
        "Яку утиліту використовують для перевірки (і виправлення) пошкодженої файлової системи?" \
        "fdisk|tune2fs|fsck|mkfs" \
        "c" \
        "fsck (filesystem check) — універсальна утиліта перевірки. e2fsck — специфічна для ext2/3/4. ВАЖЛИВО: запускати тільки на НЕзмонтованому розділі!"

    ask_choice \
        "Коли БЕЗПЕЧНО запускати fsck для перевірки файлової системи?" \
        "Під час активної роботи системи|Тільки якщо розділ НЕ змонтований|Тільки для root-розділу|Будь-коли" \
        "b" \
        "fsck на змонтованій FS може призвести до корупції даних! Для перевірки root-розділу: або завантажитись з live-USB, або система перевірить автоматично при наступному завантаженні."

    ask_practical \
        "Перевірте вільне місце на дисках" \
        "Виконайте команду: df -hT" \
        "df -h" \
        "df -h або df -hT (з типом ФС)"

    ask_question \
        "Яка команда lsblk показує файлову систему та UUID кожного розділу?" \
        "lsblk -f" \
        "lsblk -f виводить додаткові колонки: FSTYPE (тип ФС), LABEL (мітка), UUID, MOUNTPOINT." \
        "lsblk з одним ключем"

    ask_choice \
        "Яка утиліта дозволяє переглянути параметри ext4 файлової системи (кількість монтувань, UUID тощо)?" \
        "fsck|tune2fs -l|blkid -v|parted info" \
        "b" \
        "tune2fs -l /dev/sdXN виводить детальну інформацію про ext2/3/4 ФС: UUID, кількість монтувань, дату останньої перевірки тощо."

    ask_choice \
        "Яка команда моніторить I/O-активність процесів у реальному часі?" \
        "iostat|iotop|df -i|lsblk -m" \
        "b" \
        "iotop (потребує sudo та встановлення пакету) — аналог top, але для дискового I/O. iostat — статистика без поділу по процесах."

    ask_practical \
        "Знайдіть 5 найбільших об'єктів у /var" \
        "Виконайте: sudo du -sh /var/* 2>/dev/null | sort -rh | head -5" \
        "du -sh /var 2>/dev/null" \
        "du -sh /var/* | sort -rh | head -5 — з сортуванням за розміром"

    ask_multichoice \
        "Які команди відображають інформацію про UUID розділів? (виберіть всі правильні)" \
        "lsblk -f|fdisk -n|blkid|ls /dev/disk/by-uuid/" \
        "a,c,d" \
        "lsblk -f, blkid та ls /dev/disk/by-uuid/ — всі показують UUID. fdisk -n не є коректною командою для цього."

    section_result
}

# ═══════════════════════════════════════════════════════════════
#  РОЗДІЛ 4: ПРАКТИЧНИЙ БЛОК (перевірка системи)
# ═══════════════════════════════════════════════════════════════

section4() {
    print_section "РОЗДІЛ 4: Практичний блок — дослідження системи"

    echo -e "  ${DIM}У цьому розділі ви досліджуєте реальний стан вашої системи.${NC}"
    echo -e "  ${DIM}Для кожного завдання виконайте команду і дайте відповідь на питання.${NC}"
    echo ""

    # Практичне 1
    echo -e "  ${BOLD}🔧 Завдання 1: Дослідження дисків${NC}"
    echo -e "  ${DIM}Виконайте: lsblk -f${NC}"
    echo ""
    echo -ne "  ${YELLOW}▶ Скільки дисків бачить ваша система? ${NC}"
    read -r ANS1
    if echo "$ANS1" | grep -qE "^[1-9][0-9]*$"; then
        echo -e "  ${GREEN}✅ Відповідь записана: $ANS1 дисків${NC}"
        ((SCORE++)); ((MAX_SCORE++)); ((SECTION_SCORE++)); ((SECTION_MAX++))
    else
        echo -e "  ${YELLOW}⚠️  Введіть число! Виконайте lsblk і порахуйте рядки sd* або vd*${NC}"
        ((MAX_SCORE++)); ((SECTION_MAX++)); ((WRONG++))
    fi

    # Практичне 2
    echo ""
    echo -e "  ${BOLD}🔧 Завдання 2: Аналіз fstab${NC}"
    echo -e "  ${DIM}Виконайте: cat /etc/fstab${NC}"
    echo ""
    FSTAB_LINES=$(grep -v "^#" /etc/fstab | grep -v "^$" | wc -l)
    echo -ne "  ${YELLOW}▶ Скільки активних (не закоментованих) рядків у /etc/fstab? ${NC}"
    read -r ANS2
    if [[ "$ANS2" == "$FSTAB_LINES" ]]; then
        correct "Правильно! У /etc/fstab $FSTAB_LINES активних записів." "fstab lines"
    else
        wrong "$FSTAB_LINES" "Правильна відповідь: $FSTAB_LINES рядків (grep -v '^#' /etc/fstab | grep -v '^$' | wc -l)"
    fi

    # Практичне 3
    echo ""
    echo -e "  ${BOLD}🔧 Завдання 3: Вільне місце${NC}"
    echo -e "  ${DIM}Виконайте: df -h /${NC}"
    echo ""
    ROOT_FREE=$(df -h / | awk 'NR==2 {print $4}')
    echo -e "  ${DIM}Фактично вільно на /: ${BOLD}$ROOT_FREE${NC}"
    echo -ne "  ${YELLOW}▶ Скільки відсотків використано на кореневому розділі /? (число) ${NC}"
    read -r ANS3
    ROOT_PERCENT=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
    if [[ "$ANS3" == "$ROOT_PERCENT" ]] || [[ "$ANS3%" == "$ROOT_PERCENT%" ]]; then
        correct "Правильно! Використано $ROOT_PERCENT%" "root usage"
    else
        wrong "$ROOT_PERCENT%" "df / | awk 'NR==2 {print \$5}' → $ROOT_PERCENT%"
    fi

    # Практичне 4 — визначення ФС
    echo ""
    echo -e "  ${BOLD}🔧 Завдання 4: Тип файлової системи${NC}"
    echo -e "  ${DIM}Виконайте: lsblk -f | head -5${NC}"
    echo ""
    ROOT_FS=$(findmnt -n -o FSTYPE /)
    echo -ne "  ${YELLOW}▶ Який тип файлової системи встановлений на кореневому розділі /? ${NC}"
    read -r ANS4
    ANS4_LOWER=$(echo "$ANS4" | tr '[:upper:]' '[:lower:]' | xargs)
    ROOT_FS_LOWER=$(echo "$ROOT_FS" | tr '[:upper:]' '[:lower:]')
    if [[ "$ANS4_LOWER" == "$ROOT_FS_LOWER" ]]; then
        correct "Правильно! Коренева ФС: $ROOT_FS" "root fs type"
    else
        wrong "$ROOT_FS" "findmnt -n -o FSTYPE / → $ROOT_FS"
    fi

    section_result
}

# ═══════════════════════════════════════════════════════════════
#  РОЗДІЛ 5: БЛИСКАВИЧНЕ ОПИТУВАННЯ (швидкі питання)
# ═══════════════════════════════════════════════════════════════

section5() {
    print_section "РОЗДІЛ 5: ⚡ Блискавичне опитування"
    echo -e "  ${DIM}Швидкі питання — відповідайте одним словом або командою${NC}"
    echo ""

    ask_question "Яка команда активує swap-розділ?" \
        "swapon" \
        "swapon /dev/sdXN активує swap. swapoff — деактивує." \
        "sw..."

    ask_question "Якою командою примусово розмонтувати зайнятий розділ (lazy)?" \
        "umount -l" \
        "umount -l (lazy) розмонтовує ФС при першій можливості, коли вона перестане використовуватись." \
        "umount з ключем -l"

    ask_question "Як дивитись тільки реальні ФС у df, виключаючи tmpfs?" \
        "df -h -x tmpfs|df.*-x tmpfs" \
        "df -h -x tmpfs -x devtmpfs — виключить псевдо-ФС tmpfs та devtmpfs." \
        "df -h з ключем для виключення"

    ask_question "Яка утиліта є інтерактивним монітором дискового I/O?" \
        "iotop" \
        "iotop — як top, але показує дискову активність. Потребує sudo." \
        "Аналог top для диску"

    ask_question "Яка команда дає змогу дізнатись UUID всіх блокових пристроїв?" \
        "blkid|sudo blkid" \
        "sudo blkid виводить UUID, LABEL, TYPE для всіх розділів." \
        "bl..."

    ask_question "Яка директорія містить символічні посилання на розділи за UUID?" \
        "/dev/disk/by-uuid" \
        "ls /dev/disk/by-uuid/ — показує всі UUID у вигляді символічних посилань на /dev/sdX." \
        "/dev/disk/..."

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

    # Оцінка
    echo -e "  ──────────────────────────────────────────────"
    if [ "$PERCENT" -ge 90 ]; then
        GRADE="ВІДМІННО"
        GRADE_COLOR="$GREEN"
        EMOJI="🏆"
        COMMENT="Чудова робота! Ви відмінно засвоїли матеріал."
    elif [ "$PERCENT" -ge 75 ]; then
        GRADE="ДОБРЕ"
        GRADE_COLOR="$CYAN"
        EMOJI="🎯"
        COMMENT="Гарний результат! Повторіть теми з помилками."
    elif [ "$PERCENT" -ge 60 ]; then
        GRADE="ЗАДОВІЛЬНО"
        GRADE_COLOR="$YELLOW"
        EMOJI="📚"
        COMMENT="Матеріал засвоєно частково. Рекомендується додаткове опрацювання."
    else
        GRADE="НЕЗАДОВІЛЬНО"
        GRADE_COLOR="$RED"
        EMOJI="⚠️"
        COMMENT="Необхідно повторити матеріал. Перечитайте README.md та конспект."
    fi

    echo ""
    echo -e "  $EMOJI  ${GRADE_COLOR}${BOLD}$GRADE ($PERCENT%)${NC}"
    echo ""
    echo -e "  ${DIM}$COMMENT${NC}"
    echo ""

    # Рекомендації
    echo -e "  ──────────────────────────────────────────────"
    echo -e "  ${BOLD}📝 Рекомендовані команди для повторення:${NC}"
    echo ""
    echo -e "  ${DIM}lsblk -f          — структура дисків${NC}"
    echo -e "  ${DIM}sudo fdisk -l     — таблиця розділів${NC}"
    echo -e "  ${DIM}df -hT            — вільне місце + тип ФС${NC}"
    echo -e "  ${DIM}du -sh /var/*     — розміри каталогів${NC}"
    echo -e "  ${DIM}cat /etc/fstab    — таблиця автомонтування${NC}"
    echo -e "  ${DIM}sudo blkid        — UUID розділів${NC}"
    echo -e "  ${DIM}findmnt           — дерево монтування${NC}"
    echo ""

    # Зберегти звіт
    {
        echo "=== ПІДСУМОК ==="
        echo "Курсант: $CADET_NAME"
        echo "Дата: $(date)"
        echo "Результат: $SCORE/$MAX_SCORE ($PERCENT%)"
        echo "Оцінка: $GRADE"
    } >> "$LOG_FILE"

    echo -e "  ${DIM}Детальний журнал збережено: $LOG_FILE${NC}"
    echo ""

    # Пропозиція повторити
    echo -ne "  ${YELLOW}▶ Бажаєте пройти тест повторно? [y/N]: ${NC}"
    read -r REPEAT
    if [[ "$REPEAT" =~ ^[yYтТ] ]]; then
        SCORE=0; MAX_SCORE=0; WRONG=0; SECTION_SCORE=0; SECTION_MAX=0
        main
    else
        echo ""
        echo -e "  ${GREEN}${BOLD}Дякуємо за роботу, $CADET_NAME!${NC}"
        echo -e "  ${DIM}Продовжуйте практикуватись у роботі з Linux! 🐧${NC}"
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
    echo -e "  ${CYAN}2)${NC} Розділ 1: Розмітка дискового простору"
    echo -e "  ${CYAN}3)${NC} Розділ 2: Монтування розділів"
    echo -e "  ${CYAN}4)${NC} Розділ 3: Моніторинг файлової системи"
    echo -e "  ${CYAN}5)${NC} Розділ 4: Практичний блок"
    echo -e "  ${CYAN}6)${NC} Розділ 5: Блискавичне опитування"
    echo -e "  ${CYAN}0)${NC} Вихід"
    echo ""
    echo -ne "  ${YELLOW}▶ Ваш вибір [0-6]: ${NC}"
    read -r MENU_CHOICE

    case "$MENU_CHOICE" in
        1)
            section1
            section2
            section3
            section4
            section5
            final_report
            ;;
        2) section1; final_report ;;
        3) section2; final_report ;;
        4) section3; final_report ;;
        5) section4; final_report ;;
        6) section5; final_report ;;
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
