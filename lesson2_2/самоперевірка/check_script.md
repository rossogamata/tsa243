# Автоматична перевірка лабораторної роботи

## Інструкція

1.  Збережіть скрипт як `check_lab.sh`

2.  Надайте права на виконання:

    ``` bash
    chmod +x check_lab.sh
    ```

3.  Запустіть:

    ``` bash
    ./check_lab.sh
    ```

------------------------------------------------------------------------

## Скрипт перевірки

``` bash
#!/bin/bash

TOTAL=0
MAX=100

if [ -d "project" ]; then
    ((TOTAL+=10))
fi

FILE_COUNT=$(find project -maxdepth 1 -type f 2>/dev/null | wc -l)
if [ "$FILE_COUNT" -ge 3 ]; then
    ((TOTAL+=15))
fi

PERMISSION_CHECK=true
for f in project/*; do
    if [ -f "$f" ]; then
        PERM=$(stat -c "%a" "$f")
        if [ "$PERM" != "740" ]; then
            PERMISSION_CHECK=false
        fi
    fi
done

if $PERMISSION_CHECK; then
    ((TOTAL+=20))
fi

ARCHIVE=$(ls *.tar.gz 2>/dev/null | head -n 1)
if [ -n "$ARCHIVE" ]; then
    ((TOTAL+=15))
    tar -tzf "$ARCHIVE" | grep -q "project" && ((TOTAL+=15))
fi

SYMLINK_FOUND=false
for f in *; do
    if [ -L "$f" ]; then
        TARGET=$(readlink "$f")
        if [ "$TARGET" == "$ARCHIVE" ]; then
            SYMLINK_FOUND=true
        fi
    fi
done

if $SYMLINK_FOUND; then
    ((TOTAL+=15))
fi

ps aux | grep "sleep 600" | grep -v grep > /dev/null
if [ $? -ne 0 ]; then
    ((TOTAL+=10))
fi

echo "Результат: $TOTAL / $MAX"
```
