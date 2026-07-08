# AllyClicker — Контекст сессии

> Этот файл обновляется перед каждым коммитом.
> При старте новой сессии — прочитай этот файл первым.

---

## Статус проекта

**Текущая фаза:** Фаза 4 (Settings) и большая часть Фазы 5 ЗАВЕРШЕНЫ.
Приложение установлено в `/Applications`, работает как настоящее.
**Последнее действие:** перерыв. Настройки, редактор панели, ориентация,
звук, автозапуск, иконка v2, установка в `/Applications` — готовы и закоммичены.

### 🎯 Точка остановки (перерыв после Фазы 5.4)
Сделано в этой сессии (всё в git):
- **Настройки (3 вкладки):** Behavior (тайминги, поведение, Cursor precision,
  Sound, Startup/Launch-at-login), Panel (ориентация, редактор кнопок с тумблерами,
  стиль/размер иконок, ширина, прозрачность, Launch collapsed), About (иконка,
  версия, кредиты, ссылка). Футер: Reset / Cancel / **Save** (применяет + закрывает).
- **Редактор панели** (4.1.5) + live-пересборка (4.2.1); ON/OFF закреплена первой,
  но опциональна; KEYBOARD убрана (переедет на отдельную панель).
- **Ориентация** панели V/H (гориз. дефолт — сверху по центру).
- **Звук** (5.2): системные звуки на арм/клик, гейт `appearance.audio`. НЕ проверен на слух.
- **Автозапуск** (5.1): `SMAppService`, тумблер Launch at login — проверен.
- **Иконка v2** (`.icns`) + скилл `macos-app-icon` (в `~/.claude/skills` и в репо).
- **Установка** (5.4): `App/install.sh` → `/Applications`.

Осталось:
- 4.1.6 KEYBOARD-цель — отложено до отдельной панели клавиатуры.
- 5.3 финальный прогон всех функций вживую.
- Нотаризация — только для раздачи (нужен Apple Developer ID).
- Косметика: курсор при перетаскивании панели.
- Экран входа (loginwindow): наше приложение туда не может; использовать
  встроенные Dwell + Универсальную клавиатуру macOS.

### Проверено вживую (работает)
- LEFT / RIGHT / DOUBLE клики; DRAG (выделение/область)
- MIDDLE: auto-scroll (якорь, динамика, intensity=0.5) + умный клик по ссылке →
  новая вкладка (Safari/Firefox). Выход из скролла: **перестал водить курсором
  (замер на месте) → автоклик ЛКМ + выход** (как обычный dwell); либо мазок по панели
- Панель: сворачивание, перемещение головой (DRAG+ON/OFF), сохранение позиции,
  immune к desktop-reveal, зажим в экран, тёмная тема, скользящая плашка
- Стабильная подпись (грант не слетает); авто-снятие функции после 2 мин простоя

### Исправления по ревью сессии (все закрыты)
- Runaway scroll: intensity зажат в [0.05, 5.0] + clamp maxSpeed ПОСЛЕ множителя
- «Мёртвый» dwell после скролла: advance() прерывает эффекты тика при willFire-перехвате
- AX без таймаута → `AXUIElementSetMessagingTimeout(0.1)` (зависшее приложение не морозит)
- Идемпотентность таймеров (`guard timer == nil`) в Runner/AutoScroller/beginMove

### Доступ к Mac
- SSH: `ssh mishkin@100.126.136.17`, проект в `~/projects/ally-clicker`
- macOS 26.3.1 (arm64), Xcode 26.6 установлен, лицензия принята
- Все 72 теста проходят на Mac (`swift test`) и на Linux-CI
- Сборка без Xcode-проекта: `./App/build-app.sh` → `build/AllyClicker.app`
  (swift build + swiftc против AppKit + ad-hoc codesign)
- Цикл итерации: правка на WSL → commit/push → `ssh … git pull && ./App/build-app.sh && pkill … && open …`
- GUI запускать может только пользователь на самом Mac (SSH `open` работает,
  но скриншоты/GUI-интеракции — нет)

### 🎯 Точка остановки (пауза на Фазе 4 — Settings Window)
Фаза 4.0 (инфраструктура) + большинство 4.1 ГОТОВО вживую:
- Статус-бар иконка (курсор) → меню Settings… / Quit (единственный способ выйти)
- Окно настроек: SwiftUI в NSWindow, тёмная тема, крупные шрифты, группы (GroupBox),
  запоминает позицию (UserDefaults `AllyClickerSettingsFrame`)
- `ValueControl`: слайдер + круглые −/+ + поле, синхронно; пояснение под каждым
- Секции: Timing (шаг 0.01с), Sensitivity, Behavior, Auto-scroll
- Apply (live-apply engine-параметров через updateSettings + rebuildAutoScroller),
  Cancel, Reset to defaults (только поля формы)
- Ревью Фазы 4 отработано: NSWindowDelegate (крестик=Cancel), Reset не трогает
  скрытые поля, rebuildAutoScroller.stop() перед заменой

**СЛЕДУЮЩИЙ ШАГ — доделать Фазу 4:**
- 4.1.5 Редактор панели: состав/порядок `panel.items` (add/remove/reorder),
  width, transparency, «сбросить позицию» + **пересборка панели на лету**
  (applySettings сейчас применяет только engine-параметры, панель НЕ трогает)
- 4.1.6 Выбор KEYBOARD-цели (3 режима) — значение настраивается, действие отложено
- 4.1.7 About (версия, кредиты PNC, ссылка)

Файлы Settings: `App/AllyClicker/Settings/{SettingsView, ValueControl, SettingsModel,
SettingsWindowController}.swift`, `StatusBar/StatusBarController.swift`.
applySettings + rebuildAutoScroller — в `App/AllyClicker/App/AppDelegate.swift`.

---

### Архив: предыдущая точка остановки
- **C1 стабильная подпись — ГОТОВО и проверено.** Keychain `allyclicker.keychain-db`
  (пароль `allyclicker`), self-signed "AllyClicker Self-Signed". `setup-signing.sh`
  настраивает (по SSH), `build-app.sh` подписывает. При пересборке грант не слетает.
  ВАЖНО: при первой выдаче доступа для НОВОЙ подписи надо сбросить старый TCC-грант:
  `tccutil reset Accessibility com.allyclicker.app`, затем включить тумблер заново.
- **Инъекция кликов + Y-flip — ПРОВЕРЕНО вживую, работает.** Point == CGPoint
  (оба top-left), клик попадает точно под курсор. Координаты корректны.
- **Сохранение позиции панели — ГОТОВО и проверено.** Перетащил за ON/OFF →
  positionX/Y пишутся в settings.json → при перезапуске панель на том же месте.
- Debug-хвосты возвращены: панель у правого края (или в сохранённой позиции),
  мягкий гейт Accessibility (панель показывается всегда + алерт если нет доступа).

### Что дальше (не проверено вживую)
- DRAG (двухфазный) на реальном приложении — выделение текста/перемещение
- MIDDLE клик + Auto-Scroll (адаптер CGScrollWheelEvent ещё не подключён)
- KEYBOARD (I3): запуск клавиатуры почти наверняка не работает (прямой запуск
  KeyboardViewer.app не открывает её с ~Catalina) — чинить
- I2: dwell под нагрузкой (фиксированный dt vs wall-clock)

### Что сделано в UI-слое (App/, всё работает вживую)
- `PanelWindow`: nonactivating NSPanel, statusBar level, immune к desktop-reveal
- `PanelViewController`: кнопки из `panel.items`, hit-test (ZoneMapping),
  скользящая красная плашка (ease-in-out 0.25s), анимация collapse/expand,
  зажим рамки в экран, fade плашки с ON/OFF через 1с, режим перемещения панели
- `PanelButton`: иконки проекта (векторные PDF, template), размеры 48/42/36,
  drag-to-move за ON/OFF (с подавлением dwell-toggle во время drag)
- `CursorPolicy`: единая политика курсора по зоне+intent (из onZone-тика)
- `CursorSampler`, `CGMouseInjector`, `KeyboardLauncher`, `DwellRunner` — адаптеры
- `BackgroundCursor`: private SetsCursorInBackground для курсора в фоне
- `ScreenGeometry`: конвенция top-left координат, флип на границе AppKit

### Что дальше (следующая сессия)
1. **Фаза 4 — окно настроек (Settings UI)**: слайдеры/поля для всех параметров
   (AutoMouse/AutoSelect Delay, sensitivity, scroll intensity, idle-disarm,
   redактор панели panel.items, выбор KEYBOARD-цели, transparency). Пока всё
   правится только через `settings.json`.
2. **KEYBOARD — ОТЛОЖЕНО, кнопка сейчас no-op** (на неё ничего не повешено).
   Toggle встроенной Accessibility Keyboard = ключ `com.apple.universalaccess →
   virtualKeyboardOnOff` (через `defaults` реагирует мгновенно; Assistive Control
   = индикатор включённости фичи). Код в `KeyboardLauncher` готов, но toggle из
   нашего процесса вживую не сработал — разобраться позже (cfprefsd/notification
   из фонового приложения?)
3. **I2** — dwell под нагрузкой (фиксированный dt vs wall-clock)
4. Косметика: смена курсора при перемещении панели (не меняется — см. бэклог)

### Новые параметры Settings (правятся через settings.json, UI — Фаза 4)
- `autoScroll.intensity` (дефолт 0.5) — множитель скорости скролла
- `clicks.idleDisarmSeconds` (дефолт 120) — авто-снятие функции после N сек простоя
- `panel.positionX/Y` — сохранённая позиция панели
4. Косметика: смена курсора при перемещении панели (не меняется, см. бэклог plan.md)

---

## Что сделано

- [x] Создан репозиторий: `git@github.com:umkasanki/ally-clicker.git`
- [x] Написан спек: `docs/spec.md`
- [x] Написан план по фазам с чеклистом: `docs/plan.md`
- [x] Проведён анализ DwellClick (форк-идеи в `docs/DwellClick/pr-ideas.md`)
- [x] Подготовлены reference-файлы PNC: `references/point-n-click/`
  - `config/point-n-click-macos-port-brief.md` — технический бриф macOS-порта
  - `config/DwellEngineSpec.swift` — готовая стейт-машина (pure, без macOS API)
  - `config/PNCSettings.swift` — модель настроек (Codable, реальные значения из реестра)
  - `config/pnc-settings-model.json` — настройки в JSON
  - `icons/pnc-icons/` — 14 SVG иконок (click-left, click-right, click-middle, click-double, drag, keyboard, mod-*, power, repeat, scroll, wheel)
  - `icons/PNCIcons.xcassets/` — Xcode asset catalog (PDF иконки)
- [x] Принято решение: **нативное macOS приложение на Swift/AppKit** (не форк DwellClick, не Python)
- [x] Обновлены docs/spec.md, docs/plan.md, docs/context.md под новое направление

---

## Что делать в следующей сессии

**Шаг 1.1 — Создать Xcode проект:**
- Новый macOS App (AppKit, не SwiftUI) — target macOS 14+
- Bundle ID: `com.allyclicker.app` или аналогичный
- Скопировать `DwellEngineSpec.swift` и `PNCSettings.swift` из references в Sources
- Скопировать `PNCIcons.xcassets` в Assets
- Первый milestone: запросить Accessibility permission через `AXIsProcessTrustedWithOptions`, показать алерт если нет

---

## Ключевые решения и договорённости

- **Язык:** Swift (6.3.2 в WSL для ядра, Xcode на Mac для app)
- **Сборка:** гибрид — `AllyClickerCore` это SPM-пакет (корень репо), приложение это
  `App/AllyClicker.xcodeproj` (создаётся на Mac, подключает пакет локальной зависимостью)
- **Архитектура:** ports-and-adapters. Ядро зависит только от протоколов
  (`MouseInjecting`, `CursorSampling`, `ZoneMapping` в `Ports.swift`), macOS даёт адаптеры
- **Геометрия:** свой тип `Point` (не `CGPoint`) → ядро не зависит от CoreGraphics →
  тестируется на Linux/WSL. App-слой конвертирует `CGPoint ↔ Point` на границе адаптеров
- **UI фреймворк:** AppKit (NSPanel, NSStatusItem)
- **Событийный ввод:** `NSEvent.mouseLocation` (чтение, polling 5мс) + `CGEvent.post` (инъекция)
- **Accessibility permission:** обязательно — без него инъекция не работает
- **Конфиг:** JSON через `Settings.Codable`, в `~/Library/Application Support/AllyClicker/`
- **Где что пишется:** ядро + тесты → WSL (сейчас); адаптеры + UI → Mac (позже)
- **Режим редактирования:** редактировать напрямую (по умолчанию, уточнять в начале таска)

---

## Структура проекта (фактическая)

```
ally-clicker/
├── Package.swift                    # SPM: только AllyClickerCore + тесты (WSL+Mac)
├── Sources/AllyClickerCore/         # ЧИСТОЕ ядро — без AppKit/CoreGraphics
│   ├── Geometry.swift               # Point (вместо CGPoint)
│   ├── DwellEngine.swift            # стейт-машина (Action/Zone/Effect nested)
│   ├── Settings.swift               # модель настроек (Codable)
│   ├── SettingsStore.swift          # JSON персистенс
│   └── Ports.swift                  # протоколы: MouseInjecting/CursorSampling/ZoneMapping
├── Tests/AllyClickerTests/
│   └── DwellEngineTests.swift       # 9 тестов (swift test на WSL)
│
├── App/                             # macOS app (Xcode проект создаётся на Mac)
│   ├── README.md                    # инструкция как создать .xcodeproj
│   └── AllyClicker/
│       ├── main.swift
│       ├── App/AppDelegate.swift    # lifecycle + Accessibility check
│       └── Adapters/
│           └── CGMouseInjector.swift  # MouseInjecting → CGEvent
│           # (далее: CursorSampler, PanelZoneMapper, DwellController, Panel/, Settings/, StatusBar/)
│
├── docs/                            # spec.md, plan.md, context.md, DwellClick/
└── references/point-n-click/        # анализ PNC, иконки, бриф
```

---

## Важные детали реализации (из бриф-документа)

### Панель
- `NSPanel` с `.nonactivatingPanel` — не перехватывает фокус при dwell
- Высокий `window.level` (`.floating` или выше) — поверх всех окон
- Позиция: у правого края экрана, настраиваемая Y-позиция

### DwellEngine (state machine)
Реализация в `Sources/AllyClickerCore/DwellEngine.swift` (pure, тесты на WSL):
- **Pure**: принимает `Point + TimeInterval`, возвращает `[Effect]`
- **armed**: текущая активная функция (nil = ничего)
- **Swipe-reset**: при входе курсора в зону панели → `armed = nil` мгновенно
- **Post-action revert**: 3 пути (defaultLeft → .left / autoCancel → nil / repeat)
- **Re-fire gate**: после клика нужно подвигать к новой цели (`moveRadiusPx`),
  иначе стоящий курсор машинганил бы кликами
- **Two-phase DRAG** с защитой: вход в панель при зажатой кнопке → mouseUp
- **Command-кнопки** (`Zone.panelCommand`): ON/OFF и KEYBOARD — не клики, а one-shot
  команды. Dwell → `Effect.runCommand(.togglePanel | .launchKeyboard)`, срабатывает
  один раз за визит (повторно — после ухода с кнопки). Роутятся в `onCommand`
- **Red = armed action**; dwell countdown НЕ рисуется (см. spec §2)

### Инъекция кликов
- `CGEvent(mouseEventSource:mouseType:mouseCursorPosition:mouseButton:)`
- `.post(tap: .cgSessionEventTap)`
- Double click: `.mouseEventClickState = 2`
- Drag: down → move events → up
- Middle click: `.otherMouseDown/.otherMouseUp`, button `.center`
- **Требует Accessibility permission** (`AXIsProcessTrustedWithOptions`)

### Настройки (из реального реестра PNC)
| Параметр | Значение | Описание |
|---|---|---|
| dwellTimeMs | 320 | Задержка выбора кнопки панели → 0.32с |
| dwellTimeMouseMs | 195 | Задержка авто-клика → 0.20с |
| sensitivity | 1 | Радиус допуска дрожания (пиксели) |
| trackerIntervalMs | 5 | Интервал опроса курсора |
| defaultLeft | true | Вернуться к ЛКМ после клика |
| autoCancel | true | Сброс после первого клика |

---

## Ссылки

- Репозиторий: https://github.com/umkasanki/ally-clicker
- Спек: `docs/spec.md`
- План: `docs/plan.md`
- Аналог: https://polital.com/pnc/
- DwellClick (анализ): https://github.com/pilotmoon/DwellClick
- LinearMouse (auto-scroll): https://github.com/linearmouse/linearmouse


---

## Обновление 2026-06-29 — выводы из переписки с автором PNC

Получены и подтверждены ответы Anne York (автор PNC) на 8 вопросов. Полностью внесены в
`docs/spec.md` → раздел «Дополнение по переписке с автором PNC (подтверждено 2026-06-29)».

Ключевое:
- **Dwell над экраном в PNC вычисляется, а не задаётся:**
  `DwellTimeMouse = Int(DwellMultiplier * Sensitivity_Twips / AverageVelocity)`,
  где `AverageVelocity` — из обязательного калибровочного теста.
  → **РЕШЕНО:** формула реализована в ядре (`Settings.Calibration.computedDwellMs`,
  `Settings.effectiveDwellMouseSeconds`), ручной `dwellTimeMouseMs = 195` остаётся
  fallback. Калибровка выключена по умолчанию (`enabled = false`). Осталось на Mac:
  baseline-тест для замера `averageVelocity` и подбор `multiplier` под точки macOS.
- `BaselineFlags` = флаг «калибровка пройдена»; `SensitivityV2` = допуск-радиус (= наш `dwell_radius`).
- **AutoCancel OFF** в PNC: без swipe-отмены (нужен Cancel/другая кнопка). У нас swipe-reset
  оставляем всегда — осознанное улучшение, а не баг.
- `RAMB` = Remote Access Mouse Button (якорь поверх fullscreen) — кандидат в Фазу 5.
- `Left2`/`Middle2` = двойной клик; `RightLeft` = right-затем-left; `UseTimer*` = break-таймер.

⚠️ Reference-бриф `references/point-n-click/config/point-n-click-macos-port-brief.md` создан
до ответов и частично устарел — актуальные выводы см. в `docs/spec.md`.
