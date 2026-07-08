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
- [x] 1.0 DwellEngine: re-fire gate (нет машингана), safety-release зажатой кнопки
- [x] 1.0 DwellEngine: командные кнопки (ON/OFF, KEYBOARD) — one-shot, без флапа
- [x] 1.0 DwellController: координатор движок ↔ порты (onUIEffect/onCommand, release при teardown)
- [x] 1.0 AutoScrollEngine + AutoScrollController: алгоритм LinearMouse + режим (pure)
- [x] 1.0 Конфигурируемая панель: PanelItem + Settings.panel.items (состав + порядок) с нормализацией
- [x] 1.0 KeyboardTarget: 3 режима (accessibility/viewer/custom)
- [x] 1.4 SettingsStore (JSON read/write) + устойчивый к отсутствующим ключам decode
- [x] 1.5 Юнит-тесты: 58 тестов, все зелёные на WSL и в CI (GitHub Actions)
- [x] 1.2 Accessibility permission check + alert (работает; сейчас debug-режим без гейта)
- [x] 1.3 CGMouseInjector собран против реального AppKit (инъекция вживую ещё не проверена)
- [ ] 1.1 Xcode проект — теперь нужен в основном для стабильной подписи
  (ad-hoc подпись слетает при пересборке → Accessibility каждый раз заново).
  Временная замена: `App/build-app.sh` (сборка без Xcode) — работает

### Фаза 2 — NSPanel ✅ (работает вживую на Mac, визуал утверждён)
- [x] 2.1 PanelWindow (nonactivating, statusBar level, immune к desktop-reveal, скругления 12pt)
- [x] 2.2 PanelButton (иконки проекта PDF 48/42/36, normal/armed, pointing-hand курсор)
- [x] 2.3 PanelViewController (кнопки из panel.items, hit-testing, зажим в экран)
- [x] 2.4 ON/OFF: сворачивание/разворачивание с анимацией + drag-to-move панели
- [x] 2.5 Скользящая красная плашка (ease-in-out), заезжает и под команды,
  fade с ON/OFF через 1с после сворачивания

### Фаза 3 — DwellEngine интеграция
> Логика ядра готова (Фаза 1). macOS-обвязка подключена и работает вживую.
- [x] 3.1 DwellRunner (DispatchSourceTimer 5мс) → DwellController.advance(dt:)
- [x] 3.2 onUIEffect → плашка/подсветка; onCommand → toggle/keyboard
- [x] 3.4 DRAG двухфазная механика — проверена вживую (выделение/область работают)
- [x] 3.5 Auto-Scroll расчёт дельты — AutoScrollEngine (ядро)
- [x] 3.3 Last position outside panel — НЕ нужно: движок стреляет только в зоне .desktop
- [x] 3.6 Инъекция кликов + Y-flip — проверено вживую (LEFT/RIGHT/DOUBLE/DRAG)
- [x] 3.5a Auto-Scroll (MIDDLE) — ГОТОВО вживую: CGScrollWheelEvent, якорь-точка,
  динамическая скорость + intensity-множитель (дефолт 0.5), dwell→ЛКМ+выход,
  мазок по панели→выход. Умный клик по ссылке (AX AXLink → средний клик/новая
  вкладка) в Safari/Firefox. Chrome — нужен AXManualAccessibility (отложено).

### Фаза 4 — Settings Window (SwiftUI, применение по кнопке Apply)

**Решения:** SwiftUI в NSWindow (через NSHostingController); изменения
применяются по кнопке **Apply** (правит рабочую копию → save → применить к
запущенному приложению), Cancel отменяет. **Доступность:** окно управляется
dwell-кликами (ЛКМ), поэтому вместо перетаскиваемых слайдеров — **степперы «−/+»**
и дискретные кнопки (как ◄ ► в PNC); слайдер только там, где степпер неудобен.

#### 4.0 — Инфраструктура (сначала)
- [x] 4.0.1 Status bar icon (`NSStatusItem`, иконка из references/menu-bar-icon)
  с меню: «Настройки…», «Выход». ВАЖНО: сейчас у приложения нет способа выйти —
  этот пункт решает и запуск настроек, и Quit.
- [x] 4.0.2 `SettingsWindowController` + SwiftUI-хост; при открытии `NSApp.activate`
  (мы .accessory) — окно должно принимать фокус/ввод (в отличие от панели)
- [x] 4.0.3 Apply/Cancel: SwiftUI редактирует рабочую копию `Settings`; Apply →
  валидация → `SettingsStore.save` → `applyToRunningApp` (updateSettings движка,
  пересоздать AutoScroller, пересобрать панель при структурных изменениях)

#### 4.1 — Секции формы
- [x] 4.1.1 Тайминги (степперы 0.01с): AutoMouse Delay (авто-клик по экрану =
  `dwellTimeMouseMs`), задержка кнопки панели (`dwellTimeMs`), AutoSelect down/up (drag)
- [x] 4.1.2 Sensitivity — Jitter tolerance (`sensitivity`) + Move threshold
  (`moveRadiusPx`) отдельными контролами в группе «Cursor precision»
- [x] 4.1.3 Поведение: Default to Left (toggle), Automatic Cancel (toggle),
  Idle-disarm в минутах (степпер, 0 = выкл)
- [x] 4.1.4 Auto-scroll: intensity (степпер 0.25×); продвинутое
  (deadZone, boost) — под раскрывашкой [не выведено, задел на будущее]
- [x] 4.1.5 Редактор панели: вкладка Panel — список `panel.items`
  (добавить/убрать/переставить стрелками), width, transparency (opacity %),
  выбор стиля иконок (Custom/System). KEYBOARD убрана из панели (переедет на
  отдельную панель). Осталось: кнопка «сбросить позицию» — в бэклог
- [ ] 4.1.6 KEYBOARD-цель: radio (Accessibility Keyboard / Keyboard Viewer /
  стороннее + выбор файла). Действие пока отложено, но значение настраивается
- [x] 4.1.7 About: вкладка About — иконка, версия (из Bundle), кредиты
  (PNC/DwellClick/LinearMouse) с ссылками, ссылка на репозиторий; футер скрыт на About

#### 4.2 — Применение структурных изменений
- [x] 4.2.1 Пересборка панели при смене items/width/transparency/iconStyle
  (без перезапуска) — `PanelViewController.rebuild(with:)`, тот же экземпляр/окно;
  живая позиция панели сохраняется на Apply
- [x] 4.2.2 Пересоздание/обновление AutoScroller и движка при смене таймингов/скролла
  (на Apply: `controller.updateSettings` + `rebuildAutoScroller`). Оговорка: частота
  `DwellRunner` (`trackerIntervalMs`) не пересоздаётся live — параметр не выведен в
  UI, зашит 5 мс; пересоздание раннера — в бэклог, если когда-нибудь выведем)
- [ ] 4.2.3 Проверка на устройстве: всё управляется dwell-кликами

### Фаза 5 — Полировка
- [x] 5.1 Login item (SMAppService) — тумблер «Launch at login» в Behavior/Startup,
  регистрирует/снимает `SMAppService.mainApp`, применяется сразу. Проверено (виден в
  «Объектах входа»)
- [x] 5.2 Audio feedback — системные звуки на арм кнопки и срабатывание клика
  (`SoundPlayer`, `controller.onFired`, гейт `appearance.audio`). НЕ проверено на слух
  (не было доступа к динамикам) — подтвердить звучание позже
- [ ] 5.3 Финальное тестирование
- [x] 5.4 Сборка + установка — `App/install.sh` собирает и ставит в `/Applications`
  (стабильный путь для иконки, Accessibility-гранта, login item). Проверено.
  Нотаризация — отложена до распространения на другие Маки (нужен Apple Developer ID)
- [ ] Косметика: курсор при перемещении панели; KEYBOARD toggle (отложено)

### Реализованные фичи (сверх базового PNC)
- [x] Auto-scroll intensity — множитель скорости скролла (`autoScroll.intensity`, дефолт 0.5)
- [x] Idle-disarm — авто-снятие функции после простоя курсора (`clicks.idleDisarmSeconds`, дефолт 120с)
- [x] Умный MIDDLE — над ссылкой средний клик, иначе auto-scroll (AX-детект)
- [x] Ориентация панели — вертикальная/горизонтальная (гориз. дефолт: сверху по центру)
- [x] Стиль и размер иконок кнопок — Custom/System + масштаб 50–150%
- [x] ON/OFF опциональна, но закреплена первой; «Launch collapsed» (старт свёрнутым)
- [x] Иконка приложения v2 (`.icns`) + скилл `macos-app-icon` для генерации

### Бэклог (подтверждено автором PNC, 2026-06-29 — см. spec «Дополнение по переписке»)
- [x] Адаптивный dwell — формула в ядре (`Settings.Calibration.computedDwellMs`). Готова.
- [ ] Калибровка = ОДНОРАЗОВЫЙ ПОСЕВ (уточнено пользователем): baseline-тест при
  установке/первом запуске вычисляет dwell по формуле и **записывает результат в
  `dwellTimeMouseMs`**; дальше это обычное редактируемое значение (можно переопределить
  в настройках). НЕ живая формула каждый тик. → упростить: убрать
  `calibration.enabled`/`effectiveDwellMouseSeconds`-переключение, сделать кнопку
  «Calibrate» в настройках, которая один раз прогоняет тест и пишет в dwellTimeMouseMs.
  Замер `averageVelocity` + подбор `multiplier` под точки macOS — на Mac.
- [ ] `RightLeft` (right-затем-left) — реализовать в InputController + добавить как PanelItem
- [ ] RAMB (Remote Access Mouse Button) — плавающий якорь поверх fullscreen (Фаза 5+)
- [ ] Break-timer (`UseTimer`/`UseTimerReset`) — напоминания об отдыхе (опционально)

### Бэклог ревью app-слоя (Mac-сессия) — приоритеты по убыванию
- [x] **C1. Стабильная подпись — СДЕЛАНО.** Отдельный keychain
  `allyclicker.keychain-db` + self-signed "AllyClicker Self-Signed".
  `App/setup-signing.sh` настраивает (работает по SSH, неинтерактивно),
  `build-app.sh` подписывает им. Accessibility привязан к подписи, при
  пересборке не слетает. Сборка/подпись идут удалённо по SSH
- [ ] **C2. Перемещение панели головой** — сейчас drag за ON/OFF работает только
  физической мышью. Нужен осознанный «режим перемещения» (dwell-armed), т.к.
  движок стреляет drag только в зоне .desktop, а над кнопкой — .panelCommand
- [ ] **I2. Dwell под нагрузкой растягивается** — фиксированный dt=5мс vs wall-clock;
  перейти на реальное время с капом (~50мс), чтобы паузы не давали мгновенный fire
- [ ] **I3. KEYBOARD не запускается** — прямой запуск KeyboardViewer.app не работает
  с ~Catalina; проверить и починить (input-source / Accessibility Keyboard toggle)
- [ ] **I4. Нереализованные действия молча ничего не делают** (`rightDouble`,
  `rightThenLeft`) — убрать из normalize пока не реализованы, или fallback
- [x] Сохранение позиции панели между запусками — ГОТОВО (positionX/Y в settings.json)
- [x] Перемещение панели головой (C2) — ГОТОВО: DRAG + dwell на ON/OFF → move mode,
  панель едет за курсором, остановка роняет. Логика через CursorPolicy/onZone.
- [ ] **Косметика: курсор при перемещении/превью НЕ меняется** (всегда pointer).
  Пробовали: set() из таймера, push/pop, cursorUpdate, централизованный CursorPolicy
  по зоне+intent — не сработало (фоновое nonactivating-окно + SetsCursorInBackground,
  видимо, не даёт сменить на closedHand/crosshair). Функционально move работает,
  визуально курсор — на последние косметические штрихи. Возможные пути: NSTrackingArea
  с cursorUpdate только на ON/OFF; кастомный курсор-картинка; или временный overlay.
- [ ] Минорное: залипание drag при потере mouseUp (проверять `pressedMouseButtons`);
  `mouseExited` не сбивать чужой курсор; наблюдатель
  `didChangeScreenParametersNotification` для re-clamp; хрупкий glob в build

### Debug-хвосты — все возвращены к боевому виду ✅
- [x] Панель докается к правому краю / сохранённой позиции (не центр)
- [x] Accessibility: системный prompt (добавляет бинарь в список + диалог настроек)
- [x] Инъекция кликов + Y-flip проверены вживую; отладочные NSLog убраны
