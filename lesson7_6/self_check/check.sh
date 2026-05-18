#!/bin/bash
# =============================================================
#  check.sh — Самоперевірка заняття 7_6: Nginx
#  ЗАНЯТТЯ 6 (Групове) — Конфігурація веб-сервера Nginx
#  Курс: ТСА-243 | ВІТІ | 2026
# =============================================================

set -euo pipefail

# ── Кольори ──────────────────────────────────────────────────
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

# ── Визначити IP ──────────────────────────────────────────────
MY_IP=$(hostname -I | awk '{print $1}')

echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   Самоперевірка: ЗАНЯТТЯ 7_6 — Nginx   ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo "  IP сервера: ${MY_IP}"
echo "  Дата:       $(date '+%Y-%m-%d %H:%M:%S')"

# ═════════════════════════════════════════════════════════════
hdr "1. Nginx встановлено та запущено"
# ═════════════════════════════════════════════════════════════

if command -v nginx &>/dev/null; then
    ok "nginx встановлено ($(nginx -v 2>&1 | grep -oP 'nginx/[\d.]+'))"
else
    fail "nginx не знайдено — виконайте: sudo apt install nginx"
fi

if systemctl is-active --quiet nginx; then
    ok "Служба nginx активна"
else
    fail "Служба nginx не запущена — виконайте: sudo systemctl start nginx"
fi

if systemctl is-enabled --quiet nginx; then
    ok "nginx увімкнено в автозапуск"
else
    fail "nginx не увімкнено в автозапуск — виконайте: sudo systemctl enable nginx"
fi

# ═════════════════════════════════════════════════════════════
hdr "2. Порти та синтаксис конфігурації"
# ═════════════════════════════════════════════════════════════

if sudo nginx -t &>/dev/null; then
    ok "Синтаксис конфігурації Nginx без помилок"
else
    fail "Помилка синтаксису Nginx — виконайте: sudo nginx -t"
fi

if ss -tulnp 2>/dev/null | grep -q ':80.*nginx'; then
    ok "Nginx слухає порт 80"
else
    fail "Nginx НЕ слухає порт 80"
fi

if ss -tulnp 2>/dev/null | grep -q ':443.*nginx'; then
    ok "Nginx слухає порт 443"
else
    fail "Nginx НЕ слухає порт 443"
fi

# ═════════════════════════════════════════════════════════════
hdr "3. HTTP → HTTPS редирект"
# ═════════════════════════════════════════════════════════════

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${MY_IP}" --max-time 5 2>/dev/null || echo "000")
case "$HTTP_CODE" in
    301) ok "HTTP повертає 301 Moved Permanently (редирект на HTTPS)" ;;
    302) ok "HTTP повертає 302 Found (редирект, але краще 301)" ;;
    200) fail "HTTP повертає 200 — редирект на HTTPS не налаштовано" ;;
    000) fail "Немає відповіді на порту 80 (таймаут або відхилено)" ;;
    *)   fail "HTTP повертає ${HTTP_CODE} (очікувався 301)" ;;
esac

LOCATION=$(curl -sI "http://${MY_IP}" --max-time 5 2>/dev/null | grep -i "^location" | tr -d '\r' || true)
if echo "$LOCATION" | grep -qi "https://"; then
    ok "Заголовок Location вказує на HTTPS: $LOCATION"
else
    fail "Заголовок Location не містить https:// (або редиректу немає)"
fi

# ═════════════════════════════════════════════════════════════
hdr "4. HTTPS (TLS)"
# ═════════════════════════════════════════════════════════════

HTTPS_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://${MY_IP}" --max-time 5 2>/dev/null || echo "000")
if [[ "$HTTPS_CODE" == "200" ]]; then
    ok "HTTPS повертає 200 OK"
else
    fail "HTTPS повертає ${HTTPS_CODE} (очікувався 200)"
fi

# Перевірити TLS протокол
TLS_VERSION=$(echo | openssl s_client -connect "${MY_IP}:443" 2>/dev/null | grep "Protocol" | awk '{print $3}' || true)
if [[ "$TLS_VERSION" == "TLSv1.3" || "$TLS_VERSION" == "TLSv1.2" ]]; then
    ok "TLS протокол: ${TLS_VERSION}"
else
    fail "Слабкий або невизначений TLS протокол: ${TLS_VERSION:-невідомо}"
fi

# Перевірити сертифікат
CERT_SUBJECT=$(echo | openssl s_client -connect "${MY_IP}:443" 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null | sed 's/subject=//' || true)
if [[ -n "$CERT_SUBJECT" ]]; then
    ok "Сертифікат знайдено: ${CERT_SUBJECT}"
else
    fail "Не вдалося отримати сертифікат від ${MY_IP}:443"
fi

# Термін дії сертифіката
CERT_END=$(echo | openssl s_client -connect "${MY_IP}:443" 2>/dev/null \
    | openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//' || true)
if [[ -n "$CERT_END" ]]; then
    ok "Термін дії сертифіката: ${CERT_END}"
else
    info "Не вдалося визначити термін дії сертифіката"
fi

# ═════════════════════════════════════════════════════════════
hdr "5. Заголовки безпеки"
# ═════════════════════════════════════════════════════════════

HEADERS=$(curl -skI "https://${MY_IP}" --max-time 5 2>/dev/null || true)

if echo "$HEADERS" | grep -qi "strict-transport-security"; then
    ok "HSTS заголовок присутній (Strict-Transport-Security)"
else
    fail "HSTS заголовок відсутній — додайте: add_header Strict-Transport-Security \"max-age=63072000\" always"
fi

if echo "$HEADERS" | grep -qi "x-content-type-options"; then
    ok "X-Content-Type-Options заголовок присутній"
else
    info "X-Content-Type-Options відсутній (рекомендовано додати)"
fi

if echo "$HEADERS" | grep -qi "x-frame-options"; then
    ok "X-Frame-Options заголовок присутній"
else
    info "X-Frame-Options відсутній (рекомендовано додати)"
fi

# ═════════════════════════════════════════════════════════════
hdr "6. Конфігураційні файли"
# ═════════════════════════════════════════════════════════════

if [[ -f /etc/nginx/nginx.conf ]]; then
    ok "/etc/nginx/nginx.conf існує"
else
    fail "/etc/nginx/nginx.conf не знайдено"
fi

ENABLED_SITES=$(ls /etc/nginx/sites-enabled/ 2>/dev/null | grep -v "^$" || true)
if [[ -n "$ENABLED_SITES" ]]; then
    ok "Активні сайти в sites-enabled: $(echo $ENABLED_SITES | tr '\n' ' ')"
else
    fail "Немає активних сайтів у /etc/nginx/sites-enabled/"
fi

if [[ -d /etc/nginx/ssl ]] && ls /etc/nginx/ssl/*.crt &>/dev/null 2>&1; then
    ok "Каталог /etc/nginx/ssl/ з сертифікатами існує"
else
    fail "Каталог /etc/nginx/ssl/ або сертифікати не знайдено"
fi

# Перевірити права на ключ
KEY_FILE=$(ls /etc/nginx/ssl/*.key 2>/dev/null | head -1 || true)
if [[ -n "$KEY_FILE" ]]; then
    KEY_PERMS=$(stat -c "%a" "$KEY_FILE" 2>/dev/null || true)
    if [[ "$KEY_PERMS" == "600" ]]; then
        ok "Права на приватний ключ: 600 (коректно)"
    else
        fail "Права на приватний ключ: ${KEY_PERMS} (має бути 600)"
    fi
fi

# ═════════════════════════════════════════════════════════════
hdr "7. Логування"
# ═════════════════════════════════════════════════════════════

if [[ -d /var/log/nginx ]]; then
    ok "/var/log/nginx/ існує"
else
    fail "/var/log/nginx/ не знайдено"
fi

if ls /var/log/nginx/access.log &>/dev/null 2>&1 || \
   ls /var/log/nginx/*.access.log &>/dev/null 2>&1; then
    ok "access.log знайдено в /var/log/nginx/"
else
    fail "access.log не знайдено в /var/log/nginx/"
fi

if ls /var/log/nginx/error.log &>/dev/null 2>&1 || \
   ls /var/log/nginx/*.error.log &>/dev/null 2>&1; then
    ok "error.log знайдено в /var/log/nginx/"
else
    fail "error.log не знайдено в /var/log/nginx/"
fi

# ═════════════════════════════════════════════════════════════
hdr "Результати"
# ═════════════════════════════════════════════════════════════

TOTAL=$((PASS + FAIL))
echo ""
echo -e "  Виконано перевірок: ${TOTAL}"
echo -e "  ${GREEN}Пройдено:  ${PASS}${NC}"
echo -e "  ${RED}Провалено: ${FAIL}${NC}"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}  Всі перевірки пройдено успішно!${NC}"
elif [[ $FAIL -le 2 ]]; then
    echo -e "${YELLOW}${BOLD}  Майже! Виправте вказані помилки.${NC}"
else
    echo -e "${RED}${BOLD}  Є помилки — перевірте конфігурацію.${NC}"
fi

echo ""
echo "  Для детальної діагностики:"
echo "    sudo nginx -t"
echo "    sudo journalctl -u nginx --since '10 min ago'"
echo ""

exit $FAIL
