# AllyClicker — Implementation Plan

> Фазы выполняются последовательно. Каждый шаг — атомарная единица работы,
> которую можно реализовать и закоммитить отдельно.

---

## Структура проекта

```
ally-clicker/
├── ally_clicker/
│   ├── __init__.py
│   ├── input/                  # Слой ввода (абстракция + реализации)
│   │   ├── __init__.py
│   │   ├── base.py             # Абстрактный InputBackend
│   │   ├── windows.py          # Windows: SendInput, GetCursorPos
│   │   └── macos.py            # macOS: CGEventPost (будущее)
│   ├── core/                   # Бизнес-логика, не зависит от GUI
│   │   ├── __init__.py
│   │   ├── cursor_tracker.py   # Фоновый трекинг позиции курсора
│   │   ├── dwell.py            # Движок dwell-click (таймер, отмена)
│   │   ├── active_function.py  # Стейт-машина текущей активной функции
│   │   └── settings.py         # Модель настроек (dataclass)
│   ├── config/                 # Хранение настроек
│   │   ├── __init__.py
│   │   └── store.py            # Чтение/запись JSON-конфига
│   ├── panel/                  # Основная панель
│   │   ├── __init__.py
│   │   ├── app.py              # Точка входа панели
│   │   ├── window.py           # Окно панели (tkinter)
│   │   └── buttons/
│   │       ├── __init__.py
│   │       ├── base.py         # Базовый класс кнопки
│   │       ├── on_off.py
│   │       ├── left_click.py
│   │       ├── right_click.py
│   │       ├── selection.py
│   │       ├── double_click.py
│   │       ├── middle_click.py
│   │       └── keyboard.py
│   └── configure/              # Приложение настройки
│       ├── __init__.py
│       ├── app.py              # Точка входа configure
│       ├── window.py           # Главное окно Configure AllyClicker
│       └── dialogs/
│           ├── __init__.py
│           ├── auto_mouse_delay.py
│           ├── auto_select_delay.py
│           ├── sensitivity.py
│           ├── transparency.py
│           ├── form_size.py
│           ├── automouse_functions.py
│           ├── color_selections.py
│           └── about.py
├── assets/
│   └── icons/                  # SVG/PNG иконки кнопок
├── tests/
│   ├── test_dwell.py
│   ├── test_active_function.py
│   ├── test_config.py
│   └── test_input_backend.py
├── docs/
│   ├── spec.md
│   └── plan.md
├── main_panel.py               # $ python main_panel.py
├── main_configure.py           # $ python main_configure.py
└── pyproject.toml
```

---

## Фаза 1 — Фундамент проекта

> Цель: настроить окружение, зависимости, базовые абстракции. Без GUI.

### Шаг 1.1 — Инициализация проекта
- Создать `pyproject.toml` (Python 3.12, зависимости, точки входа)
- Создать структуру пакетов (`__init__.py` во всех директориях)
- Настроить `.gitignore`
- Создать `main_panel.py` и `main_configure.py` — пустые точки входа

### Шаг 1.2 — Модель настроек
- `core/settings.py` — датакласс `Settings` со всеми параметрами:
  - `automouse_delay: float` (по умолч. 0.80)
  - `autoselect_delay_down: float` (по умолч. 0.32)
  - `autoselect_delay_up: float` (по умолч. 0.21)
  - `default_to_left_click: bool`
  - `automatic_cancel: bool`
  - `run_at_boot: bool`
  - `visible_when_active: bool`
  - `audio_feedback: bool`
  - `transparency: float`
  - `panel_direction: str` ("right" | "down")
  - `keyboard_app_path: str` (по умолч. "osk.exe")
  - `sensitivity: float`
  - `panel_position: tuple[int, int]`

### Шаг 1.3 — Хранение конфига
- `config/store.py` — класс `ConfigStore`:
  - Читает/пишет `settings.json` в папке пользователя (`%APPDATA%/AllyClicker/`)
  - Методы: `load() -> Settings`, `save(settings: Settings)`
  - Обработка отсутствующего файла → возврат дефолтных значений

### Шаг 1.4 — Абстрактный InputBackend
- `input/base.py` — абстрактный класс `InputBackend`:
  - `left_click(x, y)`
  - `right_click(x, y)`
  - `double_click(x, y)`
  - `middle_click(x, y)`
  - `mouse_down(x, y)`
  - `mouse_up(x, y)`
  - `move_cursor(x, y)`
  - `get_cursor_pos() -> tuple[int, int]`

### Шаг 1.5 — Windows InputBackend
- `input/windows.py` — класс `WindowsInputBackend(InputBackend)`:
  - Реализация всех методов через `ctypes` + `SendInput`
  - `SetCursorPos`, `GetCursorPos`
  - Структуры `MOUSEINPUT`, `INPUT`
  - Выполнение в отдельном потоке (не блокирует GUI)

### Шаг 1.6 — Фабрика InputBackend
- `input/__init__.py` — функция `get_backend() -> InputBackend`:
  - Определяет платформу (`sys.platform`)
  - Возвращает нужный бэкенд
  - На не-Windows платформе — заглушка с `NotImplementedError`

---

## Фаза 2 — Движок ядра (Core Engine)

> Цель: реализовать всю бизнес-логику без GUI. Покрыть тестами.

### Шаг 2.1 — Cursor Tracker
- `core/cursor_tracker.py` — класс `CursorTracker`:
  - **Не polling** — подписка на глобальные события мыши через `WH_MOUSE_LL` hook (Windows low-level mouse hook via ctypes). Аналог `CGEventTap` из DwellClick (macOS)
  - Hook срабатывает на каждое движение мыши — точнее и эффективнее чем цикл каждые 50мс
  - Хранит `last_pos_outside_panel: tuple[int, int]`
  - Принимает callback `is_in_panel(x, y) -> bool` для определения зоны панели
  - Публичный метод `get_last_outside_pos() -> tuple[int, int]`
  - Методы `start()`, `stop()`
  - Hook живёт в отдельном потоке с win32 message loop

### Шаг 2.2 — Dwell Engine
- `core/dwell.py` — класс `DwellEngine`:
  - **Стейт-машина** (по аналогии с DwellClick): `Off → MoveDetect → DwellDetect → ButtonDown`
    - `MoveDetect` — мышь двигается, ждём остановки
    - `DwellDetect` — мышь остановилась, отсчёт таймера
    - `ButtonDown` — пауза если пользователь сам нажал физическую кнопку
  - **Jitter radius** (`dwell_radius`, дефолт 2px) — курсор считается остановившимся пока не вышел за радиус
  - **Move radius** (`move_radius`, дефолт 10px) — минимальное смещение для регистрации движения и сброса таймера
  - Оба радиуса берутся из `Settings.sensitivity`
  - Методы: `start(callback)`, `cancel()`
  - Использует `threading.Timer`
  - Потокобезопасен

### Шаг 2.3 — Стейт-машина активной функции
- `core/active_function.py` — класс `ActiveFunctionManager`:
  - Хранит текущую активную функцию (`FunctionType` enum: LEFT, RIGHT, SELECTION, DOUBLE, MIDDLE, NONE)
  - Методы:
    - `set_active(fn: FunctionType)`
    - `get_active() -> FunctionType`
    - `reset()` — сброс (с учётом Default to Left Click)
    - `on_action_executed()` — вызывается после выполнения действия (с учётом Automatic Cancel)
  - Принимает `Settings` как зависимость

### Шаг 2.4 — Тесты ядра
- `tests/test_dwell.py` — тесты DwellEngine (срабатывание, отмена, смена задержки)
- `tests/test_active_function.py` — тесты всех комбинаций Default to Left Click / Automatic Cancel
- `tests/test_config.py` — тесты сохранения/загрузки настроек

---

## Фаза 3 — Основная панель (UI)

> Цель: отображение панели, кнопки без логики кликов.

### Шаг 3.1 — Базовое окно панели
- `panel/window.py` — класс `PanelWindow`:
  - `tkinter.Tk`, `overrideredirect(True)`, `attributes("-topmost", True)`
  - `WS_EX_NOACTIVATE` через `ctypes` — не перехватывает фокус
  - Позиционирование у правого края экрана
  - Метод `is_in_panel(x, y) -> bool` для CursorTracker

### Шаг 3.2 — Базовый класс кнопки
- `panel/buttons/base.py` — класс `BaseButton`:
  - Обёртка над `tkinter.Frame` + `tkinter.Label`
  - Поддержка иконки и подписи
  - Состояния: `NORMAL`, `HOVER`, `ACTIVE` (текущая активная функция), `FIRED`
  - Методы: `set_state(state)`, `on_enter()`, `on_leave()`
  - Хук `on_dwell_complete()` — переопределяется в подклассах
  - Интеграция с `DwellEngine`

### Шаг 3.3 — Кнопка ON/OFF
- `panel/buttons/on_off.py` — класс `OnOffButton(BaseButton)`:
  - Иконка питания
  - По dwell: разворачивает / сворачивает панель
  - Анимация разворота (вправо или вниз, из настроек)

### Шаг 3.4 — Иконки кнопок
- Создать иконки для всех 7 кнопок (PNG 48×48)
- Подключить к кнопкам через `tkinter.PhotoImage`

### Шаг 3.5 — Все кнопки панели (UI-оболочки, без действий)
- Реализовать классы для кнопок 2-7, наследующихся от `BaseButton`
- Только визуал и hover-состояния, без реальных кликов

### Шаг 3.6 — Сборка панели
- `panel/app.py` — создаёт `PanelWindow`, монтирует все кнопки, запускает `CursorTracker`
- `main_panel.py` — вызывает `panel/app.py`

---

## Фаза 4 — Действия кнопок

> Цель: подключить реальные клики и логику активной функции.

### Шаг 4.1 — Подключение InputBackend к панели
- Инициализация `get_backend()` в `panel/app.py`
- Передача бэкенда в каждую кнопку

### Шаг 4.2 — LEFT click
- `panel/buttons/left_click.py`:
  - По dwell: получает `last_outside_pos` из `CursorTracker`
  - Вызывает `backend.left_click(x, y)` в отдельном потоке
  - Уведомляет `ActiveFunctionManager.on_action_executed()`

### Шаг 4.3 — RIGHT click
- Аналогично LEFT, `backend.right_click(x, y)`

### Шаг 4.4 — DOUBLE click
- Аналогично LEFT, `backend.double_click(x, y)`

### Шаг 4.5 — MIDDLE click
- Аналогично LEFT, `backend.middle_click(x, y)`

### Шаг 4.6 — SELECTION (двухфазное выделение)
- `panel/buttons/selection.py`:
  - Фаза 1: курсор стоит `autoselect_delay_down` → `backend.mouse_down(x, y)`
  - Фаза 2: курсор стоит `autoselect_delay_up` → `backend.mouse_up(x, y)`
  - Использует отдельный `DwellEngine` с двумя задержками
  - Отмена (наведение на панель) → `mouse_up` если ЛКМ была зажата

### Шаг 4.7 — KEYBOARD
- `panel/buttons/keyboard.py`:
  - По dwell: запускает `settings.keyboard_app_path` через `subprocess.Popen`
  - Не является активной функцией

### Шаг 4.8 — Сброс по наведению на панель
- В `CursorTracker`: при входе курсора в зону панели → вызов `ActiveFunctionManager.reset()`
- Быстрое пересечение (без задержки) тоже триггерит сброс

---

## Фаза 5 — Приложение настройки (Configure)

> Цель: полноценное окно Configure AllyClicker с меню и диалогами.

### Шаг 5.1 — Главное окно Configure
- `configure/window.py` — стандартное `tkinter.Tk` окно
- Меню-бар: File | Options | Selections | Help
- При закрытии — только скрывает окно (панель продолжает работать)

### Шаг 5.2 — Меню File
- Exit: завершить оба процесса (панель + configure)

### Шаг 5.3 — Меню Options: чекбоксы
- Default to Left Click
- Automatic Cancel
- Visible When Active
- Single Row Form
- Audio Dwelling Feedback
- Каждый чекбокс сразу сохраняет изменение в `ConfigStore` и применяет к панели

### Шаг 5.4 — Меню Options: Run at Boot Up
- Добавление/удаление записи в реестре Windows (`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`)

### Шаг 5.5 — Диалог AutoMouse Delay
- `configure/dialogs/auto_mouse_delay.py`
- Одно поле: задержка в секундах, точность 0.1с
- Виджет: поле + кнопки ◄ ► + Ok / Cancel

### Шаг 5.6 — Диалог AutoSelect Delay
- `configure/dialogs/auto_select_delay.py`
- Два поля: Параметр 1 (mouse_down) и Параметр 2 (mouse_up)
- Тот же виджет ◄ ►

### Шаг 5.7 — Диалог Sensitivity
- `configure/dialogs/sensitivity.py`
- *Описание будет уточнено из spec.md*

### Шаг 5.8 — Диалог Transparency
- `configure/dialogs/transparency.py`
- Слайдер прозрачности панели (0–100%)
- Применяется через `window.attributes("-alpha", value)`

### Шаг 5.9 — Диалог Change Form Size
- `configure/dialogs/form_size.py`
- Настройка размера кнопок панели (ширина / высота)

### Шаг 5.10 — Меню Selections: AutoMouse Functions
- `configure/dialogs/automouse_functions.py`
- *Описание будет уточнено из spec.md*

### Шаг 5.11 — Меню Selections: Color Selections
- `configure/dialogs/color_selections.py`
- Выбор цветов для состояний кнопок (NORMAL, HOVER, ACTIVE, FIRED)

### Шаг 5.12 — Меню Help: About
- `configure/dialogs/about.py`
- Версия, описание, ссылка на репозиторий

---

## Фаза 6 — Интеграция и полировка

> Цель: связать configure и panel, добавить оставшиеся фичи.

### Шаг 6.1 — IPC между panel и configure
- Механизм передачи изменённых настроек из configure в panel без перезапуска
- Вариант: общий `ConfigStore` + периодический `polling` или `watchdog` на файл конфига

### Шаг 6.2 — Visible When Active
- Панель видна только когда активна какая-либо функция
- В остальное время — скрыта или полупрозрачна

### Шаг 6.3 — Audio Dwelling Feedback
- Звуковой сигнал при срабатывании dwell (системный beep через `winsound`)

### Шаг 6.4 — Настройка пути к KEYBOARD приложению
- Поле в Configure для ввода пути к exe
- Кнопка «Browse» для выбора файла через диалог

### Шаг 6.5 — Финальное тестирование
- Ручное тестирование всех кнопок
- Проверка поведения при зависании целевых приложений
- Проверка всех комбинаций Default to Left Click / Automatic Cancel

---

## Фаза 7 — Сборка и дистрибуция

> Цель: собрать два exe-файла для Windows.

### Шаг 7.1 — PyInstaller: panel
- Скрипт сборки `build_panel.py`
- Результат: `dist/ally-clicker.exe`
- Иконка приложения

### Шаг 7.2 — PyInstaller: configure
- Скрипт сборки `build_configure.py`
- Результат: `dist/configure-ally-clicker.exe`

### Шаг 7.3 — README
- Установка, запуск, зависимости

---

## Чеклист

### Фаза 1 — Фундамент проекта
- [ ] 1.1 Инициализация проекта (pyproject.toml, структура папок, .gitignore)
- [ ] 1.2 Модель настроек (датакласс Settings)
- [ ] 1.3 Хранение конфига (ConfigStore, JSON)
- [ ] 1.4 Абстрактный InputBackend
- [ ] 1.5 Windows InputBackend (SendInput через ctypes)
- [ ] 1.6 Фабрика InputBackend (определение платформы)

### Фаза 2 — Движок ядра
- [ ] 2.1 CursorTracker (фоновый поток, last_outside_pos)
- [ ] 2.2 DwellEngine (таймер, отмена)
- [ ] 2.3 ActiveFunctionManager (стейт-машина)
- [ ] 2.4 Тесты ядра

### Фаза 3 — Основная панель (UI)
- [ ] 3.1 Базовое окно (topmost, no focus, позиция)
- [ ] 3.2 Базовый класс кнопки
- [ ] 3.3 Кнопка ON/OFF (сворачивание/разворачивание)
- [ ] 3.4 Иконки кнопок
- [ ] 3.5 Все 7 кнопок (только визуал)
- [ ] 3.6 Сборка панели

### Фаза 4 — Действия кнопок
- [ ] 4.1 Подключение InputBackend к панели
- [ ] 4.2 LEFT click
- [ ] 4.3 RIGHT click
- [ ] 4.4 DOUBLE click
- [ ] 4.5 MIDDLE click
- [ ] 4.6 SELECTION (двухфазное выделение)
- [ ] 4.7 KEYBOARD (запуск приложения)
- [ ] 4.8 Сброс по наведению на панель

### Фаза 5 — Приложение настройки (Configure)
- [ ] 5.1 Главное окно + меню-бар
- [ ] 5.2 Меню File (Exit)
- [ ] 5.3 Чекбоксы Options
- [ ] 5.4 Run at Boot Up (реестр Windows)
- [ ] 5.5 Диалог AutoMouse Delay
- [ ] 5.6 Диалог AutoSelect Delay
- [ ] 5.7 Диалог Sensitivity
- [ ] 5.8 Диалог Transparency
- [ ] 5.9 Диалог Change Form Size
- [ ] 5.10 AutoMouse Functions
- [ ] 5.11 Color Selections
- [ ] 5.12 About

### Фаза 6 — Интеграция и полировка
- [ ] 6.1 IPC между panel и configure
- [ ] 6.2 Visible When Active
- [ ] 6.3 Audio Feedback
- [ ] 6.4 Настройка пути к KEYBOARD приложению
- [ ] 6.5 Финальное тестирование

### Фаза 7 — Сборка и дистрибуция
- [ ] 7.1 PyInstaller: ally-clicker.exe
- [ ] 7.2 PyInstaller: configure-ally-clicker.exe
- [ ] 7.3 README
