# Змістовий модуль 4 · Заняття 2 (Практичне)
## Дії з програмним забезпеченням

> **Курс:** Операційні системи та системне ПЗ
> **Аудиторія:** Курсанти 2-го курсу
> **Тривалість:** 2 академічні години
> **Середовище:** Windows 11 + WSL2 (Ubuntu 22.04 LTS)
> **Попередні знання:** Змістовий модуль 4, Заняття 1 (Лекція)

---

## Навчальні питання

1. [Встановлення програмного забезпечення](#питання-1--встановлення-програмного-забезпечення)
2. [Використання текстових редакторів](#питання-2--використання-текстових-редакторів)

---

## Підготовка робочого місця

Перед початком роботи переконайтесь, що WSL запущено та система оновлена.

```bash
# Запустити WSL (у PowerShell або меню Пуск → Ubuntu)
wsl

# Перевірити версію Ubuntu
lsb_release -a
```

Очікуваний результат:

```
No LSB modules are available.
Distributor ID: Ubuntu
Description:    Ubuntu 22.04.4 LTS
Release:        22.04
Codename:       jammy
```

```bash
# Оновити список пакетів
sudo apt update

# Переглянути кількість пакетів, доступних для оновлення
apt list --upgradable 2>/dev/null | wc -l
```

> 📁 Всі файли практичного заняття зберігати у директорії `~/lab2/`

```bash
# Створити робочу директорію
mkdir -p ~/lab2 && cd ~/lab2
```

---

# Питання 1 — Встановлення програмного забезпечення

## Лабораторна робота 1.1 — Дослідження APT

**Мета:** навчитися аналізувати стан пакетної бази та отримувати детальну інформацію про пакети.

### Крок 1: Дослідження бази пакетів

```bash
# Скільки пакетів доступно у репозиторіях?
apt-cache stats
```

```
Total package names: 85714
Total package structures: 85714
...
Total distinct versions: 72891
Total dependencies: 671030
```

```bash
# Переглянути вміст sources.list
cat /etc/apt/sources.list
```

```bash
# Переглянути всі підключені репозиторії (включно з sources.list.d)
grep -rh "^deb " /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null
```

> 🔍 **Зверніть увагу:** команда `grep -rh` рекурсивно шукає рядки, що починаються з `deb `, у всіх файлах конфігурації. Це повний список джерел, з яких ваша система може отримувати пакети.

---

### Крок 2: Детальний аналіз пакету

Дослідимо пакет `htop` — інтерактивний переглядач процесів.

```bash
# Інформація про пакет (до встановлення)
apt show htop
```

```
Package: htop
Version: 3.0.5-7build2
Priority: optional
Section: utils
Maintainer: Daniel Lange <DLange@debian.org>
Installed-Size: 388 kB
Depends: libc6 (>= 2.34), libncursesw6 (>= 6), libtinfo6 (>= 6)
Homepage: https://htop.dev
Download-Size: 150 kB
APT-Sources: http://archive.ubuntu.com/ubuntu jammy/universe amd64 Packages
Description: interactive processes viewer
 htop is an ncurses-based process viewer...
```

```bash
# Записати інформацію у файл для звіту
apt show htop > ~/lab2/htop_info.txt
echo "Записано у ~/lab2/htop_info.txt"
```

> 🔍 **Зверніть увагу на поле `Depends:`** — це залежності пакету. APT автоматично встановить їх разом із `htop`. Якщо потрібної бібліотеки немає у системі, APT знайде і встановить її самостійно.

---

### Крок 3: Встановлення та перевірка htop

```bash
# Встановити htop
sudo apt install htop -y
```

```bash
# Перевірити встановлення — де знаходиться бінарний файл?
which htop

# Яка версія встановлена?
htop --version

# Які файли входять до пакету?
dpkg -L htop
```

```
/.
/usr
/usr/bin
/usr/bin/htop
/usr/share
/usr/share/applications
/usr/share/applications/htop.desktop
/usr/share/doc
/usr/share/doc/htop
/usr/share/doc/htop/AUTHORS
/usr/share/man
/usr/share/man/man1
/usr/share/man/man1/htop.1.gz
/usr/share/pixmaps
/usr/share/pixmaps/htop.png
```

```bash
# Від яких бібліотек залежить скомпільований бінарник?
ldd /usr/bin/htop
```

```
        linux-vdso.so.1 (0x00007ffd...)
        libncursesw.so.6 => /lib/x86_64-linux-gnu/libncursesw.so.6
        libtinfo.so.6 => /lib/x86_64-linux-gnu/libtinfo6
        libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6
        /lib64/ld-linux-x86-64.so.2
```

```bash
# Який пакет надає бібліотеку libncursesw?
dpkg -S /lib/x86_64-linux-gnu/libncursesw.so.6
```

```bash
# Зберегти результат ldd для звіту
ldd /usr/bin/htop > ~/lab2/htop_deps.txt
```

> 💡 **Висновок:** `htop` використовує бібліотеку `libncursesw` для відображення псевдографічного інтерфейсу у терміналі. Це хороший приклад повторного використання бібліотек — та сама бібліотека може використовуватись у `vim`, `nano`, `mc` тощо.

---

## Лабораторна робота 1.2 — Керування пакетами: повний цикл

**Мета:** відпрацювати встановлення, перевірку та видалення пакетів.

### Завдання: встановити `git`, `curl`, `tree`, `net-tools`

```bash
# Встановити кілька пакетів одночасно
sudo apt install git curl tree net-tools -y
```

### Перевірка кожного інструменту

```bash
# Git — система контролю версій
git --version
git config --list

# curl — утиліта для HTTP-запитів
curl --version | head -3

# tree — відображення дерева директорій
tree --version
tree /etc/apt/ -L 1

# net-tools — мережеві утиліти (ifconfig, netstat)
ifconfig lo
netstat -tuln | head -10
```

### Дослідження залежностей curl

```bash
# Що залежить від curl? (reverse dependencies)
apt-cache rdepends curl | head -15

# Від чого залежить curl?
apt-cache depends curl
```

```
curl
  Depends: libc6
  Depends: libcurl4
  Depends: zlib1g
```

```bash
# Де фізично живе бібліотека libcurl?
dpkg -L libcurl4 | grep "\.so"
```

---

### Симуляція встановлення без реального виконання

```bash
# Переглянути, що буде встановлено (без реального встановлення)
apt-get install -s nmap
```

```
NOTE: This is only a simulation!
      apt-get needs root privileges for real execution.
Inst liblinear4 (2.3.0+dfsg-5 Ubuntu:22.04)
Inst nmap-common (7.80+dfsg1-2build1 Ubuntu:22.04)
Inst nmap (7.80+dfsg1-2build1 Ubuntu:22.04)
Conf liblinear4 (2.3.0+dfsg-5 Ubuntu:22.04)
Conf nmap-common (7.80+dfsg1-2build1 Ubuntu:22.04)
Conf nmap (7.80+dfsg1-2build1 Ubuntu:22.04)
```

> 💡 Прапор `-s` (simulate) дуже корисний — дозволяє побачити, що буде встановлено, без реального виконання.

---

### Видалення пакету: `remove` vs `purge`

```bash
# Встановити тестовий пакет
sudo apt install cowsay -y
cowsay "Мяу, я пакет!"

# Перевірити конфіги пакету
dpkg -L cowsay | grep etc

# Видалити пакет (конфіги залишаються)
sudo apt remove cowsay -y

# Перевірити: чи залишились конфіги?
dpkg -l | grep cowsay
# Статус "rc" = removed but Config залишились
```

```
rc  cowsay     3.03+dfsg2-8    all    ...
```

```bash
# Повне видалення разом із конфігами
sudo apt purge cowsay -y
sudo apt autoremove -y

# Перевірити: пакет повністю відсутній
dpkg -l | grep cowsay
# (порожній вивід)
```

> 🔍 **Таблиця статусів dpkg:**
>
> | Код | Значення |
> |-----|---------|
> | `ii` | Встановлено (installed) |
> | `rc` | Видалено, конфіги залишились |
> | `un` | Невідомий / не встановлений |

---

## Лабораторна робота 1.3 — Встановлення з архіву (вихідний код)

**Мета:** зрозуміти процес `configure → make → install`, навчитися читати Makefile.

### Підготовка інструментів збірки

```bash
# build-essential включає: gcc, g++, make, libc-dev тощо
sudo apt install build-essential wget -y

# Перевірити наявність компілятора
gcc --version
make --version
```

```
gcc (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0
GNU Make 4.3
```

---

### Практична збірка: утиліта `jq` (JSON-процесор)

**jq** — незамінний інструмент для роботи з JSON у терміналі. Збираємо з вихідного коду, щоб побачити весь процес.

```bash
cd ~/lab2

# Завантажити вихідний код jq 1.7.1
wget https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-1.7.1.tar.gz

# Перевірити завантажений файл
ls -lh jq-1.7.1.tar.gz
file jq-1.7.1.tar.gz
```

```
-rw-r--r-- 1 user user 1.6M Feb 10 12:00 jq-1.7.1.tar.gz
jq-1.7.1.tar.gz: gzip compressed data, from Unix
```

```bash
# Розпакувати архів
tar xf jq-1.7.1.tar.gz

# Що з'явилось?
ls -la
tree jq-1.7.1/ -L 1
```

```
jq-1.7.1/
├── AUTHORS
├── COPYING
├── Makefile.am        ← шаблон для генерації Makefile
├── README.md
├── configure          ← скрипт налаштування
├── configure.ac       ← вхідні дані для autoconf
├── src/               ← вихідний код (.c файли)
├── tests/             ← тести
└── docs/              ← документація
```

```bash
cd jq-1.7.1/

# Переглянути, що перевіряє configure
./configure --help | head -40
```

```
`configure' configures jq 1.7.1 to adapt to many kinds of systems.

Usage: ./configure [OPTION]... [VAR=VALUE]...

Installation directories:
  --prefix=PREFIX    install architecture-independent files in PREFIX
                     [/usr/local]
  --bindir=DIR       user executables [PREFIX/bin]
  --libdir=DIR       object code libraries [PREFIX/lib]
  --includedir=DIR   C header files [PREFIX/include]

Optional Features:
  --disable-maintainer-mode
  --enable-shared[=PKGS]
  --enable-static[=PKGS]
  --disable-docs
  --with-oniguruma    use Oniguruma for regex
```

---

#### Крок 1: `./configure`

```bash
# Налаштувати з установкою у /usr/local та без документації (швидше)
./configure --prefix=/usr/local --disable-docs
```

```
checking for a BSD-compatible install... /usr/bin/install -c
checking whether build environment is sane... yes
checking for a thread-safe mkdir -p... /usr/bin/mkdir -p
checking for gawk... gawk
checking whether make sets $(MAKE)... yes
checking for gcc... gcc
checking for C compiler default output file name... a.out
checking whether the C compiler works... yes
checking for C compiler flag -std=c11... yes
...
checking for oniguruma... no
configure: WARNING: Oniguruma not found, using built-in regex
...
config.status: creating Makefile   ← Makefile створено!
config.status: creating config.h
```

```bash
# Що з'явилось після configure?
ls -la | grep -E "Makefile|config"
```

```
-rw-r--r-- 1 user user  52431 Feb 10 Makefile
-rw-r--r-- 1 user user   3072 Feb 10 config.h
-rw-r--r-- 1 user user   1284 Feb 10 config.log
-rwxr-xr-x 1 user user   3981 Feb 10 config.status
```

```bash
# Переглянути початок Makefile (що він визначає)
head -30 Makefile
```

---

#### Крок 2: `make`

```bash
# Компілювати (вказати кількість паралельних потоків = кількість ядер CPU)
make -j$(nproc)
```

```
gcc -DHAVE_CONFIG_H -I. -I./src  -g -O2 -MT src/jq-main.o \
    -MD -MP -MF src/.deps/jq-main.Tpo -c -o src/jq-main.o src/main.c
gcc -DHAVE_CONFIG_H -I. -I./src  -g -O2 -MT src/jq-lexer.o \
    -MD -MP -MF src/.deps/jq-lexer.Tpo -c -o src/jq-lexer.o src/jq-lexer.c
...
gcc -g -O2  -o jq src/jq-main.o src/jq-parser.o ... src/libjq.a
```

```bash
# jq збірки з'явився у поточній директорії
ls -lh jq
file jq
```

```
-rwxr-xr-x 1 user user 1.1M Feb 10 jq
jq: ELF 64-bit LSB pie executable, x86-64, dynamically linked
```

```bash
# Протестувати зібраний бінарник БЕЗ встановлення
./jq --version
echo '{"name": "Іван", "rank": "курсант"}' | ./jq .
```

```json
{
  "name": "Іван",
  "rank": "курсант"
}
```

---

#### Крок 3: `make install`

```bash
# Встановити у систему (/usr/local/bin/)
sudo make install
```

```
make[1]: Entering directory '/home/user/lab2/jq-1.7.1'
 /usr/bin/install -c jq /usr/local/bin/jq
make[1]: Leaving directory '/home/user/lab2/jq-1.7.1'
```

```bash
# Перевірити встановлення
which jq
jq --version

# Порівняти: пакетний менеджер нічого не знає про цей jq
dpkg -l | grep jq
# (порожній або інша версія)
```

> ⚠️ **Важливо:** `/usr/local/bin/` має вищий пріоритет у `$PATH`, ніж `/usr/bin/`. Тому якби `jq` був встановлений через `apt` у `/usr/bin/`, наша версія з `/usr/local/bin/` виконувалась би першою.

```bash
# Перевірити порядок у PATH
echo $PATH
# /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

---

#### Практичне використання jq

```bash
# Створити тестовий JSON-файл
cat > ~/lab2/cadets.json << 'EOF'
{
  "unit": "Взвод 1",
  "cadets": [
    {"name": "Іванов", "year": 2, "gpa": 4.5},
    {"name": "Петренко", "year": 2, "gpa": 3.8},
    {"name": "Коваль", "year": 2, "gpa": 4.9}
  ]
}
EOF

# Читати JSON
jq '.' ~/lab2/cadets.json

# Отримати лише список курсантів
jq '.cadets[].name' ~/lab2/cadets.json

# Відфільтрувати курсантів з GPA > 4.0
jq '.cadets[] | select(.gpa > 4.0) | .name' ~/lab2/cadets.json

# Порахувати кількість курсантів
jq '.cadets | length' ~/lab2/cadets.json
```

---

## Лабораторна робота 1.4 — Спільні бібліотеки: дослідження

**Мета:** зрозуміти механізм динамічного лінкування та керування бібліотеками.

### Карта бібліотек у системі

```bash
# Скільки бібліотек відомо системі?
ldconfig -p | wc -l

# Знайти конкретну бібліотеку
ldconfig -p | grep libz

# Де живе libc (основна бібліотека C)?
ldconfig -p | grep "libc.so"
```

### Порівняння залежностей програм

```bash
# Порівняємо залежності різних утиліт
echo "=== git ===" && ldd $(which git) | wc -l
echo "=== curl ===" && ldd $(which curl) | wc -l
echo "=== ls ===" && ldd $(which ls) | wc -l
echo "=== nano ===" && ldd $(which nano) | wc -l
```

```bash
# Повний аналіз: зберегти у файл
{
  echo "# Аналіз залежностей утиліт"
  echo "## git"
  ldd $(which git)
  echo ""
  echo "## curl"
  ldd $(which curl)
  echo ""
  echo "## ls"
  ldd $(which ls)
} > ~/lab2/library_analysis.txt

cat ~/lab2/library_analysis.txt
```

### Знайти програми, що використовують конкретну бібліотеку

```bash
# Які встановлені пакети залежать від libssl?
apt-cache rdepends libssl3 | head -20

# Перевірити наявність бібліотеки
ls -la /lib/x86_64-linux-gnu/libssl*
ls -la /lib/x86_64-linux-gnu/libcrypto*
```

```bash
# Де шукає бібліотеки система?
cat /etc/ld.so.conf
cat /etc/ld.so.conf.d/*.conf
```

---

# Питання 2 — Використання текстових редакторів

## Лабораторна робота 2.1 — Редактор nano

**Мета:** навчитися ефективно використовувати nano для редагування конфігураційних файлів.

### Базова навігація

```bash
# Створити файл для практики
cat > ~/lab2/practice.txt << 'EOF'
Рядок перший
Рядок другий
Рядок третій
Рядок четвертий
Рядок п'ятий
Рядок шостий
Рядок сьомий
Рядок восьмий
Рядок дев'ятий
Рядок десятий
EOF

# Відкрити у nano
nano ~/lab2/practice.txt
```

### Шпаргалка nano (тренування у редакторі)

| Дія | Комбінація | Пояснення |
|-----|-----------|-----------|
| Зберегти | `Ctrl+O` → Enter | Write **O**ut |
| Вийти | `Ctrl+X` | e**X**it |
| Вирізати рядок | `Ctrl+K` | **K**ill line |
| Вставити | `Ctrl+U` | **U**npaste |
| Пошук | `Ctrl+W` | **W**here is |
| Замінити | `Ctrl+\` | Search & replace |
| Перейти до рядка | `Ctrl+_` | Go to line number |
| Початок рядка | `Ctrl+A` | |
| Кінець рядка | `Ctrl+E` | |
| Виділення тексту | `Alt+A` | Mark/unmark |
| Копіювати виділене | `Alt+6` | |

---

### Практичне завдання nano: конфігурація SSH

Створимо учбовий конфігураційний файл SSH-клієнта:

```bash
nano ~/lab2/ssh_config_example
```

Введіть наступний текст **вручну** (не копіюйте — тренуйте навички введення):

```
# SSH Client Config — Lab 2
# Курсант: [Прізвище І.Б.]
# Дата: [сьогоднішня дата]

Host jumpbox
    HostName 203.0.113.10
    User admin
    Port 22
    IdentityFile ~/.ssh/id_ed25519

Host dev-server
    HostName 10.10.0.5
    User developer
    Port 2222
    ProxyJump jumpbox

Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
```

Після введення:
1. Збережіть: `Ctrl+O` → Enter
2. Знайдіть слово "admin": `Ctrl+W` → `admin` → Enter
3. Замініть "admin" на "cadet": `Ctrl+\` → `admin` → Enter → `cadet` → Enter → `Y` (yes to all)
4. Перейдіть до рядка 6: `Ctrl+_` → `6` → Enter
5. Вийдіть: `Ctrl+X`

```bash
# Перевірити результат
cat ~/lab2/ssh_config_example
```

---

### Редагування реального конфігу (читання)

```bash
# Переглянути (тільки читання) конфіг APT
nano --view /etc/apt/sources.list
# Ctrl+X для виходу
```

---

## Лабораторна робота 2.2 — Редактор Vim

**Мета:** опанувати базові команди vim для роботи у SSH-сесіях.

> 💡 **Чому vim важливий?** На більшості серверів немає GUI. Якщо nano недоступний (мінімальна інсталяція), vim майже завжди є. Крім того, vim значно ефективніший для редагування коду.

### Тренажер: Vim без паніки

```bash
# Відкрити файл у vim
vim ~/lab2/vim_practice.txt
```

#### Ви у Normal mode. Не панікуйте! Запам'ятайте одне: `Esc → :q! → Enter` = вийти завжди.

```
┌───────────────────────────────────────────────────────────────────┐
│                         РЕЖИМИ VIM                                │
│                                                                   │
│  NORMAL ──── i/a/o ────► INSERT  (введення тексту)               │
│    │    ◄─── Esc ──────    │                                      │
│    │                                                              │
│    └───── : ────────────► COMMAND  (:w :q :wq :q! :/пошук)       │
│    │      ◄─── Esc ─────    │                                     │
│    │                                                              │
│    └───── v ────────────► VISUAL  (виділення тексту)             │
│           ◄─── Esc ─────                                          │
└───────────────────────────────────────────────────────────────────┘
```

---

### Вправа 1: Введення тексту

```
Команди для входу в INSERT mode:
  i  — вставка ПЕРЕД курсором
  a  — вставка ПІСЛЯ курсора
  o  — новий рядок НИЖЧЕ
  O  — новий рядок ВИЩЕ
  I  — вставка на ПОЧАТКУ рядка
  A  — вставка в КІНЦІ рядка
```

**Дія:**
1. Натисніть `i` (перейти в INSERT mode — бачите `-- INSERT --` внизу)
2. Введіть текст:
```
# Vim Practice File
# Модуль 4, Заняття 2

server_ip=192.168.1.100
server_port=8080
debug_mode=false
log_level=info
max_connections=100
```
3. Натисніть `Esc` (повернутись у Normal mode)
4. Введіть `:w` → Enter (зберегти)

---

### Вправа 2: Навігація

У Normal mode — **НЕ використовуйте мишу:**

```
Базова навігація (замість стрілок):
  h — ліво     j — вниз     k — вгору     l — право

Швидка навігація:
  0  — початок рядка
  $  — кінець рядка
  gg — перший рядок файлу
  G  — останній рядок файлу
  5G — перейти до рядка 5
  w  — наступне слово
  b  — попереднє слово
  Ctrl+d — пролистати вниз (half page)
  Ctrl+u — пролистати вгору (half page)
```

**Дія:** перейдіть до рядка з `debug_mode` за допомогою команди `4G` (або `/debug` для пошуку).

---

### Вправа 3: Редагування

```
Команди редагування у Normal mode:
  x     — видалити символ під курсором
  dd    — видалити (вирізати) рядок
  yy    — скопіювати рядок
  p     — вставити після курсора
  P     — вставити перед курсором
  u     — undo (скасувати)
  Ctrl+r — redo (повторити)
  cw    — замінити слово (c = change)
  r     — замінити один символ
  .     — повторити останню дію
  2dd   — видалити 2 рядки
  3yy   — скопіювати 3 рядки
```

**Дія:**
1. Перейдіть на рядок `debug_mode=false`
2. Натисніть `$` (перейти в кінець рядка)
3. Натисніть `b` (перейти на початок слова `false`)
4. Натисніть `cw` (change word — перейде в INSERT)
5. Введіть `true`
6. Натисніть `Esc`

---

### Вправа 4: Пошук та заміна

```bash
# У vim (Command mode):
/слово          ← пошук вперед
?слово          ← пошук назад
n               ← наступний результат
N               ← попередній результат

# Заміна (substitute):
:s/old/new/     ← замінити перше входження у рядку
:s/old/new/g    ← замінити всі у рядку
:%s/old/new/g   ← замінити всі у файлі
:%s/old/new/gc  ← замінити з підтвердженням кожного
```

**Дія:**
1. Введіть `:/192.168` → Enter (знайти IP-адресу)
2. Введіть `:%s/192.168.1.100/10.0.0.1/g` → Enter (замінити IP у всьому файлі)
3. Перевірте результат: `gg` (перейти на початок)

---

### Вправа 5: Мультирядкові операції та збереження

```
:w              — зберегти
:w filename     — зберегти як...
:q              — вийти (тільки якщо немає змін)
:wq або ZZ      — зберегти і вийти
:q!             — вийти БЕЗ збереження (аварійний вихід)
:set number     — показати номери рядків
:set nonumber   — сховати номери рядків
:set paste      — режим вставки (вимикає автоіндент)
```

**Дія:**
1. Введіть `:set number` → Enter (показати номери рядків)
2. Введіть `:wq` → Enter (зберегти і вийти)

```bash
# Перевірити результат редагування
cat ~/lab2/vim_practice.txt
```

---

### Практичне завдання vim: редагування конфігу

```bash
# Скопіювати файл hosts для практики
cp /etc/hosts ~/lab2/hosts_practice

vim ~/lab2/hosts_practice
```

Виконайте у vim:
1. `:set number` — увімкнути нумерацію
2. `G` — перейти в кінець файлу
3. `o` — новий рядок, введіть: `10.0.0.1    lab-server    # Lab 2 server`
4. `Esc`
5. `o` — ще один рядок: `10.0.0.2    monitoring    # Grafana`
6. `Esc`
7. `/localhost` — знайти рядок з localhost
8. `yy` — скопіювати рядок
9. `G` → `p` — вставити в кінець
10. `:wq` — зберегти та вийти

```bash
# Порівняти з оригіналом
diff /etc/hosts ~/lab2/hosts_practice
```

---

## Лабораторна робота 2.3 — Потокові редактори: sed та awk

**Мета:** навчитися автоматизувати редагування файлів без інтерактивного редактора.

> 💡 `sed` і `awk` — інструменти для **пакетного** редагування. Ідеальні для скриптів і автоматизації.

### sed — Stream Editor

```bash
# Переглянути файл
cat ~/lab2/vim_practice.txt

# Замінити у файлі (вивід у термінал, файл не змінюється)
sed 's/info/warning/' ~/lab2/vim_practice.txt

# Замінити всі входження у рядку (прапор g)
sed 's/false/true/g' ~/lab2/vim_practice.txt

# Замінити у файлі (зберегти зміни, -i = in-place)
sed -i 's/log_level=info/log_level=debug/' ~/lab2/vim_practice.txt

# Видалити рядки, що починаються з # (коментарі)
sed '/^#/d' ~/lab2/vim_practice.txt

# Показати тільки рядки 3-6
sed -n '3,6p' ~/lab2/vim_practice.txt

# Додати рядок після рядка з "port"
sed '/port/a timeout=30' ~/lab2/vim_practice.txt
```

### awk — рядковий процесор

```bash
# Базова структура: awk '{дія}' файл

# Вивести тільки перший стовпець (роздільник =)
awk -F'=' '{print $1}' ~/lab2/vim_practice.txt

# Вивести ключ та значення у зворотному порядку
awk -F'=' 'NF==2 {print $2, "=>", $1}' ~/lab2/vim_practice.txt

# Порахувати рядки, що не є коментарями
awk '!/^#/ && NF>0 {count++} END {print "Параметрів:", count}' ~/lab2/vim_practice.txt

# Аналіз CSV (корисний скіл)
cat > ~/lab2/data.csv << 'EOF'
name,year,gpa
Іванов,2,4.5
Петренко,2,3.8
Коваль,2,4.9
Мельник,2,4.1
EOF

awk -F',' 'NR>1 {sum+=$3; count++} END {printf "Середній GPA: %.2f\n", sum/count}' ~/lab2/data.csv
awk -F',' 'NR>1 && $3>4.0 {print $1, "- відмінник"}' ~/lab2/data.csv
```

---

## Підсумкове завдання заняття

**Виконати самостійно за 20 хвилин.** Результати оформити у файлі `~/lab2/report.md`.

### Завдання А — Пакетний менеджер (3 бали)

```bash
nano ~/lab2/report.md
```

Дайте відповіді у файлі:

1. Встановіть пакет `figlet`. Яка команда? Що робить ця утиліта? Виконайте: `figlet "VÍTI 2025"` і вставте результат у звіт.

2. Знайдіть, якому пакету належить файл `/usr/bin/python3`. Запишіть команду та результат.

3. Перевірте, скільки пакетів у системі залежить від `libssl3`. Запишіть команду та кількість.

4. Різниця між `apt remove` та `apt purge` — пояснити своїми словами + навести приклад коли кожен варіант кращий.

---

### Завдання Б — Компіляція (3 бали)

Встановіть утиліту **`nmap`** двома способами:

**Спосіб 1: через apt**
```bash
sudo apt install nmap -y
which nmap
nmap --version
ldd $(which nmap) | wc -l    # записати кількість залежностей
```

**Спосіб 2: дізнатись звідки apt завантажив пакет**
```bash
apt show nmap | grep -E "Version|Download-Size|APT-Sources"
```

У звіті порівняйте: що простіше, що надійніше, коли б ви обрали встановлення з коду?

---

### Завдання В — Текстові редактори (4 бали)

Створіть файл `~/lab2/final_config.ini` у **vim** з наступним вмістом:

```ini
[network]
interface = eth0
ip_address = 192.168.100.10
netmask = 255.255.255.0
gateway = 192.168.100.1
dns_primary = 8.8.8.8
dns_secondary = 8.8.4.4

[logging]
log_file = /var/log/service.log
log_level = warning
max_size_mb = 100
rotate_days = 7

[security]
allow_root_login = no
password_auth = no
max_auth_tries = 3
```

Потім **у nano** виконайте такі зміни:
1. Змініть `log_level = warning` на `log_level = error`
2. Змініть `max_auth_tries = 3` на `max_auth_tries = 5`
3. Додайте рядок `firewall = ufw` у секцію `[security]`

Нарешті, **через sed** (одна команда):
- Замініть усі IP-адреси `192.168.100` на `10.10.0`

```bash
# Перевірка
grep -E "ip_address|gateway|dns" ~/lab2/final_config.ini
```

Вставте кінцевий вміст файлу у звіт.

---

## Здача роботи

```bash
# Переконатись, що всі файли на місці
ls -la ~/lab2/
```

Очікувана структура:

```
lab2/
├── cadets.json          ← ЛР 1.3
├── data.csv             ← ЛР 2.3
├── final_config.ini     ← Завдання В
├── hosts_practice       ← ЛР 2.2
├── htop_deps.txt        ← ЛР 1.1
├── htop_info.txt        ← ЛР 1.1
├── jq-1.7.1/            ← ЛР 1.3 (директорія збірки)
├── jq-1.7.1.tar.gz      ← ЛР 1.3
├── library_analysis.txt ← ЛР 1.4
├── practice.txt         ← ЛР 2.1
├── report.md            ← Підсумкове завдання
├── ssh_config_example   ← ЛР 2.1
└── vim_practice.txt     ← ЛР 2.2
```

```bash
# Архівувати для здачі (замість XX вказати номер взводу + прізвище)
tar czf ~/lab2_ВЗВОД_ПРІЗВИЩЕ.tar.gz ~/lab2/

# Перевірити архів
tar tzf ~/lab2_ВЗВОД_ПРІЗВИЩЕ.tar.gz | head -20
```

---

## Критерії оцінювання

| Лабораторна робота | Критерій | Балів |
|-------------------|---------|-------|
| ЛР 1.1–1.2 | Файли `htop_info.txt`, `htop_deps.txt`, `library_analysis.txt` присутні і коректні | 2 |
| ЛР 1.3 | `jq` зібрано та працює, є директорія збірки | 2 |
| ЛР 1.4 | Файл `library_analysis.txt` містить аналіз ≥ 3 утиліт | 1 |
| ЛР 2.1 | `ssh_config_example` містить правильний вміст із заміною | 1 |
| ЛР 2.2 | `hosts_practice` містить 2 нові записи та коректний diff | 2 |
| ЛР 2.3 | Команди sed/awk виконані, результати в `report.md` | 1 |
| Завд. А–В | `report.md` містить відповіді, `final_config.ini` коректний | 3 |
| **Разом** | | **12 балів** |

> Оцінка "відмінно" — 11–12 балів | "добре" — 9–10 | "задовільно" — 7–8

---

## Довідник команд заняття

```bash
# APT
apt show <pkg>           # інформація про пакет
apt-cache depends <pkg>  # залежності пакету
apt-cache rdepends <pkg> # зворотні залежності
apt-get install -s <pkg> # симуляція встановлення
dpkg -l | grep <name>    # пошук серед встановлених
dpkg -L <pkg>            # файли пакету
dpkg -S <file>           # якому пакету належить файл

# Бібліотеки
ldd <binary>             # залежності бінарника
ldconfig -p | grep <lib> # пошук у кеші бібліотек

# Збірка з коду
./configure --help       # опції збірки
./configure --prefix=... # вказати директорію
make -j$(nproc)          # компіляція (всі ядра)
sudo make install        # встановлення
sudo make uninstall      # видалення

# nano (Ctrl = ^)
^O — зберегти   ^X — вийти   ^W — пошук   ^\ — заміна
^K — вирізати   ^U — вставити   ^_ — перейти до рядка

# vim (Normal mode)
i/a/o — INSERT   Esc — Normal   :wq — зберегти/вийти
dd/yy/p — видалити/копіювати/вставити
/слово — пошук   :%s/old/new/g — заміна у файлі

# sed
sed 's/old/new/g' file          # заміна (вивід)
sed -i 's/old/new/g' file       # заміна (в файлі)
sed -n '3,6p' file              # вивести рядки 3-6
sed '/pattern/d' file           # видалити рядки за шаблоном

# awk
awk -F',' '{print $1}' file     # перший стовпець CSV
awk 'NR>1 {sum+=$3} END {print sum}' file  # сума
```

---

## 📝 Самоперевірка

Для самоперевірки та закріплення матеріалу запустіть інтерактивний скрипт:

```bash
bash самоперевірка/check.sh
```

> Скрипт охоплює 7 розділів: APT, бібліотеки, збірка з коду, nano/vim, sed/awk, практичний блок та блискавичне опитування.

---

*Кафедра 21 · ВІТІ · Навчальний матеріал для службового використання*
