# Змістовий модуль 4 · Заняття 1 (Лекція)
## Системне програмне забезпечення

> **Курс:** Технології системного адміністрування 
> **Аудиторія:** Курсанти 2-го курсу (базові знання Linux)  
> **Тривалість:** 2 академічні години

---

## Навчальні питання

1. [Керування пакетами та системні бібліотеки ПЗ](#1-керування-пакетами-та-системні-бібліотеки-пз)
2. [Використання текстових редакторів](#2-використання-текстових-редакторів)

---

## 1. Керування пакетами та системні бібліотеки ПЗ

### 1.1 Що таке пакет?

**Пакет** — це архів, що містить:
- скомпільовані бінарні файли програми,
- конфігураційні файли,
- метадані (назва, версія, залежності),
- скрипти для встановлення / видалення.

Без пакетного менеджера адміністратор мав би вручну відстежувати сотні файлів і залежностей. Пакетний менеджер автоматизує цю роботу.

```
┌─────────────────────────────────────────────────────┐
│                  Репозиторій (сервер)               │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │  nginx   │  │   git    │  │  python3-requests│   │
│  └──────────┘  └──────────┘  └──────────────────┘   │
└────────────────────────┬────────────────────────────┘
                         │  apt install / yum install
                ┌────────▼────────┐
                │  Пакетний менед-│
                │  жер (APT/YUM)  │
                └────────┬────────┘
                         │  розпаковка + залежності
                ┌────────▼────────┐
                │  Ваша система   │
                └─────────────────┘
```

---

### 1.2 APT — Advanced Package Tool (Debian / Ubuntu / WSL)

APT використовується в дистрибутивах родини **Debian**: Ubuntu, Linux Mint, Kali Linux, а також у більшості WSL-середовищ за замовчуванням.

#### Основні команди APT

```bash
# Оновити список пакетів із репозиторіїв (не оновлює самі пакети!)
sudo apt update

# Оновити всі встановлені пакети до нових версій
sudo apt upgrade

# Встановити пакет
sudo apt install <назва-пакету>

# Видалити пакет (залишає конфіги)
sudo apt remove <назва-пакету>

# Видалити пакет разом із конфіг-файлами
sudo apt purge <назва-пакету>

# Видалити непотрібні залежності
sudo apt autoremove

# Пошук пакету за ключовим словом
apt search <ключове-слово>

# Переглянути інформацію про пакет
apt show <назва-пакету>

# Переглянути список встановлених пакетів
dpkg -l
dpkg -l | grep git      # відфільтрувати конкретний
```

#### Приклад: встановлення Git

```bash
$ sudo apt update
Hit:1 http://archive.ubuntu.com/ubuntu jammy InRelease
Get:2 http://archive.ubuntu.com/ubuntu jammy-updates InRelease [119 kB]
...
Fetched 3,421 kB in 2s (1,521 kB/s)
Reading package lists... Done

$ sudo apt install git
Reading package lists... Done
Building dependency tree... Done
The following NEW packages will be installed:
  git git-man liberror-perl
0 upgraded, 3 newly installed, 0 to remove and 5 not upgraded.
Need to get 4,182 kB of archives.
After this operation, 20.8 MB of additional disk space will be used.
Do you want to continue? [Y/n] Y
...
Setting up git (1:2.34.1-1ubuntu1.11) ...

$ git --version
git version 2.34.1
```

> ⚠️ **Важливо:** `apt update` лише оновлює **індекс** (список доступних пакетів). Без нього встановлення може завершитися помилкою або встановить застарілу версію.

---

### 1.3 Файл `/etc/apt/sources.list` — список репозиторіїв

APT знає, де шукати пакети, завдяки файлу **`/etc/apt/sources.list`** та директорії **`/etc/apt/sources.list.d/`**.

```bash
# Переглянути вміст
cat /etc/apt/sources.list
```

Типовий рядок репозиторію:

```
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
 │        │                            │      └──────────────────────────────┐
 │        │                            │      Компоненти (категорії пакетів) │
 │        │                            │                                      │
 │        │                            └── Кодова назва дистрибутиву          │
 │        └── URL репозиторію                                                  │
 └── Тип: deb (бінарний) або deb-src (вихідний код)
```

#### Компоненти Ubuntu

| Компонент    | Ліцензія     | Підтримка Canonical |
|-------------|---------------|---------------------|
| `main`      | Відкрита      | ✅ Офіційна         |
| `restricted`| Закрита       | ✅ Офіційна         |
| `universe`  | Відкрита      | Community           |
| `multiverse`| Закрита       | Community           |

#### Додавання стороннього репозиторію (PPA)

```bash
# Приклад: додати репозиторій Git (офіційний PPA)
sudo add-apt-repository ppa:git-core/ppa
sudo apt update
sudo apt install git
```

Після виконання цих команд у `/etc/apt/sources.list.d/` з'явиться новий файл:

```bash
ls /etc/apt/sources.list.d/
# git-core-ubuntu-ppa-jammy.list
```

---

### 1.4 YUM / DNF — Yellowdog Updater Modified (RHEL / CentOS / Fedora)

YUM (і його сучасна заміна **DNF**) використовуються в дистрибутивах родини **Red Hat**: RHEL, CentOS, Fedora, Rocky Linux, AlmaLinux.

```bash
# Оновити індекс та всі пакети
sudo yum update          # або: sudo dnf update

# Встановити пакет
sudo yum install <пакет>

# Видалити пакет
sudo yum remove <пакет>

# Пошук
yum search <ключове-слово>

# Інформація про пакет
yum info <пакет>

# Переглянути встановлені пакети
rpm -qa
rpm -qa | grep git
```

#### Репозиторії YUM

Конфіги репозиторіїв знаходяться у `/etc/yum.repos.d/`:

```bash
cat /etc/yum.repos.d/CentOS-Base.repo
```

```ini
[BaseOS]
name=CentOS Stream $releasever - BaseOS
baseurl=https://mirror.centos.org/centos/$releasever/BaseOS/$basearch/os/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
enabled=1
```

#### Порівняння APT та YUM/DNF

| Дія                  | APT (Debian/Ubuntu)         | YUM/DNF (RHEL/Fedora)      |
|---------------------|----------------------------|---------------------------|
| Оновити індекс       | `apt update`                | `dnf check-update`        |
| Встановити           | `apt install pkg`           | `dnf install pkg`         |
| Видалити             | `apt remove pkg`            | `dnf remove pkg`          |
| Пошук                | `apt search kw`             | `dnf search kw`           |
| Інфо про пакет       | `apt show pkg`              | `dnf info pkg`            |
| Список встановлених  | `dpkg -l`                   | `rpm -qa`                 |
| Формат пакету        | `.deb`                      | `.rpm`                    |
| Конфіг репозиторіїв  | `/etc/apt/sources.list`     | `/etc/yum.repos.d/*.repo` |

---

### 1.5 Встановлення пакету з архіву (з вихідного коду)

Іноді потрібна версія пакету, якої немає у репозиторіях, або потрібна кастомна компіляція. Тоді встановлюють **з вихідного коду**.

#### Класичний ланцюжок: `./configure && make && make install`

```
Архів з кодом (.tar.gz)
        │
        ▼
  tar xf archive.tar.gz      ← розпакування
        │
        ▼
  ./configure                 ← перевірка середовища, генерація Makefile
        │
        ▼
  make                        ← компіляція (C → бінарний файл)
        │
        ▼
  sudo make install           ← копіювання файлів у /usr/local/...
```

#### Практичний приклад: встановлення `htop` з коду

```bash
# 1. Встановити інструменти збірки
sudo apt install build-essential libncurses-dev autotools-dev autoconf -y

# 2. Завантажити вихідний код
wget https://github.com/htop-dev/htop/releases/download/3.3.0/htop-3.3.0.tar.xz

# 3. Розпакувати
tar xf htop-3.3.0.tar.xz
cd htop-3.3.0/

# 4. Налаштування (перевірить наявність бібліотек, компілятора тощо)
./configure --prefix=/usr/local
```

Результат `./configure`:

```
checking for gcc... gcc
checking whether the C compiler works... yes
checking for ncurses.h... yes
checking for libncurses... yes
...
config.status: creating Makefile
config.status: creating config.h
```

```bash
# 5. Компіляція (використати всі ядра процесора)
make -j$(nproc)

# 6. Встановлення
sudo make install

# 7. Перевірка
htop --version
# htop 3.3.0
```

> 💡 `--prefix=/usr/local` вказує, куди встановити програму. За замовчуванням:
> - бінарники → `/usr/local/bin/`
> - бібліотеки → `/usr/local/lib/`
> - заголовки → `/usr/local/include/`

> ⚠️ Програми, встановлені таким чином, **не відстежуються** пакетним менеджером. Для видалення потрібно виконати `sudo make uninstall` у тій самій директорії збірки.

---

### 1.6 Спільні бібліотеки та залежності

#### Що таке бібліотека?

**Бібліотека** — набір функцій, що можуть використовуватись різними програмами. Замість того, щоб кожна програма мала власну копію коду для, наприклад, шифрування SSL — всі вони використовують одну спільну бібліотеку `libssl.so`.

#### Статичні vs Динамічні (спільні) бібліотеки

| Характеристика      | Статичні (`.a`)               | Динамічні / Спільні (`.so`) |
|--------------------|-------------------------------|------------------------------|
| Підключення         | Під час компіляції            | Під час виконання            |
| Розмір бінарника    | Великий (код вбудований)      | Маленький                    |
| Оновлення           | Потрібна перекомпіляція       | Замінюємо лише `.so` файл    |
| Спільне використання| ❌ Кожна програма — своя копія | ✅ Одна копія у пам'яті       |

```
Програма A ──┐
             ├──► libssl.so (у пам'яті — одна копія)
Програма B ──┘
```

#### Де знаходяться бібліотеки?

```bash
# Стандартні шляхи пошуку бібліотек
/lib/
/usr/lib/
/usr/local/lib/
/lib/x86_64-linux-gnu/     # для 64-бітних систем

# Переглянути всі шляхи пошуку
cat /etc/ld.so.conf
cat /etc/ld.so.conf.d/*.conf
```

#### Корисні команди для роботи з бібліотеками

```bash
# ldd — показати залежності бінарного файлу
ldd /usr/bin/git
```

```
        linux-vdso.so.1 (0x00007ffdf3bfd000)
        libpcre2-8.so.0 => /lib/x86_64-linux-gnu/libpcre2-8.so.0
        libz.so.1 => /lib/x86_64-linux-gnu/libz.so.1
        libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0
        libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6
        /lib64/ld-linux-x86-64.so.2
```

```bash
# ldconfig — оновити кеш бібліотек (після встановлення нової бібліотеки)
sudo ldconfig

# Переглянути кеш (які бібліотеки відомі системі)
ldconfig -p | grep libssl

# dpkg -L — переглянути файли, встановлені пакетом
dpkg -L libssl3

# dpkg -S — знайти, якому пакету належить файл
dpkg -S /usr/lib/x86_64-linux-gnu/libssl.so.3
```

#### Змінна середовища `LD_LIBRARY_PATH`

Якщо бібліотека встановлена у нестандартне місце (наприклад, у домашню директорію), можна тимчасово вказати шлях:

```bash
export LD_LIBRARY_PATH=/home/user/mylibs:$LD_LIBRARY_PATH
./myprogram
```

> ⚠️ Не рекомендується використовувати `LD_LIBRARY_PATH` постійно у продакшені — це може призвести до конфліктів версій. Краще додати шлях до `/etc/ld.so.conf.d/` і виконати `sudo ldconfig`.

---

## Практичне завдання: Встановлення Git CLI на Windows + WSL

### Крок 1: Встановлення WSL (якщо не встановлено)

Відкрийте **PowerShell** від імені адміністратора:

```powershell
# Встановити WSL з Ubuntu за замовчуванням
wsl --install

# Перевірити встановлені дистрибутиви
wsl --list --verbose

# Перевірити версію WSL
wsl --version
```

Після встановлення перезавантажте ПК і задайте ім'я користувача та пароль Linux.

---

### Крок 2: Встановлення Git у WSL (Ubuntu)

Відкрийте **WSL термінал** (Ubuntu):

```bash
# Оновити індекс пакетів
sudo apt update

# Перевірити доступну версію Git
apt show git | grep Version

# Встановити Git
sudo apt install git -y

# Перевірити встановлення
git --version
```

---

### Крок 3: Встановлення актуальної версії Git через офіційний PPA

Репозиторій Ubuntu може містити не найновішу версію. Для отримання останньої:

```bash
# Додати офіційний PPA команди Git
sudo add-apt-repository ppa:git-core/ppa -y
sudo apt update

# Встановити / оновити Git
sudo apt install git -y

# Перевірити версію (має бути новіша)
git --version
```

---

### Крок 4: Початкове налаштування Git

```bash
# Вказати ім'я та email (обов'язково для комітів)
git config --global user.name "Іванов Іван"
git config --global user.email "ivanov@viti.edu.ua"

# Встановити редактор за замовчуванням
git config --global core.editor nano

# Встановити назву гілки за замовчуванням
git config --global init.defaultBranch main

# Переглянути всі налаштування
git config --list
```

---

### Крок 5: Встановлення Git для Windows (GUI + інтеграція)

Завантажте інсталятор з [https://git-scm.com/download/win](https://git-scm.com/download/win) або через **winget**:

```powershell
# У PowerShell (Windows)
winget install --id Git.Git -e --source winget

# Перевірити у PowerShell
git --version
```

> 💡 **Рекомендація:** використовуйте **Git у WSL** для проектів, що живуть у файловій системі Linux, і **Git для Windows** для проектів у `C:\`. Змішувати не варто — різні закінчення рядків (`\r\n` vs `\n`).

---

### Крок 6: Перевірка встановлення

```bash
# У WSL — перевірити всі компоненти
echo "=== Git version ===" && git --version
echo "=== Git config ===" && git config --list
echo "=== Git location ===" && which git
echo "=== Git dependencies ===" && ldd $(which git) | head -5
```

Очікуваний результат:

```
=== Git version ===
git version 2.47.2
=== Git config ===
user.name=Іванов Іван
user.email=ivanov@viti.edu.ua
core.editor=nano
init.defaultbranch=main
=== Git location ===
/usr/bin/git
=== Git dependencies ===
        linux-vdso.so.1 (0x00007ffc...)
        libpcre2-8.so.0 => /lib/x86_64-linux-gnu/libpcre2-8.so.0
        libz.so.1 => /lib/x86_64-linux-gnu/libz.so.1
```

---

## 2. Використання текстових редакторів

### 2.1 Огляд редакторів

| Редактор | Тип        | Складність | Коли використовувати |
|---------|-----------|-----------|---------------------|
| `nano`  | Terminal   | ⭐ Легко   | Швидке редагування конфігів |
| `vim`   | Terminal   | ⭐⭐⭐ Важко | Ефективне редагування у SSH |
| `code`  | GUI/Remote | ⭐⭐ Середньо | Розробка проектів (WSL) |

---

### 2.2 nano — простий редактор для початківців

```bash
# Відкрити / створити файл
nano filename.txt

# Відкрити з позицією курсора на рядку 15
nano +15 filename.txt
```

Основні комбінації клавіш (`^` = Ctrl):

| Комбінація  | Дія                    |
|------------|------------------------|
| `^O`       | Зберегти файл          |
| `^X`       | Вийти                  |
| `^K`       | Вирізати рядок         |
| `^U`       | Вставити               |
| `^W`       | Пошук                  |
| `^G`       | Довідка                |

```bash
# Приклад: швидко відредагувати sources.list
sudo nano /etc/apt/sources.list
```

---

### 2.3 Vim — потужний редактор

Vim має два основних режими:

```
┌─────────────────────────────────────┐
│  NORMAL MODE (навігація / команди)  │
│         натисніть i або a           │
│                 ▼                   │
│  INSERT MODE (введення тексту)      │
│         натисніть Esc               │
│                 ▲                   │
│  повернення в NORMAL MODE           │
└─────────────────────────────────────┘
```

```bash
vim filename.txt
```

Базові команди (у Normal mode):

| Команда   | Дія                           |
|----------|-------------------------------|
| `i`      | Вставка перед курсором         |
| `a`      | Вставка після курсора          |
| `Esc`    | Повернутись у Normal mode      |
| `:w`     | Зберегти                       |
| `:q`     | Вийти                          |
| `:wq`    | Зберегти і вийти               |
| `:q!`    | Вийти без збереження           |
| `dd`     | Видалити рядок                 |
| `yy`     | Скопіювати рядок               |
| `p`      | Вставити                       |
| `/слово` | Пошук                          |
| `n`      | Наступний результат пошуку     |

> 💡 Якщо ви випадково відкрили Vim і не знаєте, як вийти — натисніть `Esc`, потім введіть `:q!` і натисніть Enter.

---

### 2.4 VS Code з WSL Remote — сучасний підхід

Visual Studio Code підтримує розробку безпосередньо у WSL через розширення **Remote - WSL**.

```bash
# У WSL: встановити VS Code Server автоматично
code .
# ↑ Якщо VS Code встановлений на Windows, ця команда відкриє
# поточну директорію WSL у VS Code з повним доступом до файлів Linux
```

Встановлення розширення у Windows VS Code:
1. Відкрийте VS Code
2. `Ctrl+Shift+X` → пошук `WSL`
3. Встановіть **Remote - WSL** (автор: Microsoft)
4. `Ctrl+Shift+P` → `WSL: Connect to WSL`

---

## Завдання на самопідготовку

### Завдання 1 — Базова робота з APT ⭐

Виконайте у WSL та збережіть вивід команд у файл `task1.txt`:

```bash
# Запишіть результати виконання цих команд:
apt show git > task1.txt
echo "---" >> task1.txt
dpkg -L git | head -20 >> task1.txt
echo "---" >> task1.txt
ldd $(which git) >> task1.txt
```

**Дайте відповіді у файлі (власними словами):**
1. Яка версія Git встановлена у вашій системі?
2. Скільки файлів встановлює пакет `git`? Де знаходиться виконуваний файл?
3. Від яких бібліотек залежить `git`? Назвіть 3 і поясніть, для чого вони можуть використовуватись.

---

### Завдання 2 — Дослідження репозиторіїв ⭐

```bash
# Перегляньте файл sources.list та директорію sources.list.d
cat /etc/apt/sources.list
ls -la /etc/apt/sources.list.d/
```

**Дайте відповіді:**
1. Яка кодова назва вашого дистрибутиву Ubuntu? (наприклад: `jammy`, `focal`)
2. Які компоненти підключені у вашому `sources.list`?
3. Які додаткові репозиторії є у `sources.list.d/`? Що вони надають?

---

### Завдання 3 — Встановлення пакету та аналіз залежностей ⭐⭐

```bash
# Встановіть curl та проаналізуйте
sudo apt install curl -y
ldd $(which curl)
apt show curl
```

**Дайте відповіді:**
1. Від яких бібліотек залежить `curl`? Знайдіть у мережі, для чого використовується `libssl` та `libcurl`.
2. Що станеться, якщо видалити одну з бібліотек, від якої залежить `curl`? (Лише теоретично, не виконуйте!)
3. Як перевірити, яким пакетом встановлена бібліотека `libcurl4`? Запишіть команду та результат.

---

### Завдання 4 — Компіляція з вихідного коду ⭐⭐⭐

Встановіть просту програму **`tree`** з вихідного коду:

```bash
# Встановити необхідні інструменти
sudo apt install build-essential wget -y

# Завантажити вихідний код tree
wget https://mama.indstate.edu/users/ice/tree/src/tree-2.1.1.tgz

# Розпакуйте та перейдіть у директорію
tar xf tree-2.1.1.tgz
cd tree-2.1.1

# Переглянути Makefile перед збіркою
cat Makefile | head -30
```

**Виконайте компіляцію та встановлення, дайте відповіді:**
1. Які файли з'явились у директорії після виконання `make`?
2. Куди були скопійовані файли після `sudo make install`?
3. Порівняйте встановлення через `apt install tree` та з вихідного коду — плюси та мінуси кожного підходу (мін. 3 пункти для кожного).

---

### Завдання 5 — Текстові редактори ⭐

Виконайте наступні дії та зробіть скриншоти:

1. Створіть файл `~/myconfig.conf` у **nano** з таким вмістом:
```ini
[server]
host = 192.168.1.1
port = 8080
debug = true
```

2. Відкрийте той самий файл у **vim**, перейдіть у INSERT mode, змініть `port = 8080` на `port = 443`, збережіть та вийдіть.

3. Перевірте результат:
```bash
cat ~/myconfig.conf
```

---

### Критерії оцінювання

| Завдання | Максимум балів |
|---------|---------------|
| Завдання 1 | 2 бали |
| Завдання 2 | 2 бали |
| Завдання 3 | 2 бали |
| Завдання 4 | 3 бали |
| Завдання 5 | 1 бал  |
| **Разом** | **10 балів** |

Результати надсилати до наступного заняття у вигляді:
- текстових файлів з відповідями,
- скриншотів терміналу (для завдань 1–4),
- скриншотів редакторів (для завдання 5).

---

## Корисні ресурси

- 📖 [Офіційна документація APT](https://manpages.ubuntu.com/manpages/latest/en/man8/apt.8.html)
- 📖 [Git — офіційний сайт](https://git-scm.com/doc)
- 📖 [WSL Documentation (Microsoft)](https://learn.microsoft.com/en-us/windows/wsl/)
- 📖 [Vim Adventures — ігровий туторіал](https://vim-adventures.com/)
- 📖 [GNU Make Manual](https://www.gnu.org/software/make/manual/)

---

*Кафедра 21 · ВІТІ · Навчальний матеріал, відкрита інформація*
