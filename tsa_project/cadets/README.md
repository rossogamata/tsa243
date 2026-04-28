# Інструкція для курсантів

---

## Крок 1 — Налаштування (один раз на початку курсу)

```bash
# Клонувати репозиторій
git clone https://github.com/ВАШ_ORG/tsa243.git
cd tsa243/tsa_project

# Створити власний каталог зі шаблону
cp -r cadets/_template cadets/surname
git add cadets/surname
git commit -m "surname: init"
git push origin main
```

Заповни `cadets/surname/README.md` — IP твоєї VM, hostname, SSH публічний ключ.

---

## Крок 2 — Робота на кожному занятті

### Важливо: кожне заняття — окрема гілка

Довгоживуча гілка `surname` з часом розходиться з `main` і при відкритті PR
виникають merge conflicts. Тому для кожного заняття створюється нова гілка
від актуального `main`.

```bash
# 1. Переконатись що main актуальний
git checkout main
git pull origin main

# 2. Створити гілку для заняття
git checkout -b surname/lesson5_6
```

### На VM

Виконай завдання відповідно до README заняття. Зберігай команди і результати.

### У репозиторії

```bash
# 3. Скопіювати шаблон і заповнити звіт
cp cadets/_template/reports/lesson_template.md cadets/surname/reports/lesson5_6.md
nano cadets/surname/reports/lesson5_6.md

# 4. Закомітити
git add cadets/surname/reports/lesson5_6.md
git commit -m "surname/lesson5_6: мережева конфігурація"
git push origin surname/lesson5_6
```

---

## Крок 3 — Відкрити PR для захисту

1. GitHub → репозиторій → **Pull Requests** → **New Pull Request**
2. **base:** `main` ← **compare:** `surname/lesson5_6`
3. Заголовок: `[surname] Lesson 5.6 — Мережева конфігурація`
4. Заповни шаблон опису
5. **Create Pull Request**

Викладач перевіряє, залишає коментарі.
**Approve = залік**, гілка видаляється автоматично після merge.

---

## Цикл на кожне заняття

```
git checkout main && git pull        ← стартуємо з актуального main
git checkout -b surname/lessonX_Y    ← нова гілка
  ... робота на VM ...
  ... заповнити звіт ...
git add / commit / push              ← один коміт
PR: surname/lessonX_Y → main         ← захист
Approve → merge → гілка видалена    ← залік
```

---

## Структура твого каталогу

```
cadets/surname/
├── README.md          ← VM IP, hostname, SSH публічний ключ, таблиця прогресу
└── reports/
    ├── lesson2_2.md
    ├── lesson3_3.md
    └── ...
```

---

## Правила

- PR відкривається **після** виконання роботи на VM, не до
- Звіт без виводу команд або скріншотів не приймається
- Один PR = одне заняття = один коміт
- Ламати чужу інфраструктуру заборонено. Якщо щось пішло не так — одразу повідомляй викладача

---

## Корисні команди

```bash
git status                          # що змінилось
git log --oneline -10               # останні 10 комітів
git branch -a                       # всі гілки
git checkout main && git pull       # оновити main
git branch -d surname/lesson5_6     # видалити локальну гілку після merge
```
