# AllyClicker — Контекст сессии

> Этот файл обновляется перед каждым коммитом.
> При старте новой сессии — прочитай этот файл первым.

---

## Статус проекта

**Текущая фаза:** macOS-версия в рабочем состоянии, релиз **v0.1.6** (Homebrew tap + .dmg).
Репо реструктурирован в монорепо (`macos/` + `windows/`).
**Последнее действие:** в ветке `feature/windows-app` закрыт W0 (каркас + CI) и
идёт W1 — портированы представление (`Point`/`ClickAction`/`Zone`/`Effect`/`PanelItem`/
`Ports`) и `Settings` с golden-харнессом. **66 тестов зелёные.** Дальше — `DwellEngine`.
План и все решения — в `docs/windows-plan.md`.

### 🪟 W1 — идёт (2026-08-01). Сделано: представление + Settings
Локальный цикл: `dotnet test windows/AllyClicker.Core.slnf` (Мак не нужен).
Эталон запускается здесь же: `docker run --rm -v "$PWD/macos":/pkg -w /pkg swift:6.0 swift test`
→ 75 тестов. Образ `swift:6.0` закэширован локально.

**Форма зафиксирована — закрытые иерархии `record`-ов** для `Zone`/`Effect`/`PanelItem`
(приватный конструктор базы = исчерпывающий `switch`, как у Swift-энума). Решающий
аргумент — равенство по значению: портируемые тесты сравнивают целые списки эффектов.
Переименования: `Action`→`ClickAction` (конфликт с `System.Action`), `Command`→`PanelCommand`,
`Panel`→`PanelSettings` (конфликт с `Zone.Panel`), `ZoneMapping`→`IZoneMapper`.

**Главная методика — дифференциальная сверка, а не ручной перенос ассертов.**
`macos/Sources/SettingsGolden` (dev-цель, в приложение не входит) печатает, как эталон
декодирует 28 документов; вывод закоммичен фикстурой, C#-тесты сверяются структурно.
Перегенерация:
```
docker run --rm -v "$PWD/macos":/pkg -w /pkg swift:6.0 swift run SettingsGolden \
  > windows/AllyClicker.Core.Tests/Fixtures/settings-golden.json
```
Проверено мутациями, что набор умеет краснеть. Для `DwellEngine` тот же подход
масштабируется лучше всего: снять со Swift трассу эффектов на скриптованной
последовательности тиков и сверять покадрово.

**Две ловушки, стоившие правок (обе задокументированы в плане):**
1. Swift трактует явный `null` как отсутствующий ключ, `System.Text.Json` — бросает
   исключение. Файл с одним `null` уронил бы приложение на старте. Отсюда рукописный
   декодер `Json.cs` с семантикой `decodeIfPresent`.
2. `IReadOnlyList` **не** делает данные неизменяемыми — только прячет мутирующие методы.
   `DefaultItems` приводился обратно к массиву и был доступен на запись (статический,
   общий на процесс). Иммутабельность обеспечивает владение хранилищем: `Array.AsReadOnly`
   + копия во входе `Items` + обёртка на выходе `Normalize`.

⚠️ Не покрыто фикстурой: поведение при **неверном типе** значения (`"width": "abc"`) —
Swift бросает `typeMismatch`, порт повторяет по прочтению исходника, но не прибито.

**➡️ Начать следующую сессию с:** `docs/windows-plan.md` → «Как возобновить работу»
(там состояние, первые команды, план по `DwellEngine` и один открытый вопрос).

### 🪟 W0 — каркас Windows ЗАКРЫТ (2026-08-01, ветка `feature/windows-app`)
**CI зелёный** (run 30693414883): `AllyClicker.App` собирается на `windows-latest`,
тесты 4/4 и на Windows, и на Linux. Критерий готовности W0 выполнен.
Создано: `windows/AllyClicker.sln` (Core / Core.Tests / App), `Directory.Build.props`,
`AllyClicker.Core.slnf`, `app.manifest` с `PerMonitorV2`, `.github/workflows/windows-ci.yml`
(две джобы: полный solution на `windows-latest` + core-only на `ubuntu-latest`).
Засеян `Point.cs` + 4 теста — первая строка таблицы порта, чтобы зелёный CI был осмысленным.
Проверено по исходнику: `Point` в Swift-ядре нигде не мутируется → `readonly record struct`
в C# безопасен.

**По итогам ревью W0 — новое обязательное требование (`docs/spec.md` §3.6):**
на Windows UIPI **молча** глотает `SendInput`, когда в фокусе окно, запущенное от
администратора (MSDN: ошибка не видна ни в return value, ни в `GetLastError`). Лечится
только `uiAccess="true"`, а тот требует подписи Authenticode **и** установки в `Program
Files`. Портабельный single-file `.exe` как формат раздачи отменяется. В манифесте пока
`uiAccess="false"` с комментарием — иначе не запустить ни локально, ни в CI.

**Проверка `uiAccess` перенесена из W7 в W2b** (решение 2026-08-01): от исхода зависят
бюджет, сроки и способ раздачи, узнавать это на упаковке поздно. Ключевой вопрос спайка —
**пройдёт ли самоподписанный сертификат** (схема-близнец macOS: свой корень в «Доверенные
корневые центры сертификации» + установка в `Program Files`). Если да — покупка нужна только
для публичной раздачи, основной сценарий закрыт бесплатно. Если нет — закупка стартует сразу,
у неё свой срок: **Certum Open Source** — облачный ~€60 / аппаратный ~€120 первый год,
~€30 далее, выдаётся физлицам, требует открытого проекта (им подписан OptiKey — ассистивный
проект той же ниши); либо **Azure Artifact Signing** $9.99/мес, но ограничен списком стран.
Цены у источников расходятся, уточнять перед покупкой; отдельно проверить выполнимость
оплаты и доставки. NB: с июня 2023 приватный ключ обязан лежать на сертифицированной
железке или в облачном HSM; с 1 марта 2026 максимальный срок сертификата 460 дней —
продление примерно ежегодное при любом варианте.

⚠️ **Январь 2026 добавил второй вопрос** (`docs/spec.md` §3.6): обновление от 13.01.2026
ограничило ввод в диалоги аутентификации тремя источниками, среди которых **доверенные
ассистивные приложения с uiAccess** — наш путь подтверждён как легитимный, но критерий
«доверенности» Microsoft не раскрывает. Поэтому спайк проверяет эти случаи раздельно:
обычные окна администратора и диалоги UAC/аутентификации. Ответы могут не совпасть.

✅ **Нашлась бесплатная альтернатива — срочность закупки снята.** Вместо `uiAccess` можно
поднять сам процесс до прав администратора: тогда UIPI не мешает, сертификат не нужен.
Запрос UAC при старте обходится **заданием в Планировщике** («наивысшие права» + триггер
«при входе в систему») — служба стартует нас в уже разрешённом контексте. Третий разрешённый
источник ввода по январскому правилу — как раз «приложения с правами администратора», так что
и диалоги аутентификации закрываются. Цена: полные права вместо узкой привилегии, то есть
хуже по безопасности. W2b проверяет **обе ветки**, лестница вариантов — в `windows-plan.md`.
NB: ползунок «Никогда не уведомлять» — это НЕ отключённый UAC, UIPI при нём работает.

**Среда (выяснено фактически 2026-08-01):**
- В WSL поставлен **`dotnet-sdk-8.0` из apt** (8.0.129). Restore к nuget.org работает,
  `dotnet test` проходит. Локальный цикл ядра: `dotnet test windows/AllyClicker.Core.slnf`.
- ⚠️ **Ubuntu-сборка SDK не содержит `Microsoft.NET.Sdk.WindowsDesktop`** (source-build
  вырезает Windows-компоненты). WPF-проект на WSL нельзя даже *прочитать* — `dotnet sln add`
  на нём падает, `EnableWindowsTargeting` не спасает. Отсюда `.slnf` для локальной работы и
  правило: **всё, что трогает `AllyClicker.App`, проверяется только в CI.** Если понадобится
  локальная сборка App — ставить SDK от Microsoft (`dotnet-install.sh`), не из apt.
- Swift в WSL сейчас **не установлен**; ядро macOS гоняется через docker
  (`docker run --rm -v "$PWD/macos":/pkg -w /pkg swift:6.0 swift test`).

### ✅ Закрыто (сессия 2026-07-14)
- **Звук на старте драга** (`c8eb48d`) — собрано, установлено, подтверждено на слух.
- **Стабильная подпись релизов** — секреты `SIGNING_P12_BASE64` / `SIGNING_P12_PASSWORD`
  залиты (экспорт `.p12` из `AllyClicker Self-Signed` сделан в GUI-Терминале Мака).
  Релиз **v0.1.3** выпущен; проверено: `.dmg` подписан `Authority=AllyClicker Self-Signed`
  (= локальным install.sh). Грант Универсального доступа теперь держится у всех сборок.
- Экспорт private key возможен только из GUI-сессии Мака (по SSH —
  «User interaction is not allowed»); keychain-пароль связки = `allyclicker`.

### ✅ Релиз v0.1.6 (2026-07-27) — модель «активной команды» доведена
Проверено вживую на Маке (включая сборку из новой структуры `macos/`):
- **Активная функция больше не слетает сама:** idle-disarm выключен по умолчанию
  (`idleDisarmSeconds = 0`). Пользователь: «автоматическое снятие левого клика больше
  добавляет проблем, чем решает». Настройка осталась, но по умолчанию off.
- **Left возвращается после ВСЕХ функций,** включая режимы-захваты: после выхода из
  авто-скролла и после перемещения панели (`DwellController.armDefaultIfEnabled()`).
  Раньше там не оставалось активной функции вообще — это был реальный пробел.
- **Дребезг кромки панели** больше не отменяет функцию: swipe-reset дебаунсится
  (`DwellEngine.swipeDebounce = 15 мс`); настоящий мазок отменяет мгновенно.
- 75 тестов зелёные. ⚠️ При апгрейде со старых версий в `settings.json` остаётся
  `idleDisarmSeconds: 120` — лечится Reset to defaults или вручную (у Олега уже 0).

### 🔀 Reorg в монорепо — СДЕЛАН (2026-07-27)
`App/ Sources/ Tests/ tools/ Package.swift` → **`macos/`** (через `git mv`, история цела).
Скрипты (`build-app.sh`/`install.sh`/`make-dmg.sh`) работали и так — они делают
`cd $(dirname $0)/..`, что теперь = `macos/`; обновлены только usage-комментарии.
Пути поправлены в `ci.yml` (`working-directory: macos`), `release.yml`
(`macos/App/Info.plist`, `./macos/App/make-dmg.sh`, `macos/build/*.dmg`), README.
**Проверено:** Linux CI зелёный (72 теста) с новой структурой.
**Проверено на Маке (2026-07-27):** `./macos/App/install.sh` собирает, подписывает
(стабильная identity) и ставит в `/Applications` из новой структуры; артефакты — в
`macos/build/`. release.yml тоже отработал (релиз v0.1.6). Старые `App/`+`build/` в корне
Мака удалены как остатки прежней структуры.
Мелочь закрыта: папка с опечаткой `counds/` → **`sounds/`** (в ней `tone1.WAV`, пока не используется).

### 🪟 Следующая большая веха: Windows-версия (план в docs/windows-plan.md)
**Решено: C#/.NET** (после спайка — см. ниже). Следующий шаг: W0 (каркас `windows/`) → W1 (порт движка + xUnit).
Решено (2026-07-26): **C#/.NET (WPF)**, монорепо с **полным reorg** (`macos/` + `windows/`),
спека — общий контракт. Главное требование — не зависать вместе с чужим софтом
(SendInput async + UIA с таймаутом). **Завтра начинаем с reorg репо**, затем W0→W8.
Подробности и шаги reorg — в `docs/windows-plan.md`.

### ⏳ Осталось (macOS)
- **Первый грант Универсального доступа** — выдать один раз вручную (тумблер;
  до гранта приложение не кликает — замкнутый круг; мышь/помощник/встроенный Dwell).
  После этого, благодаря стабильной подписи, грант больше не слетит.

### 🎯 Точка остановки (перерыв после релиза v0.1.1)

**Раздача настроена и работает:**
- Публичный репозиторий, релизы через тег `v*` → GitHub Actions (`release.yml`)
  собирает `.dmg`, публикует Release, обновляет cask в `umkasanki/homebrew-tap`
  (нужен секрет `TAP_TOKEN` — добавлен). Установка:
  `brew tap umkasanki/tap && brew trust umkasanki/tap && brew install --cask allyclicker`
  (+ `xattr -dr com.apple.quarantine …`, т.к. self-signed без нотаризации).
- Текущий релиз: **v0.1.6**. `macos/App/make-dmg.sh` — ручная сборка dmg.
- Codesign по SSH: чинится через `security set-key-partition-list … -k allyclicker`
  (ключ требовал интерактивного подтверждения → «errSecInternalComponent»).

**Правки размеров/единиц (v0.1.1):** ширина панели в **pt**, дефолт **50**, шаг **1**,
минимум **30**; размеры иконок кнопок и радиус скругления (**10% width**) —
пропорциональны ширине.

**Соседний проект `ally-keyboard`:** добавлена иконка (красная клавиатура, house-style)
+ `tools/`. Скилл `macos-app-icon` дополнен вариантом Xcode asset-catalog.

Сделано ранее в сессии (всё в git):
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
- Стабильная подпись (грант не слетает). NB: авто-снятие функции по простою с v0.1.6
  ВЫКЛЮЧЕНО по умолчанию (активная функция держится, пока её не смахнут)

### Исправления по ревью сессии (все закрыты)
- Runaway scroll: intensity зажат в [0.05, 5.0] + clamp maxSpeed ПОСЛЕ множителя
- «Мёртвый» dwell после скролла: advance() прерывает эффекты тика при willFire-перехвате
- AX без таймаута → `AXUIElementSetMessagingTimeout(0.1)` (зависшее приложение не морозит)
- Идемпотентность таймеров (`guard timer == nil`) в Runner/AutoScroller/beginMove

### Доступ к Mac
- SSH: `ssh mishkin@100.126.136.17`, проект в `~/projects/ally-clicker`
- macOS 26.3.1 (arm64), Xcode 26.6 установлен, лицензия принята
- Все 72 теста проходят на Mac (`swift test`) и на Linux-CI
- Сборка без Xcode-проекта: `./macos/App/build-app.sh` → `macos/build/AllyClicker.app`
  (swift build + swiftc против AppKit + codesign стабильной identity)
- Цикл итерации: правка на WSL → commit/push → `ssh … git reset --hard origin/main && ./macos/App/install.sh`
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
