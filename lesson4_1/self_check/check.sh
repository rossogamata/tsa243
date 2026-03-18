#!/bin/bash
# ============================================================
#  летучка.sh — Швидка перевірка знань з попередніх занять
#  Охоплює: Заняття 2.2 та 3.3
#  Формат: 20 питань, ~5-7 хвилин, без меню
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

SCORE=0
TOTAL=0
CADET_NAME=""
Q_NUM=0

# ─── Функції ─────────────────────────────────────────────────

print_header() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║   ⚡  ЛЕТУЧКА — ПЕРЕВІРКА ЗНАНЬ З ПОПЕРЕДНІХ ЗАНЯТЬ  ⚡   ║"
    echo "║        Заняття 2.2 · Заняття 3.3  │  20 питань             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

divider() {
    echo -e "  ${DIM}──────────────────────────────────────────────────────${NC}"
}

topic_banner() {
    echo ""
    echo -e "  ${MAGENTA}${BOLD}▌ $1${NC}"
    echo ""
}

ask() {
    # $1 — питання, $2 — regex правильної відповіді, $3 — правильна відповідь (для показу), $4 — пояснення
    ((Q_NUM++))
    ((TOTAL++))
    echo -e "\n  ${BOLD}${CYAN}[$Q_NUM/20]${NC} ${BOLD}$1${NC}"
    echo -ne "  ${YELLOW}▶ ${NC}"
    read -r ANS
    ANS_NORM=$(echo "$ANS" | tr '[:upper:]' '[:lower:]' | xargs)
    if echo "$ANS_NORM" | grep -qiE "$2"; then
        echo -e "  ${GREEN}${BOLD}✅ Правильно!${NC}  ${DIM}$4${NC}"
        ((SCORE++))
    else
        echo -e "  ${RED}${BOLD}❌ Неправильно.${NC}  Відповідь: ${YELLOW}${BOLD}$3${NC}"
        echo -e "  ${DIM}$4${NC}"
    fi
    sleep 0.3
}

choose() {
    # $1 — питання, $2 — варіанти через |, $3 — правильна літера, $4 — пояснення
    ((Q_NUM++))
    ((TOTAL++))
    echo -e "\n  ${BOLD}${CYAN}[$Q_NUM/20]${NC} ${BOLD}$1${NC}"
    echo ""
    IFS='|' read -ra OPTS <<< "$2"
    LETTERS=("a" "b" "c" "d")
    for i in "${!OPTS[@]}"; do
        echo -e "    ${BOLD}${LETTERS[$i]})${NC} ${OPTS[$i]}"
    done
    echo ""
    echo -ne "  ${YELLOW}▶ [a-${LETTERS[$((${#OPTS[@]}-1))]}]: ${NC}"
    read -r ANS
    ANS_NORM=$(echo "$ANS" | tr '[:upper:]' '[:lower:]' | xargs)
    CORRECT_NORM=$(echo "$3" | tr '[:upper:]' '[:lower:]')
    if [[ "$ANS_NORM" == "$CORRECT_NORM" ]]; then
        echo -e "  ${GREEN}${BOLD}✅ Правильно!${NC}  ${DIM}$4${NC}"
        ((SCORE++))
    else
        IDX=$(echo "$CORRECT_NORM" | tr 'abcd' '0123')
        echo -e "  ${RED}${BOLD}❌ Неправильно.${NC}  Відповідь: ${YELLOW}${BOLD}${3}) ${OPTS[$IDX]}${NC}"
        echo -e "  ${DIM}$4${NC}"
    fi
    sleep 0.3
}

progress() {
    local done=$1 total=$2 width=30
    local filled=$((done * width / total))
    local empty=$((width - filled))
    printf "  ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %d/%d\n" "$done" "$total"
}

# ═══════════════════════════════════════════════════════════════
#  СТАРТ
# ═══════════════════════════════════════════════════════════════

print_header

echo -e "  ${BOLD}Перед початком нового заняття — швидка перевірка!${NC}"
echo ""
echo -e "  ${DIM}Питання без варіантів: відповідайте командою або ключовим словом.${NC}"
echo -e "  ${DIM}Питання з варіантами: вводьте літеру (a/b/c/d).${NC}"
echo ""
echo -ne "  ${YELLOW}▶ Ваше прізвище: ${NC}"
read -r CADET_NAME
[ -z "$CADET_NAME" ] && CADET_NAME="Курсант"
echo ""
echo -e "  ${GREEN}Починаємо, ${BOLD}$CADET_NAME${NC}${GREEN}! Успіхів! ⚡${NC}"
sleep 1

# ═══════════════════════════════════════════════════════════════
#  БЛОК 1: ЗАНЯТТЯ 2.2 — ПРОЦЕСИ, АРХІВИ, ПРАВА
# ═══════════════════════════════════════════════════════════════

topic_banner "БЛОК 1 / Заняття 2.2 — Процеси, архіви, права доступу"
divider

ask \
    "Яка команда виводить список усіх запущених процесів у розгорнутому форматі?" \
    "ps aux" \
    "ps aux" \
    "ps aux — усі процеси (a), включно з іншими користувачами (u), без терміналу (x)."

choose \
    "Який сигнал примусово завершує процес без можливості перехоплення?" \
    "SIGTERM (15)|SIGKILL (9)|SIGSTOP (19)|SIGHUP (1)" \
    "b" \
    "SIGKILL (9) — неперехоплюваний сигнал. kill -9 PID або kill -SIGKILL PID."

ask \
    "Яка команда показує дерево процесів (ієрархію батько→дитина)?" \
    "ps -ejH|pstree" \
    "ps -ejH  або  pstree" \
    "ps -ejH або pstree — наочно показують, який процес породив який."

ask \
    "Запишіть команду для створення архіву tar.gz з директорії 'project':" \
    "tar -czvf.*project\.tar\.gz.*project|tar.*czf.*project" \
    "tar -czvf project.tar.gz project" \
    "-c створити, -z gzip-стиснення, -v детально, -f ім'я файлу."

choose \
    "Що означають права доступу 740 у числовому записі?" \
    "власник: rwx, група: r--, інші: ---  |  власник: rw-, група: r--, інші: ---  |  власник: rwx, група: rw-, інші: r--  |  всі: rwx" \
    "a" \
    "7=rwx (4+2+1), 4=r-- (4+0+0), 0=--- (0). Власник: повний доступ, група: лише читання, інші: нічого."

ask \
    "Яка команда встановлює права 740 на всі файли у директорії project?" \
    "chmod 740 project/\*|chmod 740 project" \
    "chmod 740 project/*" \
    "chmod задає права у числовому (740) або символьному (u=rwx,g=r,o=) форматі."

ask \
    "Яка команда створює СИМВОЛІЧНЕ посилання з іменем 'link' на файл 'project.tar.gz'?" \
    "ln -s project\.tar\.gz link|ln -s.*project" \
    "ln -s project.tar.gz link" \
    "ln -s (symbolic) — символічне. ln без -s — жорстке (hard link)."

choose \
    "Яка різниця між символічним та жорстким посиланням?" \
    "Немає різниці|Символічне — це посилання на шлях, жорстке — на inode файлу|Жорстке — це посилання на шлях, символічне — на inode|Тільки жорсткі можна видаляти" \
    "b" \
    "Символічне (soft) вказує на шлях — якщо оригінал видалити, посилання 'зламається'. Жорстке вказує на inode — оригінал і посилання рівноцінні."

ask \
    "Як запустити процес у фоновому режимі?" \
    "&$|.*&" \
    "команда &  (амперсанд після команди)" \
    "sleep 300 & — запускає процес у фоні, shell одразу повертає PID."

ask \
    "Яка команда переглядає ВМІСТ архіву tar.gz без розпакування?" \
    "tar -tzf|tar -tf" \
    "tar -tzf archive.tar.gz" \
    "-t (list), -z (gzip), -f (file). Аналог: tar tf archive.tar.gz"

echo ""
divider
BLOCK1_SCORE=$SCORE
echo -e "  ${BOLD}Результат блоку 1: ${CYAN}$BLOCK1_SCORE / 10${NC}"
divider
echo ""
echo -ne "  ${DIM}Натисніть Enter для продовження...${NC}"
read -r

# ═══════════════════════════════════════════════════════════════
#  БЛОК 2: ЗАНЯТТЯ 3.3 — ФАЙЛОВА СИСТЕМА
# ═══════════════════════════════════════════════════════════════

topic_banner "БЛОК 2 / Заняття 3.3 — Файлова система: розмітка, монтування, моніторинг"
divider

ask \
    "Яка команда показує дерево блокових пристроїв (диски та розділи)?" \
    "lsblk" \
    "lsblk" \
    "lsblk (list block devices) — наочне дерево дисків. lsblk -f — додає тип ФС та UUID."

choose \
    "Яка схема розмітки підтримує диски понад 2 ТБ і до 128 розділів?" \
    "MBR|GPT|FAT32|ext4" \
    "b" \
    "GPT (GUID Partition Table) — сучасний стандарт. MBR обмежений 2 ТБ і лише 4 основними розділами."

ask \
    "Яка команда в інтерактивному режимі fdisk ЗАПИСУЄ зміни і виходить?" \
    "^w$" \
    "w  (write)" \
    "w — записати нову таблицю розділів. q — вийти БЕЗ збереження. Не плутайте!"

ask \
    "Яка команда форматує розділ /dev/sdb1 у файлову систему ext4?" \
    "mkfs\.ext4 /dev/sdb1|mkfs -t ext4" \
    "mkfs.ext4 /dev/sdb1" \
    "mkfs.ext4 — для ext4, mkfs.xfs — для xfs, mkswap — для swap."

choose \
    "Де краще вказувати розділ у /etc/fstab для надійного автомонтування?" \
    "/dev/sdb1 (назва пристрою)|UUID=... (унікальний ідентифікатор)|Номер inode|LABEL= (мітка тому)" \
    "b" \
    "UUID незмінний. Назва /dev/sdb1 може змінитись після додавання нового диска або перезавантаження."

ask \
    "Яка команда отримує UUID усіх розділів системи?" \
    "blkid|sudo blkid" \
    "sudo blkid" \
    "blkid виводить UUID, тип ФС (TYPE) та мітку (LABEL) кожного розділу."

ask \
    "Яка команда монтує ВСЕ, що вказано у /etc/fstab?" \
    "mount -a|sudo mount -a" \
    "sudo mount -a" \
    "mount -a (all) — читає fstab і монтує всі незмонтовані системи. Корисно після редагування fstab."

choose \
    "Яка команда показує вільне місце на дисках у зручному форматі?" \
    "du -h /|df -h|ls -lh|free -h" \
    "b" \
    "df -h (disk free, human-readable). df -hT — додає тип ФС. du — для розміру конкретних каталогів."

ask \
    "Яка команда показує розмір каталогу /var одним числом у зручному форматі?" \
    "du -sh /var" \
    "du -sh /var" \
    "du -s (summary — без вкладень), -h (human-readable). Приклад результату: 1.2G /var"

choose \
    "Коли МОЖНА безпечно запускати fsck для перевірки файлової системи?" \
    "У будь-який час, це безпечно|Тільки на НЕзмонтованому розділі|Тільки від root під час роботи|Тільки після форматування" \
    "b" \
    "fsck на змонтованій ФС може зіпсувати дані! Для перевірки root-розділу використовують live-USB або перевірку при завантаженні."

echo ""
divider
BLOCK2_SCORE=$((SCORE - BLOCK1_SCORE))
echo -e "  ${BOLD}Результат блоку 2: ${CYAN}$BLOCK2_SCORE / 10${NC}"
divider

# ═══════════════════════════════════════════════════════════════
#  ПІДСУМОК
# ═══════════════════════════════════════════════════════════════

echo ""
clear
print_header

PERCENT=$((SCORE * 100 / TOTAL))

echo -e "  ${BOLD}📊 РЕЗУЛЬТАТИ ЛЕТУЧКИ${NC}"
echo ""
echo -e "  Курсант: ${BOLD}$CADET_NAME${NC}"
echo -e "  Дата:    $(date '+%d.%m.%Y %H:%M')"
echo ""
echo -e "  Блок 1 (Зан. 2.2 — процеси/архіви/права):   ${CYAN}${BOLD}$BLOCK1_SCORE / 10${NC}"
echo -e "  Блок 2 (Зан. 3.3 — файлова система):        ${CYAN}${BOLD}$BLOCK2_SCORE / 10${NC}"
echo ""
echo -ne "  Загальний прогрес: "
progress "$SCORE" "$TOTAL"
echo ""
echo -e "  ${BOLD}Загальний результат: ${NC}"
echo ""

if [ "$PERCENT" -ge 90 ]; then
    echo -e "  🏆  ${GREEN}${BOLD}ВІДМІННО — $SCORE/$TOTAL ($PERCENT%)${NC}"
    echo -e "  ${DIM}Матеріал засвоєно на відмінно. Готові до нової теми!${NC}"
elif [ "$PERCENT" -ge 75 ]; then
    echo -e "  🎯  ${CYAN}${BOLD}ДОБРЕ — $SCORE/$TOTAL ($PERCENT%)${NC}"
    echo -e "  ${DIM}Гарний результат! Перегляньте питання, де помилилися.${NC}"
elif [ "$PERCENT" -ge 60 ]; then
    echo -e "  📚  ${YELLOW}${BOLD}ЗАДОВІЛЬНО — $SCORE/$TOTAL ($PERCENT%)${NC}"
    echo -e "  ${DIM}Є прогалини. Рекомендується повторити README попередніх занять.${NC}"
else
    echo -e "  ⚠️   ${RED}${BOLD}НЕЗАДОВІЛЬНО — $SCORE/$TOTAL ($PERCENT%)${NC}"
    echo -e "  ${DIM}Необхідно повторити матеріал занять 2.2 та 3.3 перед продовженням.${NC}"
fi

echo ""
echo -e "  ${DIM}──────────────────────────────────────────────────────${NC}"
echo ""
echo -e "  ${BOLD}Нагадування ключових команд:${NC}"
echo ""
echo -e "  ${DIM}ps aux          kill -9 PID      tar -czvf arch.tar.gz dir/${NC}"
echo -e "  ${DIM}chmod 740 file  ln -s target lnk  tar -tzf arch.tar.gz${NC}"
echo -e "  ${DIM}lsblk -f        sudo blkid        df -hT${NC}"
echo -e "  ${DIM}mkfs.ext4 /dev  sudo mount -a     du -sh /var${NC}"
echo ""
echo -e "  ${DIM}──────────────────────────────────────────────────────${NC}"
echo ""
echo -e "  ${GREEN}${BOLD}Дякуємо, $CADET_NAME! Переходимо до нового матеріалу. 🐧${NC}"
echo ""
