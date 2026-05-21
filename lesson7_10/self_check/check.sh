#!/bin/bash
# Скрипт самоперевірки — lesson7_10 HAProxy
# Виконувати на HAProxy VM (11.203.X.13)
# Використання: sudo ./check.sh [номер_варіанта]

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

ok()   { echo -e "${GREEN}[OK]${NC}   $1"; ((PASS++)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)); }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

# Визначити X (номер варіанта) — з аргументу або з IP
if [[ -n "${1:-}" ]]; then
    X="$1"
else
    X=$(hostname -I | grep -oP '11\.203\.\K\d+' | head -1)
    if [[ -z "$X" ]]; then
        echo "Не вдалося визначити номер варіанта автоматично."
        echo "Запустіть: sudo ./check.sh <номер_варіанта>"
        exit 1
    fi
fi

echo "=================================================="
echo "  Самоперевірка lesson7_10 — HAProxy"
echo "  Варіант: ${X} | HAProxy VM: 11.203.${X}.13"
echo "=================================================="
echo

BACKEND1="11.203.${X}.30"
BACKEND2="11.203.${X}.31"
HAPROXY="11.203.${X}.13"

# 1. HAProxy встановлено
info "Перевірка встановлення HAProxy..."
if command -v haproxy &>/dev/null; then
    VERSION=$(haproxy -v 2>&1 | head -1)
    ok "HAProxy встановлено: ${VERSION}"
else
    fail "HAProxy не встановлено"
fi

# 2. Служба активна
info "Перевірка статусу служби..."
if systemctl is-active --quiet haproxy; then
    ok "Служба haproxy активна (running)"
else
    fail "Служба haproxy не запущена"
fi

# 3. Автозапуск
if systemctl is-enabled --quiet haproxy; then
    ok "Автозапуск haproxy увімкнено (enabled)"
else
    fail "Автозапуск haproxy не увімкнено — виконайте: sudo systemctl enable haproxy"
fi

# 4. Порт 80
info "Перевірка портів..."
if ss -tulnp 2>/dev/null | grep -q ':80.*haproxy'; then
    ok "HAProxy слухає порт 80"
else
    fail "HAProxy не слухає порт 80"
fi

# 5. Порт 8404 (stats)
if ss -tulnp 2>/dev/null | grep -q ':8404.*haproxy'; then
    ok "HAProxy слухає порт 8404 (stats)"
else
    fail "HAProxy не слухає порт 8404 — перевірте секцію 'listen stats' у конфізі"
fi

# 6. Синтаксис конфігу
info "Перевірка синтаксису конфігурації..."
if haproxy -c -f /etc/haproxy/haproxy.cfg &>/dev/null; then
    ok "Конфігурація /etc/haproxy/haproxy.cfg валідна"
else
    fail "Помилка синтаксису в /etc/haproxy/haproxy.cfg"
fi

# 7. Наявність backend-ів у конфізі
info "Перевірка конфігурації backend-ів..."
if grep -q "${BACKEND1}:8080" /etc/haproxy/haproxy.cfg; then
    ok "Backend-01 (${BACKEND1}:8080) присутній у конфізі"
else
    fail "Backend-01 (${BACKEND1}:8080) відсутній у конфізі"
fi

if grep -q "${BACKEND2}:8080" /etc/haproxy/haproxy.cfg; then
    ok "Backend-02 (${BACKEND2}:8080) присутній у конфізі"
else
    fail "Backend-02 (${BACKEND2}:8080) відсутній у конфізі"
fi

# 8. health check налаштований
if grep -q "httpchk" /etc/haproxy/haproxy.cfg; then
    ok "HTTP health check (option httpchk) налаштований"
else
    fail "HTTP health check не налаштований — додайте 'option httpchk GET /health'"
fi

# 9. Backend-01 доступний
info "Перевірка доступності backend-ів..."
if curl -sf --max-time 3 "http://${BACKEND1}:8080/health" | grep -q "OK"; then
    ok "Backend-01 (${BACKEND1}:8080) відповідає на /health"
else
    fail "Backend-01 (${BACKEND1}:8080) не відповідає — перевірте Nginx на backend-01"
fi

# 10. Backend-02 доступний
if curl -sf --max-time 3 "http://${BACKEND2}:8080/health" | grep -q "OK"; then
    ok "Backend-02 (${BACKEND2}:8080) відповідає на /health"
else
    fail "Backend-02 (${BACKEND2}:8080) не відповідає — перевірте Nginx на backend-02"
fi

# 11. HAProxy балансує між обома backend-ами
info "Перевірка балансування навантаження..."
SEEN_BACKENDS=$(for i in {1..6}; do
    curl -s --max-time 3 "http://${HAPROXY}/" 2>/dev/null | grep -o 'BACKEND-[0-9]*' || true
done | sort | uniq | tr '\n' ' ')

if echo "$SEEN_BACKENDS" | grep -q "BACKEND-01" && echo "$SEEN_BACKENDS" | grep -q "BACKEND-02"; then
    ok "Балансування працює: відповіли обидва backend (${SEEN_BACKENDS})"
elif echo "$SEEN_BACKENDS" | grep -q "BACKEND"; then
    fail "Відповідає лише один backend: ${SEEN_BACKENDS} (перевірте health check)"
else
    fail "Жоден backend не відповів через HAProxy — перевірте конфіг та статус backend-ів"
fi

# 12. Stats сторінка доступна
info "Перевірка панелі статистики..."
if curl -sf --max-time 3 "http://${HAPROXY}:8404/stats" | grep -q "HAProxy"; then
    ok "Панель статистики доступна: http://${HAPROXY}:8404/stats"
else
    fail "Панель статистики недоступна — перевірте секцію 'listen stats'"
fi

# Підсумок
echo
echo "=================================================="
printf "  Результат: ${GREEN}%d OK${NC} / ${RED}%d FAIL${NC}\n" "$PASS" "$FAIL"
echo "=================================================="

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}  Всі перевірки пройдено успішно!${NC}"
    exit 0
else
    echo -e "${RED}  Є помилки — виправте та запустіть перевірку повторно.${NC}"
    exit 1
fi
