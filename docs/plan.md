# AllyClicker — Implementation Plan (macOS / Swift)

> Фазы выполняются последовательно. Каждый шаг — атомарная единица работы.
> Источники: `references/point-n-click/config/` — готовые Swift-файлы и документация.

---

## Структура проекта (целевая)

```
AllyClicker/
├── AllyClicker.xcodeproj/
├── AllyClicker/
│   ├── App/
│   │   └── AppDelegate.swift          # Точка входа, запрос Accessibility permission
│   ├── Engine/
│   │   ├── DwellEngine.swift          # Pure state machine (из references)
│   │   └── PNCSettings.swift          # Settings model Codable (из references)
│   ├── Input/
│   │   └── InputController.swift      # CGEvent: click injection, drag, scroll
│   ├── Panel/
│   │   ├── PanelWindow.swift          # NSPanel (nonactivating, always-on-top)
│   │   ├── PanelViewController.swift  # Управление кнопками, зона панели
│   │   └── PanelButton.swift          # NSView кнопки (normal/armed, без dwell-прогресса)
│   ├── Settings/
│   │   ├── SettingsWindowController.swift
│   │   └── SettingsStore.swift        # Чтение/запись JSON
│   └── Assets.xcassets/               # Иконки из PNCIcons.xcassets
├── AllyClickerTests/
│   ├── DwellEngineTests.swift
│   └── PNCSettingsTests.swift
├── docs/
└── references/
```

---

## Фаза 1 — Фундамент (Xcode + Engine + Permissions)

> Цель: проект компилируется, инъекция клика работает, DwellEngine покрыт тестами.

### Шаг 1.1 — Создать Xcode проект
- Новый macOS App (AppKit, Swift), bundle ID `com.allyclicker.app`
- Минимальная версия: macOS 14
- Добавить `NSAccessibilityUsageDescription` в `Info.plist`
- Скопировать из `references/point-n-click/config/`:
  - `DwellEngineSpec.swift` → `Engine/DwellEngine.swift`
  - `PNCSettings.swift` → `Engine/PNCSettings.swift`
- Скопировать `PNCIcons.xcassets` → `Assets.xcassets`

### Шаг 1.2 — Accessibility permission
- `AppDelegate.swift`: при запуске — проверка `AXIsProcessTrustedWithOptions`
- Если нет доступа → `NSAlert` с инструкцией открыть System Settings → Accessibility
- Приложение должно показывать чёткое объяснение зачем разрешение нужно

### Шаг 1.3 — InputController (spike: один клик)
- `Input/InputController.swift`:
  - `leftClick(at: CGPoint)`
  - `rightClick(at: CGPoint)`
  - `doubleClick(at: CGPoint)`
  - `middleClick(at: CGPoint)`
  - `mouseDown(at: CGPoint)` / `mouseUp(at: CGPoint)`
- Реализация через `CGEvent.post(tap: .cgSessionEventTap)`
- Smoke-test: хоткей → инъекция клика в текущую позицию

### Шаг 1.4 — SettingsStore
- `Settings/SettingsStore.swift`:
  - Чтение/запись `PNCSettings` как JSON
  - Путь: `~/Library/Application Support/AllyClicker/settings.json`
  - Отсутствующий файл → дефолтные значения из `PNCSettings()`

### Шаг 1.5 — Юнит-тесты DwellEngine
- `AllyClickerTests/DwellEngineTests.swift`:
  - Тест: курсор стоит → `fire` через `dwellTimeMouseSeconds`
  - Тест: курсор двигается → таймер сбрасывается
  - Тест: курсор входит в панель → `armedAction = nil`
  - Тест: `defaultLeft = true` → после fire → `armed = .left`
  - Тест: `defaultLeft = false` → после fire → `armed = nil`

---

## Фаза 2 — NSPanel (панель без логики кликов)

> Цель: плавающая панель у края экрана, кнопки с hover-состояниями.

### Шаг 2.1 — PanelWindow
- `Panel/PanelWindow.swift`:
  - `NSPanel` subclass с `.nonactivatingPanel` style mask
  - `window.level = .floating` (или `.screenSaver - 1`)
  - Позиция: у правого края экрана, Y = 204px (из PNCSettings defaults)
  - Без заголовка, без рамки (`borderless`)

### Шаг 2.2 — PanelButton
- `Panel/PanelButton.swift` — `NSView` subclass:
  - Иконка (PDF из Assets)
  - Состояния: normal / armed (red). Состояние «armed» = красная кнопка
  - ⚠️ Dwell countdown (кружок/заполнение) НЕ реализуем — по предпочтению
    пользователя (см. spec §2). `.dwellProgress` из движка панель игнорирует

### Шаг 2.3 — PanelViewController
- `Panel/PanelViewController.swift`:
  - 7 кнопок: ON/OFF, LEFT, RIGHT, DRAG, DOUBLE, MIDDLE, KEYBOARD
  - Вертикальный stack layout
  - Hit-testing: `cursorZone(for point: CGPoint) -> CursorZone`
  - Методы обновления состояний кнопок по `DwellEffect`

### Шаг 2.4 — Сворачивание панели (ON/OFF)
- Кнопка ON/OFF: dwell → показать / скрыть остальные кнопки
- Анимация: вертикальный collapse (высота панели → только ON/OFF кнопка)

---

## Фаза 3 — Интеграция DwellEngine

> Цель: курсор останавливается → клик выполняется. Панель реагирует визуально.

### Шаг 3.1 — Polling cursor position
- `AppDelegate` или отдельный `CursorTracker`:
  - Timer каждые `trackerIntervalMs` (5мс) = `DispatchSourceTimer`
  - Читает `NSEvent.mouseLocation`
  - Вычисляет `CursorZone` через `PanelViewController.cursorZone`
  - Вызывает `engine.tick(cursor:zone:dt:)`

### Шаг 3.2 — Применение DwellEffect
- Разбор массива `[DwellEffect]` из `engine.tick`:
  - `.setArmed(action?)` → обновить red highlight на кнопке
  - `.dwellProgress(button, fraction)` → игнорируется (отсчёт не рисуем, spec §2)
  - `.clearProgress` → игнорируется (нет прогресс-бара)
  - `.fire(action, at)` → `InputController.execute(action, at: point)`
  - `.dragMouseDown/.dragMouseUp(at)` → инъекция нажатия/отпускания (DRAG)
  - Выход из приложения — через иконку в строке меню (Quit), не через панель

### Шаг 3.3 — Last position outside panel
- `CursorTracker` хранит последнюю позицию **вне панели**
- `InputController.execute` использует её как target point для клика

### Шаг 3.4 — DRAG (двухфазная механика)
- Отдельный мини-стейт-машин в `InputController`:
  - `phase1`: курсор стоит `autoselect_delay_down` → `mouseDown`
  - Пользователь двигает курсор (mouseDown удержан)
  - `phase2`: курсор стоит `autoselect_delay_up` → `mouseUp`
- Отмена при входе в панель: если `mouseDown` был → `mouseUp` немедленно

### Шаг 3.5 — Auto-Scroll (MIDDLE click режим)
> ⚠️ ПОКА НЕ ИНТЕГРИРОВАНО. Чистые части готовы (`AutoScrollEngine`,
> `AutoScrollController` + тесты), но `DwellController` сейчас роутит `.fire(.middle)`
> как обычный средний клик. Интеграция — задача Mac-фазы: нужно различать контекст
> (над ссылкой/вкладкой → обычный middle click; над прокручиваемым → auto-scroll),
> что требует macOS API. Здесь связать DwellController ↔ AutoScrollController:
- При `fire(.middle, at:)` (над прокручиваемым) → войти в Auto-Scroll режим:
  - `AutoScrollController.activate(at:)` — зафиксировать anchor
  - Запустить 60 FPS timer → `tick(cursor:)` → `CGScrollWheelEvent`
  - Любой следующий клик → `deactivate()`
  - Нелинейная скорость по алгоритму LinearMouse
- Выход: следующий `.fire` → `mouseUp` на якоре → выход из режима

---

## Фаза 4 — Settings Window

> Цель: пользователь может настроить все параметры через UI.

### Шаг 4.1 — SettingsWindowController
- `NSWindow` (обычное, не nonactivating)
- Меню-бар: **File | Options | Selections | Help**
- Открывается через `NSMenuItem` в dock menu или status bar icon

### Шаг 4.2 — Options: чекбоксы
- Default to Left Click
- Automatic Cancel
- Visible When Active
- Single Row Form
- Audio Dwelling Feedback

### Шаг 4.3 — Диалог AutoMouse Delay
- Одно поле: задержка в секундах, точность 0.1с
- Stepper / поле ввода + Ok / Cancel

### Шаг 4.4 — Диалог AutoSelect Delay
- Два поля: Параметр 1 (mouseDown) и Параметр 2 (mouseUp)

### Шаг 4.5 — Sensitivity слайдер
- Управляет `sensitivity` (px) — один параметр вместо двух низкоуровневых
- Живое превью: изменение сразу применяется к DwellEngine

### Шаг 4.6 — Transparency слайдер
- `window.alphaValue` панели (0.2 – 1.0)

### Шаг 4.7 — Конфигурация панели (состав + порядок)
- Редактор `Settings.panel.items`: список кнопок с возможностью
  добавить / убрать / перетащить (изменить порядок)
- Доступные элементы: клик-действия (left/right/drag/double/middle) + команды
  (ON/OFF, KEYBOARD)

### Шаг 4.8 — Выбор KEYBOARD-цели (3 режима)
- Radio/popup: Accessibility Keyboard / Keyboard Viewer / Стороннее приложение
- Для «стороннего» — поле пути + Browse… (NSOpenPanel)
- Пишет в `Settings.commands.keyboard: KeyboardTarget`
- Запуск целей на Mac:
  - Accessibility Keyboard — включается через Accessibility API / системную команду
  - Keyboard Viewer — `open -a "Keyboard Viewer"` / соответствующий механизм
  - customApp — `NSWorkspace.open` по пути/bundle id

### Шаг 4.9 — Прочие настройки
- About: версия, кредиты PNC, ссылка на репозиторий

---

## Фаза 5 — Полировка и дистрибуция

### Шаг 5.1 — Login item
- Запуск при входе через `SMAppService.mainApp.register()` (macOS 13+)

### Шаг 5.2 — Status bar icon
- `NSStatusItem` в меню-баре: кликнуть → показать/скрыть панель
- Контекстное меню: Settings… / Quit

### Шаг 5.3 — Audio feedback
- Звук при dwell-complete: `AudioServicesPlaySystemSound` или кастомный WAV

### Шаг 5.4 — Финальное тестирование
- Все 7 кнопок, все комбинации Default to Left Click / Automatic Cancel
- Поведение при зависшем приложении (CGEvent должен работать)
- Auto-Scroll в Safari, Chrome, Notes

### Шаг 5.5 — Сборка и дистрибуция
- Архив через Xcode → нотаризация (notarytool)
- DMG или .zip для распространения

---

## Чеклист

### Фаза 1 — Фундамент (ядро готово, собирается и тестируется на WSL)
- [x] 1.0 SPM-пакет AllyClickerCore (чистое ядро, без AppKit/CoreGraphics)
- [x] 1.0 Геометрия Point + ports (MouseInjecting/CursorSampling/ZoneMapping)
- [x] 1.0 DwellEngine: клики, two-phase drag, swipe-reset, autoCancel/defaultLeft
- [x] 1.0 DwellController: координатор движок ↔ порты
- [x] 1.0 AutoScrollEngine: алгоритм LinearMouse (pure)
- [x] 1.4 SettingsStore (JSON read/write)
- [x] 1.5 Юнит-тесты: 26 тестов, все зелёные на WSL (swift test)
- [ ] 1.1 Xcode проект (создаётся на Mac, см. App/README.md)
- [ ] 1.2 Accessibility permission check + alert (код готов в App/, нужен Mac для сборки)
- [ ] 1.3 CGMouseInjector spike (код готов, нужен Mac для проверки)

### Фаза 2 — NSPanel
- [ ] 2.1 PanelWindow (nonactivating, floating, borderless)
- [ ] 2.2 PanelButton (иконка + состояния normal/armed; БЕЗ dwell-анимации, spec §2)
- [ ] 2.3 PanelViewController (7 кнопок, hit-testing)
- [ ] 2.4 ON/OFF кнопка (сворачивание/разворачивание)

### Фаза 3 — DwellEngine интеграция
> Логика ядра готова (Фаза 1). Здесь остаётся только macOS-обвязка.
- [x] 3.4 DRAG двухфазная механика — реализована в DwellEngine (ядро)
- [x] 3.5 Auto-Scroll расчёт дельты — AutoScrollEngine (ядро); остаётся CGScrollWheelEvent адаптер
- [x] 3.3 Last position outside panel — НЕ нужно: движок стреляет только в зоне .desktop
- [ ] 3.1 Polling cursor position (DispatchSourceTimer 5мс) → вызывает DwellController.advance(dt:)
- [ ] 3.2 onUIEffect → отрисовка состояний кнопок панели
- [ ] 3.5a CGScrollWheelEvent адаптер для Auto-Scroll (MIDDLE click режим)

### Фаза 4 — Settings Window
- [ ] 4.1 SettingsWindowController + меню-бар
- [ ] 4.2 Чекбоксы Options
- [ ] 4.3 Диалог AutoMouse Delay
- [ ] 4.4 Диалог AutoSelect Delay
- [ ] 4.5 Sensitivity слайдер
- [ ] 4.6 Transparency слайдер
- [ ] 4.7 Color Selections, KEYBOARD path, About

### Фаза 5 — Полировка
- [ ] 5.1 Login item (SMAppService)
- [ ] 5.2 Status bar icon + контекстное меню
- [ ] 5.3 Audio feedback
- [ ] 5.4 Финальное тестирование
- [ ] 5.5 Сборка + нотаризация
