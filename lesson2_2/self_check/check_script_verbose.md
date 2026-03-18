# Автоматична перевірка лабораторної роботи (Verbose версія)

## Інструкція

1. Збережіть скрипт як `check_lab.sh`
2. Надайте права на виконання:
   chmod +x check_lab.sh
3. Запустіть:
   ./check_lab.sh

---

## Скрипт перевірки (розширена деталізація)

```bash
#!/bin/bash

echo "===== АВТОПЕРЕВІРКА ЛАБОРАТОРНОЇ РОБОТИ ====="
echo

TOTAL=0
MAX=100

echo "1) Перевірка каталогу project (10 балів)"
if [ -d "project" ]; then
    echo "   ✔ Каталог існує (+10)"
    ((TOTAL+=10))
else
    echo "   ✘ Каталог відсутній (+0)"
fi
echo

echo "2) Перевірка кількості файлів (15 балів)"
FILE_COUNT=$(find project -maxdepth 1 -type f 2>/dev/null | wc -l)

if [ "$FILE_COUNT" -ge 3 ]; then
    echo "   ✔ Знайдено $FILE_COUNT файлів (+15)"
    ((TOTAL+=15))
else
    echo "   ✘ Знайдено лише $FILE_COUNT файлів (+0)"
fi
echo

echo "3) Перевірка прав доступу 740 (20 балів)"
PERMISSION_CHECK=true

for f in project/*; do
    if [ -f "$f" ]; then
        PERM=$(stat -c "%a" "$f")
        echo "   Файл $f має права $PERM"
        if [ "$PERM" != "740" ]; then
            PERMISSION_CHECK=false
        fi
    fi
done

if $PERMISSION_CHECK; then
    echo "   ✔ Усі файли мають правильні права (+20)"
    ((TOTAL+=20))
else
    echo "   ✘ Є файли з неправильними правами (+0)"
fi
echo

echo "4) Перевірка наявності tar.gz архіву (15 балів)"
ARCHIVE=$(ls *.tar.gz 2>/dev/null | head -n 1)

if [ -n "$ARCHIVE" ]; then
    echo "   ✔ Знайдено архів $ARCHIVE (+15)"
    ((TOTAL+=15))
else
    echo "   ✘ Архів не знайдено (+0)"
fi
echo

echo "5) Перевірка вмісту архіву (15 балів)"
if [ -n "$ARCHIVE" ]; then
    tar -tzf "$ARCHIVE" | grep -q "project"
    if [ $? -eq 0 ]; then
        echo "   ✔ Архів містить каталог project (+15)"
        ((TOTAL+=15))
    else
        echo "   ✘ Архів не містить каталог project (+0)"
    fi
else
    echo "   ✘ Перевірка неможлива (архів відсутній) (+0)"
fi
echo

echo "6) Перевірка символічного посилання (15 балів)"
SYMLINK_FOUND=false

for f in *; do
    if [ -L "$f" ]; then
        TARGET=$(readlink "$f")
        echo "   Знайдено symlink $f -> $TARGET"
        if [ "$TARGET" == "$ARCHIVE" ]; then
            SYMLINK_FOUND=true
        fi
    fi
done

if $SYMLINK_FOUND; then
    echo "   ✔ Символічне посилання правильне (+15)"
    ((TOTAL+=15))
else
    echo "   ✘ Правильне символічне посилання не знайдено (+0)"
fi
echo

echo "7) Перевірка відсутності процесу sleep 600 (10 балів)"
ps aux | grep "sleep 600" | grep -v grep > /dev/null

if [ $? -ne 0 ]; then
    echo "   ✔ Процес не запущений (+10)"
    ((TOTAL+=10))
else
    echo "   ✘ Процес sleep 600 досі працює (+0)"
fi
echo

echo "===== ПІДСУМОК ====="
echo "Набрано балів: $TOTAL / $MAX"

if [ "$TOTAL" -ge 90 ]; then
    echo "Оцінка: Відмінно"
elif [ "$TOTAL" -ge 75 ]; then
    echo "Оцінка: Добре"
elif [ "$TOTAL" -ge 60 ]; then
    echo "Оцінка: Задовільно"
else
    echo "Оцінка: Незадовільно"
fi
```
