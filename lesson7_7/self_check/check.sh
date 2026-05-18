#!/bin/bash
# =============================================================
#  check.sh — Самоперевірка заняття 7_7
#  ЗАНЯТТЯ 7 (Практичне) — Встановлення та налаштування Nginx
#  Курс: ТСА-243 | ВІТІ | 2026
# =============================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}  [OK]${NC}  $1"; ((PASS++)); }
fail() { echo -e "${RED}  [!!]${NC}  $1"; ((FAIL++)); }
info() { echo -e "${YELLOW}  [--]${NC}  $1"; }
hdr()  { echo -e "\n${CYAN}${BOLD}══ $1 ══${NC}"; }

PASS=0
FAIL=0

MY_IP=$(hostname -I | awk '{print $1}')

echo -e "${BOLD}"
echo "  ╔════════════════════════════════════════════╗"
echo "  ║  Самоперевірка: ЗАНЯТТЯ 7_7 — Nginx Lab  ║"
echo "  ╚════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  IP сервера: ${MY_IP}"
echo "  Дата:       $(date '+%Y-%m-%d %H:%M:%S')"

# ─── 1. Встановлення ─────────────────────────────────────────
hdr "1. Nginx встановлено та активно"

if command -v nginx &>/dev/null; then
    VER=$(nginx -v 2>&1 | grep -oP 'nginx/[\d.]+')
    ok "nginx встановлено (${VER})"
else
    fail "nginx не знайдено — виконайте: sudo apt install nginx"
fi

if systemctl is-active --quiet nginx; then
    ok "Служба nginx активна"
else
    fail "Служба nginx не запущена"
fi

if systemctl is-enabled --quiet nginx; then
    ok "nginx увімкнено в автозапуск"
else
    fail "nginx не увімкнено в автозапуск — sudo systemctl enable nginx"
fi

if sudo nginx -t &>/dev/null; then
    ok "Синтаксис усіх конфігурацій без помилок"
else
    fail "Помилка синтаксису — запустіть: sudo nginx -t"
fi

# ─── 2. Порт 80 ──────────────────────────────────────────────
hdr "2. Порт 80"

if ss -tulnp 2>/dev/null | grep -q ':80.*nginx'; then
    ok "Nginx слухає порт 80"
else
    fail "Nginx НЕ слухає порт 80"
fi

# Переконатися, що default-сайт вимкнено
if [[ -L /etc/nginx/sites-enabled/default ]]; then
    fail "Сайт 'default' все ще активний — виконайте: sudo rm /etc/nginx/sites-enabled/default"
else
    ok "Сайт 'default' деактивовано"
fi

# ─── 3. Конфігурації sites-available ─────────────────────────
hdr "3. Конфігурації Virtual Hosts"

for CONF in www info proxy; do
    if [[ -f /etc/nginx/sites-available/${CONF}.conf ]]; then
        ok "sites-available/${CONF}.conf існує"
    else
        fail "sites-available/${CONF}.conf НЕ знайдено"
    fi
done

# ─── 4. Симлінки sites-enabled ───────────────────────────────
hdr "4. Активні сайти (sites-enabled)"

for CONF in www info proxy; do
    if [[ -L /etc/nginx/sites-enabled/${CONF}.conf ]]; then
        TARGET=$(readlink /etc/nginx/sites-enabled/${CONF}.conf)
        ok "sites-enabled/${CONF}.conf → ${TARGET}"
    else
        fail "sites-enabled/${CONF}.conf відсутній — виконайте: sudo ln -s /etc/nginx/sites-available/${CONF}.conf /etc/nginx/sites-enabled/"
    fi
done

# ─── 5. Контент сайтів ───────────────────────────────────────
hdr "5. Файли контенту"

for DIR in /var/www/www /var/www/info; do
    if [[ -f "${DIR}/index.html" ]]; then
        ok "${DIR}/index.html існує"
    else
        fail "${DIR}/index.html не знайдено"
    fi
done

if [[ -f /var/www/info/404.html ]]; then
    ok "/var/www/info/404.html (кастомна сторінка 404) існує"
else
    fail "/var/www/info/404.html не знайдено"
fi

# ─── 6. Відповіді сайтів за заголовком Host ──────────────────
hdr "6. HTTP-відповіді від сайтів"

# Читаємо server_name з конфігів, щоб не хардкодити X
WWW_HOST=$(grep -h "server_name" /etc/nginx/sites-available/www.conf  2>/dev/null | awk '{print $2}' | tr -d ';' | head -1)
INFO_HOST=$(grep -h "server_name" /etc/nginx/sites-available/info.conf 2>/dev/null | awk '{print $2}' | tr -d ';' | head -1)
PROXY_HOST=$(grep -h "server_name" /etc/nginx/sites-available/proxy.conf 2>/dev/null | awk '{print $2}' | tr -d ';' | head -1)

for ENTRY in "${WWW_HOST}:www" "${INFO_HOST}:info"; do
    HOST="${ENTRY%%:*}"
    LABEL="${ENTRY##*:}"
    if [[ -z "$HOST" ]]; then
        info "Не вдалося визначити server_name для ${LABEL}.conf"
        continue
    fi
    CODE=$(curl -s -o /dev/null -w "%{http_code}" \
           -H "Host: ${HOST}" http://localhost --max-time 5 2>/dev/null || echo "000")
    if [[ "$CODE" == "200" ]]; then
        ok "${HOST} → HTTP ${CODE}"
    else
        fail "${HOST} → HTTP ${CODE} (очікувався 200)"
    fi
done

# Сайт proxy може повертати 502, якщо HAProxy не запущено — це нормально
if [[ -n "$PROXY_HOST" ]]; then
    CODE=$(curl -s -o /dev/null -w "%{http_code}" \
           -H "Host: ${PROXY_HOST}" http://localhost --max-time 5 2>/dev/null || echo "000")
    if [[ "$CODE" == "200" ]]; then
        ok "${PROXY_HOST} → HTTP 200 (HAProxy доступний)"
    elif [[ "$CODE" == "502" || "$CODE" == "503" ]]; then
        ok "${PROXY_HOST} → HTTP ${CODE} (конфіг є, HAProxy недоступний — ОК для цього заняття)"
    elif [[ "$CODE" == "000" ]]; then
        fail "${PROXY_HOST} → немає відповіді (перевірте конфіг proxy.conf)"
    else
        info "${PROXY_HOST} → HTTP ${CODE} (нестандартна відповідь)"
    fi
fi

# ─── 7. Кастомна 404 ─────────────────────────────────────────
hdr "7. Кастомна сторінка 404"

if [[ -n "$INFO_HOST" ]]; then
    CODE=$(curl -s -o /dev/null -w "%{http_code}" \
           -H "Host: ${INFO_HOST}" http://localhost/nonexistent-page --max-time 5 2>/dev/null || echo "000")
    if [[ "$CODE" == "404" ]]; then
        ok "Сайт info повертає 404 для неіснуючих сторінок"
        # Перевірити чи повертається кастомний HTML (не стандартний nginx)
        BODY=$(curl -s -H "Host: ${INFO_HOST}" http://localhost/nonexistent-page --max-time 5 2>/dev/null || true)
        if echo "$BODY" | grep -qi "404\|знайдено\|not found"; then
            ok "Кастомна сторінка 404 містить правильний вміст"
        else
            info "Вміст сторінки 404 не перевірено (або порожній)"
        fi
    else
        fail "Сайт info повертає ${CODE} замість 404 для /nonexistent-page"
    fi
fi

# ─── 8. server_tokens ────────────────────────────────────────
hdr "8. Приховування версії (server_tokens off)"

HEADER_SERVER=$(curl -sI -H "Host: ${WWW_HOST:-localhost}" http://localhost --max-time 5 2>/dev/null \
    | grep -i "^server:" | tr -d '\r' || true)
if echo "$HEADER_SERVER" | grep -q "nginx/"; then
    fail "Заголовок Server розкриває версію Nginx: ${HEADER_SERVER} — додайте 'server_tokens off'"
else
    ok "Версія Nginx прихована в заголовку Server: ${HEADER_SERVER:-відсутній}"
fi

# ─── 9. Логи ─────────────────────────────────────────────────
hdr "9. Файли логів"

for LOGNAME in www info proxy; do
    ACCESS="/var/log/nginx/${LOGNAME}.access.log"
    ERROR="/var/log/nginx/${LOGNAME}.error.log"
    if [[ -f "$ACCESS" ]]; then
        ok "${ACCESS} існує"
    else
        fail "${ACCESS} не знайдено — перевірте директиву access_log у ${LOGNAME}.conf"
    fi
    if [[ -f "$ERROR" ]]; then
        ok "${ERROR} існує"
    else
        fail "${ERROR} не знайдено — перевірте директиву error_log у ${LOGNAME}.conf"
    fi
done

# ─── Підсумок ────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))
echo ""
echo -e "  ─────────────────────────────────"
echo -e "  Перевірок:  ${TOTAL}"
echo -e "  ${GREEN}Пройдено:   ${PASS}${NC}"
echo -e "  ${RED}Провалено:  ${FAIL}${NC}"
echo -e "  ─────────────────────────────────"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}  Відмінно! Всі перевірки пройдено.${NC}"
elif [[ $FAIL -le 3 ]]; then
    echo -e "${YELLOW}${BOLD}  Майже! Виправте вказані помилки та запустіть знову.${NC}"
else
    echo -e "${RED}${BOLD}  Є помилки — перегляньте кроки практичної роботи.${NC}"
fi

echo ""
echo "  Для діагностики:"
echo "    sudo nginx -t"
echo "    sudo nginx -T | grep -E 'server_name|listen|root|proxy_pass'"
echo "    sudo journalctl -u nginx --since '5 min ago'"
echo ""

exit $FAIL
