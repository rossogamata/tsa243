# Інструкція для курсантів

---

## Крок 1 — Налаштування середовища (один раз на початку курсу)

### 1.1 Клонувати репозиторій

```bash
git clone https://github.com/ВАШ_ORG/tsa243.git
cd tsa243/tsa_project
```

### 1.2 Створити власний branch

```bash
git checkout -b surname          # наприклад: git checkout -b petrenko
git push -u origin surname
```

### 1.3 Скопіювати шаблон

```bash
cp -r cadets/_template cadets/surname
git add cadets/surname
git commit -m "init: додаю свій каталог"
git push
```

---

## Крок 2 — Робота на кожному занятті

### На VM

Виконуй завдання відповідно до README заняття. Зберігай команди, конфіги, результати.

### У репозиторії

Після виконання:

```bash
# Перейди у свій branch
git checkout surname

# Заповни звіт по шаблону
nano cadets/surname/reports/lessonX_Y.md

# Закомітуй
git add cadets/surname/reports/lessonX_Y.md
git commit -m "lessonX_Y: коротка назва теми"
git push
```

---

## Крок 3 — Відкрити PR для захисту

1. Зайди на GitHub → репозиторій → **Pull Requests** → **New Pull Request**
2. **base:** `main` ← **compare:** `surname`
3. Заголовок: `[surname] Lesson X.Y — Назва теми`
4. Опис заповниться автоматично з шаблону — заповни всі розділи
5. Натисни **Create Pull Request**

Викладач перевіряє, залишає коментарі. Після виправлень — **Approve = залік**.

---

## Структура твого каталогу

```
cadets/surname/
├── README.md          ← про тебе: VM IP, hostname, SSH публічний ключ
└── reports/
    ├── lesson2_2.md
    ├── lesson3_3.md
    └── ...            ← один файл на практичну/групову роботу
```

---

## Правила

- Кожна практична і групова робота = окремий PR
- PR відкривається **після** виконання роботи на VM, не до
- Звіт без скріншотів або виводу команд не приймається
- Ламати спільні VM (`ns1`, `mail`, `proxy`, `mon`) — не можна. Якщо щось пішло не так — одразу повідомляй викладача

---

## Корисні команди

```bash
git status                        # що змінилось
git log --oneline -10             # останні 10 комітів
git diff                          # що саме змінилось у файлах
git pull origin main              # отримати оновлення від викладача
```
