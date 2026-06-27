# AllyClicker — Контекст сессии

> Этот файл обновляется перед каждым коммитом.
> При старте новой сессии — прочитай этот файл первым.

---

## Статус проекта

**Текущая фаза:** Фаза 0 — Документация и архитектура
**Текущий шаг:** 0.3 — Обновление спека и плана под macOS/Swift
**Последнее действие:** Прочитаны reference-файлы из `references/point-n-click/`, обновлена документация

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

- **Язык:** Swift
- **UI фреймворк:** AppKit (NSPanel для панели, SwiftUI можно для Settings window)
- **Событийный ввод:** CGEventTap (чтение позиции) + CGEvent.post (инъекция кликов)
- **Accessibility permission:** обязательно — без него инъекция не работает
- **Конфиг:** JSON через `PNCSettings.Codable`, хранится в `~/Library/Application Support/AllyClicker/`
- **Архитектура:** DwellEngine pure (без macOS API) → тестируемый unit-тестами
- **Режим редактирования:** редактировать напрямую (по умолчанию, уточнять в начале таска)

---

## Структура проекта (целевая)

```
ally-clicker/
├── AllyClicker.xcodeproj/
├── AllyClicker/
│   ├── App/
│   │   └── AppDelegate.swift       # NSApplicationDelegate, точка входа
│   ├── Engine/
│   │   ├── DwellEngine.swift       # Pure state machine (из references)
│   │   └── PNCSettings.swift       # Settings model (из references)
│   ├── Input/
│   │   └── InputController.swift   # CGEvent injection (click, drag, scroll)
│   ├── Panel/
│   │   ├── PanelWindow.swift       # NSPanel (nonactivating, always-on-top)
│   │   ├── PanelViewController.swift
│   │   └── PanelButton.swift       # Кнопка с dwell-анимацией
│   ├── Settings/
│   │   ├── SettingsWindow.swift    # NSWindow для Configure
│   │   └── SettingsStore.swift     # Чтение/запись JSON
│   ├── Resources/
│   │   └── Assets.xcassets/        # Иконки (из PNCIcons.xcassets)
│   └── Tests/
│       ├── DwellEngineTests.swift
│       └── PNCSettingsTests.swift
├── docs/
│   ├── spec.md
│   ├── plan.md
│   ├── context.md
│   └── DwellClick/
│       └── pr-ideas.md
└── references/
    └── point-n-click/
        ├── config/
        └── icons/
```

---

## Важные детали реализации (из бриф-документа)

### Панель
- `NSPanel` с `.nonactivatingPanel` — не перехватывает фокус при dwell
- Высокий `window.level` (`.floating` или выше) — поверх всех окон
- Позиция: у правого края экрана, настраиваемая Y-позиция

### DwellEngine (state machine)
Готовая реализация в `references/point-n-click/config/DwellEngineSpec.swift`:
- **Pure**: принимает `CGPoint + TimeInterval`, возвращает `[DwellEffect]`
- **armedAction**: текущая активная функция (nil = ничего)
- **Swipe-reset**: при входе курсора в зону панели → `armed = nil` мгновенно
- **Post-click revert**: после выполнения → вернуться к `.left` (если `defaultLeft = true`)
- **Yellow = dwell progress**, **Red = armed action**

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
| dwellTimeExitMs | 210 | Задержка кнопки Exit → 0.21с |
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
