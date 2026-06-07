# AllyClicker — Контекст сессии

> Этот файл обновляется перед каждым коммитом.
> При старте новой сессии — прочитай этот файл первым.

---

## Статус проекта

**Текущая фаза:** Фаза 1 — Фундамент проекта
**Текущий шаг:** 1.1 — Инициализация проекта
**Последнее действие:** Составлен план, создана документация, инициализирован git-репозиторий

---

## Что сделано

- [x] Создан репозиторий: `git@github.com:umkasanki/ally-clicker.git`
- [x] Написан спек: `docs/spec.md`
- [x] Написан план по фазам с чеклистом: `docs/plan.md`

---

## Что делать в следующей сессии

**Шаг 1.1 — Инициализация проекта:**
- Создать `pyproject.toml` (Python 3.12, зависимости, точки входа)
- Создать структуру пакетов со всеми `__init__.py`
- Создать `.gitignore`
- Создать пустые точки входа `main_panel.py` и `main_configure.py`

---

## Ключевые решения и договорённости

- **Язык:** Python 3.12
- **GUI:** tkinter (встроенный)
- **Win32 input:** ctypes — `SendInput`, `SetCursorPos`, `GetCursorPos`
- **Архитектура ввода:** абстрактный `InputBackend` → `WindowsInputBackend` / `MacOSInputBackend` (будущее)
- **Конфиг:** JSON, хранится в `%APPDATA%/AllyClicker/settings.json`
- **Запуск панели:** `ally-clicker.exe` (отдельно от configure)
- **Запуск настроек:** `configure-ally-clicker.exe` (отдельно)
- **Режим редактирования:** показать diff перед применением

---

## Структура проекта (целевая)

```
ally-clicker/
├── ally_clicker/
│   ├── input/          # Абстракция + реализации InputBackend
│   ├── core/           # Бизнес-логика (dwell, tracker, state machine)
│   ├── config/         # Хранение настроек
│   ├── panel/          # Основная панель (tkinter)
│   └── configure/      # Приложение настройки (tkinter)
├── assets/icons/       # Иконки кнопок
├── tests/              # Юнит-тесты
├── docs/               # Документация
├── main_panel.py       # Точка входа панели
├── main_configure.py   # Точка входа configure
└── pyproject.toml
```

---

## Важные детали реализации

### Панель
- `overrideredirect(True)` — без рамки
- `attributes("-topmost", True)` — всегда поверх
- `WS_EX_NOACTIVATE` через ctypes — не перехватывает фокус
- Клики отправляются на **последнюю позицию курсора вне панели**
- Наведение/пересечение панели → **сброс активной функции**

### Кнопки панели
| # | ID | Действие | Таймер | Активная функция |
|---|---|---|---|---|
| 1 | ON/OFF | Развернуть/свернуть | AutoMouse Delay | — |
| 2 | LEFT | Левый клик (ЛКМ) | AutoMouse Delay | ✓ |
| 3 | RIGHT | Правый клик (ПКМ) | AutoMouse Delay | ✓ |
| 4 | SELECTION | Выделение | AutoSelect Delay (×2) | ✓ |
| 5 | DOUBLE | Двойной клик | AutoMouse Delay | ✓ |
| 6 | MIDDLE | Клик колёсиком | AutoMouse Delay | ✓ |
| 7 | KEYBOARD | Запуск приложения | AutoMouse Delay | — |

### Логика активной функции
- **Automatic Cancel ON** → сброс после первого выполнения
- **Automatic Cancel OFF** → повтор при каждой остановке курсора
- **Default to Left Click ON** → после выполнения/сброса активной становится ЛКМ
- **Сброс** → наведение или пересечение зоны панели

### Selection (выделение) — двухфазная механика
1. Курсор стоит `autoselect_delay_down` → `mouse_down`
2. Пользователь перемещает курсор
3. Курсор стоит `autoselect_delay_up` → `mouse_up`

---

## Ссылки

- Репозиторий: https://github.com/umkasanki/ally-clicker
- Спек: `docs/spec.md`
- План: `docs/plan.md`
- Аналог: https://polital.com/pnc/
