# 🐧 Заняття: Робота з файловою системою Linux
### Дисципліна: Основи операційних систем Linux
### Курс: 2-й | Програмне забезпечення: VirtualBox 7.2.6 + Ubuntu Server 24.04.4 LTS

---

## 📥 Завантаження програмного забезпечення

| Програма | Версія | Посилання | Розмір |
|---|---|---|---|
| **Oracle VirtualBox** | 7.2.6 (Windows) | [⬇ Завантажити](https://download.virtualbox.org/virtualbox/7.2.6/VirtualBox-7.2.6-170440-Win.exe) | ~110 МБ |
| **Oracle VirtualBox** | 7.2.6 (macOS Intel) | [⬇ Завантажити](https://download.virtualbox.org/virtualbox/7.2.6/VirtualBox-7.2.6-170440-OSX.dmg) | ~110 МБ |
| **VirtualBox Extension Pack** | 7.2.6 | [⬇ Завантажити](https://download.virtualbox.org/virtualbox/7.2.6/Oracle_VirtualBox_Extension_Pack-7.2.6.vbox-extpack) | ~20 МБ |
| **Ubuntu Server 24.04.4 LTS** | Noble Numbat | [⬇ Завантажити](https://releases.ubuntu.com/24.04.4/ubuntu-24.04.4-live-server-amd64.iso) | ~2.7 ГБ |

> 🔗 Офіційні сторінки: [virtualbox.org/wiki/Downloads](https://www.virtualbox.org/wiki/Downloads) | [ubuntu.com/download/server](https://ubuntu.com/download/server)

---

## 🖥️ Налаштування віртуальної машини

Перед початком заняття створіть ВМ з такими параметрами:

| Параметр | Значення |
|---|---|
| Тип ОС | Linux / Ubuntu (64-bit) |
| RAM | 2048 МБ (мінімум) |
| CPU | 2 ядра |
| Диск 1 (основний) | 20 ГБ (динамічний VDI) |
| Диск 2 (для практики) | 10 ГБ (динамічний VDI) |
| Мережа | NAT або Bridged |

> ⚠️ **Важливо:** Додайте другий віртуальний диск до ВМ (**Settings → Storage → Add Hard Disk**) перед запуском заняття!

---

## 📚 Навчальні питання

### Питання 1 — Розмітка дискового простору

#### 1.1 Схема розмітки під час встановлення Ubuntu Server

Під час інсталяції Ubuntu Server інсталятор **Subiquity** пропонує:
- **Guided (автоматична)** — система сама розмічає диск
- **Custom (ручна)** — курсант задає розділи вручну

**Рекомендована схема розмітки для лабораторної роботи:**

```
/dev/sda (20 ГБ):
├── /dev/sda1   512 МБ   EFI System Partition (FAT32)
├── /dev/sda2   1 ГБ     /boot (ext4)
├── /dev/sda3   2 ГБ     swap
└── /dev/sda4   ~16 ГБ  / (ext4)
```

#### 1.2 Утиліта `fdisk` — класична розмітка MBR/GPT

```bash
# Перегляд усіх дисків
sudo fdisk -l

# Перегляд конкретного диска
sudo fdisk -l /dev/sdb

# Запуск інтерактивної розмітки
sudo fdisk /dev/sdb
```

**Основні команди в інтерактивному режимі `fdisk`:**

| Команда | Дія |
|---|---|
| `m` | Допомога (список команд) |
| `p` | Вивести таблицю розділів |
| `n` | Створити новий розділ |
| `d` | Видалити розділ |
| `t` | Змінити тип розділу |
| `w` | Записати зміни і вийти |
| `q` | Вийти без збереження |

**Практика — розмітка `/dev/sdb`:**

```bash
sudo fdisk /dev/sdb
# Всередині fdisk:
# n → Enter → Enter → Enter → +5G   (перший розділ 5 ГБ)
# n → Enter → Enter → Enter → +3G   (другий розділ 3 ГБ)
# n → Enter → Enter → Enter → Enter (решта простору)
# p   (перевірити)
# w   (записати)
```

#### 1.3 Утиліта `parted` — GPT та великі диски

```bash
# Запуск інтерактивного режиму
sudo parted /dev/sdb

# Або неінтерактивно (один рядок):
sudo parted /dev/sdb mklabel gpt
sudo parted /dev/sdb mkpart primary ext4 1MiB 5GiB
sudo parted /dev/sdb mkpart primary ext4 5GiB 8GiB
sudo parted /dev/sdb mkpart primary linux-swap 8GiB 100%

# Перегляд результату
sudo parted /dev/sdb print
```

#### 1.4 Утиліта `gdisk` — розширена робота з GPT

```bash
sudo gdisk /dev/sdb
# Команди аналогічні до fdisk, але для GPT
# ? — список команд
# n — новий розділ
# w — записати
```

#### 1.5 Форматування розділів

```bash
# ext4 — найпоширеніша файлова система Linux
sudo mkfs.ext4 /dev/sdb1

# ext4 з міткою
sudo mkfs.ext4 -L "DATA" /dev/sdb1

# xfs — висока продуктивність
sudo mkfs.xfs /dev/sdb2

# FAT32 — для EFI або сумісності
sudo mkfs.vfat -F 32 /dev/sdb3

# Swap-розділ
sudo mkswap /dev/sdb4
sudo swapon /dev/sdb4
```

---

### Питання 2 — Монтування розділів

#### 2.1 Концепція монтування в Linux

У Linux **немає букв дисків** (C:, D:). Замість цього всі пристрої монтуються до єдиного дерева каталогів, починаючи від кореня `/`.

```
/                   ← корінь файлової системи
├── /boot           ← може бути окремим розділом
├── /home           ← може бути окремим розділом
├── /mnt/           ← точки монтування (тимчасові)
└── /media/         ← автоматичне монтування знімних носіїв
```

#### 2.2 Команда `mount` — ручне монтування

```bash
# Базовий синтаксис
sudo mount <пристрій> <точка_монтування>

# Створити точку монтування
sudo mkdir -p /mnt/disk2

# Змонтувати розділ
sudo mount /dev/sdb1 /mnt/disk2

# Монтування з вказанням типу ФС
sudo mount -t ext4 /dev/sdb1 /mnt/disk2

# Монтування з опціями (тільки читання)
sudo mount -o ro /dev/sdb1 /mnt/disk2

# Монтування ISO-образу
sudo mount -o loop ubuntu.iso /mnt/iso

# Переглянути змонтовані системи
mount | grep sdb
# або
findmnt
```

#### 2.3 Команда `umount` — розмонтування

```bash
# Розмонтувати за точкою монтування
sudo umount /mnt/disk2

# Розмонтувати за пристроєм
sudo umount /dev/sdb1

# Примусове розмонтування (якщо зайнятий)
sudo umount -f /mnt/disk2
sudo umount -l /mnt/disk2   # ліниве розмонтування
```

#### 2.4 Файл `/etc/fstab` — автоматичне монтування при завантаженні

```bash
# Переглянути поточний fstab
cat /etc/fstab
```

**Структура запису в `/etc/fstab`:**

```
# <пристрій>           <точка_монт.>  <тип_ФС>  <опції>        <dump>  <pass>
UUID=xxxx-xxxx         /              ext4      errors=remount-ro 0       1
UUID=yyyy-yyyy         /boot          ext4      defaults          0       2
UUID=zzzz-zzzz         /mnt/data      ext4      defaults,nofail   0       2
/dev/sdb2              none           swap      sw                0       0
```

**Отримати UUID розділу:**

```bash
sudo blkid
sudo blkid /dev/sdb1
# або
ls -la /dev/disk/by-uuid/
```

**Додати запис до fstab (приклад):**

```bash
# Отримуємо UUID
UUID=$(sudo blkid -s UUID -o value /dev/sdb1)
echo "UUID=$UUID /mnt/data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

# Перевірка без перезавантаження
sudo mount -a
```

> ⚠️ **Увага:** Помилка у `/etc/fstab` може призвести до неможливості завантаження системи! Завжди робіть резервну копію та перевіряйте синтаксис.

#### 2.5 `systemd.mount` — альтернатива fstab

```bash
# Переглянути всі точки монтування systemd
systemctl list-units --type=mount

# Статус конкретного монтування
systemctl status mnt-data.mount
```

---

### Питання 3 — Моніторинг файлової системи

#### 3.1 `df` — вільне місце на дисках

```bash
# Перегляд у людиночитаному форматі
df -h

# Тільки реальні файлові системи (без tmpfs)
df -h -x tmpfs -x devtmpfs

# Перегляд конкретного каталогу
df -h /home

# Показати тип файлової системи
df -hT
```

**Розшифровка виводу:**
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda4        16G  3.2G   12G  22% /
/dev/sda2       974M  201M  706M  22% /boot
```

#### 3.2 `du` — розмір каталогів та файлів

```bash
# Розмір каталогу (рекурсивно)
du -sh /var/log

# Топ-10 найбільших каталогів у /
du -h --max-depth=1 / 2>/dev/null | sort -rh | head -10

# Розмір конкретного файлу
du -h /var/log/syslog

# Усі файли у каталозі, сортовані за розміром
du -ah /var/log | sort -rh | head -20
```

#### 3.3 `lsblk` — структура блокових пристроїв

```bash
# Базовий вивід
lsblk

# З файловою системою та UUID
lsblk -f

# З розмірами та точками монтування
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,UUID
```

#### 3.4 `blkid` — інформація про розділи

```bash
# Всі розділи
sudo blkid

# Конкретний розділ
sudo blkid /dev/sdb1
```

#### 3.5 `fsck` — перевірка та відновлення файлової системи

```bash
# ⚠️ ВАЖЛИВО: запускати тільки на НЕзмонтованому розділі!

# Перевірка без виправлень
sudo fsck -n /dev/sdb1

# Автоматичне виправлення помилок
sudo fsck -y /dev/sdb1

# Для ext4
sudo e2fsck -f /dev/sdb1

# Примусова перевірка (навіть якщо "чиста")
sudo fsck -f /dev/sdb1
```

#### 3.6 `tune2fs` — параметри ext2/ext3/ext4

```bash
# Перегляд параметрів ФС
sudo tune2fs -l /dev/sda4

# Встановити мітку тому
sudo tune2fs -L "ROOT" /dev/sda4

# Встановити кількість монтувань до перевірки
sudo tune2fs -c 20 /dev/sda4

# Встановити часовий інтервал між перевірками
sudo tune2fs -i 30d /dev/sda4
```

#### 3.7 `iostat` та `iotop` — моніторинг I/O

```bash
# Встановлення інструментів
sudo apt install sysstat iotop -y

# Статистика дисків (оновлення кожні 2 секунди)
iostat -x 2

# Моніторинг процесів за I/O в реальному часі
sudo iotop

# Тільки активні процеси
sudo iotop -o
```

#### 3.8 `smartctl` — SMART-діагностика дисків

```bash
# Встановлення
sudo apt install smartmontools -y

# Перегляд SMART-інформації
sudo smartctl -i /dev/sda

# Короткий тест
sudo smartctl -t short /dev/sda

# Перегляд результатів
sudo smartctl -a /dev/sda
```

---

## 🔬 Лабораторні завдання

### Завдання 1 (Обов'язкове) — Розмітка другого диска

1. Підтвердіть наявність другого диска: `lsblk`
2. Розмітіть `/dev/sdb` за допомогою `fdisk`:
   - Розділ 1: 4 ГБ (тип: Linux filesystem)
   - Розділ 2: 3 ГБ (тип: Linux filesystem)
   - Розділ 3: 2 ГБ (тип: Linux swap)
3. Відформатуйте розділи:
   - `/dev/sdb1` → ext4 з міткою "PRACTICE"
   - `/dev/sdb2` → xfs з міткою "BACKUP"
   - `/dev/sdb3` → swap
4. Перевірте результат: `lsblk -f`

### Завдання 2 (Обов'язкове) — Монтування

1. Створіть точки монтування: `/mnt/practice` та `/mnt/backup`
2. Вручну змонтуйте обидва розділи
3. Перевірте монтування: `df -h` та `findmnt`
4. Додайте записи до `/etc/fstab` (через UUID)
5. Перевірте: `sudo umount /mnt/practice && sudo mount -a && df -h`

### Завдання 3 (Обов'язкове) — Моніторинг

1. Виконайте: `df -hT` — збережіть вивід
2. Визначте топ-5 каталогів за розміром у `/var`: `du -sh /var/* | sort -rh | head -5`
3. Перегляньте повну структуру дисків: `lsblk -f`
4. Зробіть перевірку ФС (розмонтуйте спочатку): `sudo fsck -n /dev/sdb1`

### Завдання 4 (Додаткове) ⭐

1. Встановіть `smartmontools` та проведіть діагностику диска
2. Налаштуйте автозапуск swap: перевірте що запис у `fstab` правильний
3. Дослідіть відмінності між `ext4` та `xfs` за допомогою `tune2fs` та `xfs_info`

---

## 📖 Корисні команди — шпаргалка

```bash
# ===== ДИСКИ =====
lsblk -f                          # структура дисків + ФС
sudo fdisk -l                     # список всіх дисків
sudo blkid                        # UUID та типи розділів
sudo parted -l                    # таблиця розділів (parted)

# ===== ПРОСТІР =====
df -hT                            # вільне місце + тип ФС
du -sh *                          # розміри у поточному каталозі
du -ah / | sort -rh | head -20    # топ-20 найбільших

# ===== МОНТУВАННЯ =====
mount | column -t                 # список змонтованих систем
findmnt                           # дерево монтування
sudo mount -a                     # змонтувати все з fstab

# ===== ПЕРЕВІРКА =====
sudo fsck -n /dev/sdXN            # перевірка (тільки читання)
sudo e2fsck -f /dev/sdXN          # перевірка ext4
sudo xfs_check /dev/sdXN          # перевірка xfs
```

---

## 🔗 Додаткові ресурси

- [Ubuntu Server Documentation](https://ubuntu.com/server/docs)
- [Linux man pages online](https://man7.org/linux/man-pages/)
- [Arch Linux Wiki — Partitioning](https://wiki.archlinux.org/title/Partitioning)
- [Arch Linux Wiki — fstab](https://wiki.archlinux.org/title/Fstab)
- [Red Hat — Storage Administration Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/managing_file_systems/)

---

## 📝 Самоперевірка

Для самоперевірки та закріплення матеріалу запустіть інтерактивний скрипт:

```bash
bash check.sh
```

> Файл `check.sh` знаходиться в цьому ж репозиторії.

---

*Заняття підготовлено для курсантів 2-го курсу | Ubuntu Server 24.04.4 LTS | VirtualBox 7.2.6*
