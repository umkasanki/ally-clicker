# AllyClicker — Контекст сессии

> Этот файл обновляется перед каждым коммитом.
> При старте новой сессии — прочитай этот файл первым.

---

## Статус проекта

**Текущая фаза:** Фаза 1 завершена (ядро). Дальше — Фаза 2 (macOS UI, нужен Mac)
**Текущий шаг:** Ядро полностью реализовано и покрыто тестами на WSL
**Последнее действие:** Реализованы DwellEngine (клики + two-phase drag), DwellController, AutoScrollEngine, SettingsStore. 26 юнит-тестов проходят на WSL (Swift 6.3.2)

### Что НЕЛЬЗЯ делать на WSL (нужен Mac)
- Создать `App/AllyClicker.xcodeproj` (инструкция в `App/README.md`)
- Адаптеры: `CursorSampler` (NSEvent), `PanelZoneMapper` (hit-test панели)
- UI: NSPanel + кнопки, статус-бар, окно настроек
- Auto-scroll адаптер (CGScrollWheelEvent), drag-роутинг проверить вживую
- Сборка, Accessibility-проверка в реальной среде

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
  где `AverageVelocity` — из обязательного калибровочного теста. У нас сейчас
  `dwellTimeMouseMs = 195` — это ручной **fallback**; добавлять ли калибровку —
  открытое проектное решение (детали в spec).
- `BaselineFlags` = флаг «калибровка пройдена»; `SensitivityV2` = допуск-радиус (= наш `dwell_radius`).
- **AutoCancel OFF** в PNC: без swipe-отмены (нужен Cancel/другая кнопка). У нас swipe-reset
  оставляем всегда — осознанное улучшение, а не баг.
- `RAMB` = Remote Access Mouse Button (якорь поверх fullscreen) — кандидат в Фазу 5.
- `Left2`/`Middle2` = двойной клик; `RightLeft` = right-затем-left; `UseTimer*` = break-таймер.

⚠️ Reference-бриф `references/point-n-click/config/point-n-click-macos-port-brief.md` создан
до ответов и частично устарел — актуальные выводы см. в `docs/spec.md`.
