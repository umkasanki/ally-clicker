# AllyClicker для Windows — план реализации

> Решение принято 2026-07-26. Продолжаем со следующей сессии.

## ✅ Спайк Swift-on-Windows (2026-07-27) — результат
Проверяли: собирается ли чистое ядро официальным Swift-тулчейном на Windows.
**Да — ядро полностью работает на Windows.** `AllyClickerCore` собирается и **все 72 теста
проходят** на Swift **6.1.2 и 6.2** (включая `SettingsStoreTests` — то есть файловая
персистенция настроек тоже работает). Workflow: `.github/workflows/spike-swift-windows.yml`.

Грабли, которые пришлось обойти (важно помнить):
1. **Нелегальные пути в репо.** `*:Zone.Identifier` (артефакты Windows-загрузок) ломали сам
   `git checkout` на Windows — заблокировало бы ЛЮБУЮ Windows-работу, и C# тоже. Удалены,
   добавлены в `.gitignore`.
2. **`could not build module 'ucrt'`** на Swift 6.0.3 — рассинхрон тулчейна с Windows SDK.
   Лечится входом в окружение Visual Studio перед сборкой: `compnerd/gha-setup-vsdevenv`.
3. Формат версии для `compnerd/gha-setup-swift`: работает `branch: swift-X.Y.Z-release` +
   `tag: X.Y.Z-RELEASE` (новые `swift-version`-инпуты давали 404).

**Что спайк НЕ проверял (остаточный риск):** GUI и COM-интероп. На Windows нет
AppKit/SwiftUI — панель, оверлей и окно настроек пришлось бы писать голым Win32 через
`import WinSDK` (многословно; у нас анимации, тёмная тема, DPI, 4 вкладки настроек), а
UI Automation — это COM, из Swift интероп болезненный. `SendInput`/`GetCursorPos` из Swift,
наоборот, простые (обычные C-вызовы).

**Как это меняет решение:** переиспользование ядра на Windows теперь **бесплатно и
доказано**. Вопрос свёлся к UI-слою:
- **C# (рекомендация)** — порт движка ~вечер, но весь UI (2 окна, анимации, DPI) дешёвый.
- **Гибрид** — ядро Swift → нативная DLL с C-ABI (`@_cdecl`) + C#/WPF поверх. Один источник
  истины для движка, зрелый UI; цена — кросс-языковой ABI/маршалинг + двойной тулчейн в CI.
- **Full Swift** — максимум переиспользования, но весь UI руками на Win32 + COM для UIA.

Итог: основной объём работы — **UI, а не движок**, поэтому выигрыш от переиспользования
ядра меньше, чем цена ручного Win32-UI. Решение по варианту — за пользователем.

## Язык и стек
**C# / .NET** (WPF для панели; WinUI 3 — опционально позже). Причины: первый-партийный
стек Windows, стабильный тайминг dwell-петли (без GC/GIL-джиттера как в Python),
тривиальный P/Invoke к `SendInput`/`GetCursorPos`/UI Automation, взрослая упаковка и
подпись (MSIX/self-contained + Authenticode). Ядро `DwellEngine` крошечное — портируется
на C# 1:1, тесты переносятся в xUnit.

Python — только как быстрый прототип, не как продакшн. Swift-on-Windows — сырой GUI-тулинг.

## Главное требование: НЕ зависать вместе с чужим софтом
Болячка PNC: при зависании целевого приложения (Viber) зависал и сам PNC. Причина на
Windows — синхронные вызовы в зависшее окно: `SendMessage`, `AttachThreadInput`,
синхронные хуки, синхронные UIA/MSAA-вызовы. Это НЕЛЬЗЯ.

**Правила архитектуры (заложить с самого начала):**
1. Инъекция — только через **`SendInput`** (async, fire-and-forget; НЕ ждёт целевое
   приложение). Двухфазный драг стримит `MOUSEEVENTF_MOVE` между down и up.
2. Курсор — **`GetCursorPos`** (системный вызов, не зависит от чужих окон).
3. Свой процесс + свой UI-поток; dwell-петля на отдельном высокоприоритетном потоке.
   UI-поток только рисует. Windows изолирует процессы → зависший софт нас не морозит.
4. Единственный синхронный запрос к чужому окну (UI Automation «ссылка под курсором?»
   для MIDDLE) — **на отдельном потоке с жёстким таймаутом ~100 мс**
   (`Task.WhenAny(uia, Task.Delay(100))`); не ответило — бросаем, fallback на auto-scroll.
5. Запрещено: `AttachThreadInput`, синхронные `SendMessage`, journal-хуки.

Золотое правило: **UI/dwell-поток НИКОГДА не блокируется на чужом приложении.**
(На macOS это уже доказано: async `CGEvent.post` + `AXUIElementSetMessagingTimeout(0.1)`.)

## Структура репо: полный reorg в монорепо
Решено делать симметрично, пока Windows-кода ещё нет (самый дешёвый момент).
Общего кода Swift↔C# нет — общий контракт это `docs/spec.md`.

Целевая структура:
```
ally-clicker/
├── macos/                    # git mv: App/ Sources/ Tests/ tools/ Package.swift
├── windows/                  # новый C#/.NET solution
│   ├── AllyClicker.Core/         # движок (DwellEngine, AutoScroll, Settings, Point) — без Win32
│   ├── AllyClicker.App/          # WPF-панель + адаптеры (SendInput, GetCursorPos, UIA)
│   └── AllyClicker.Core.Tests/   # xUnit — порт тестов
├── docs/                     # общая спека/план/контекст (в корне)
├── packaging/                # homebrew cask (в корне)
└── .github/workflows/        # правим пути macOS + добавляем windows-ci.yml
```
Без **долгоживущих платформенных** веток. Но саму разработку Windows-версии ведём в
**feature-ветке `feature/windows-app`** и мёржим в `main` по готовности (или по частям —
W0/W1 могут влиться раньше). Это держит `main` всегда релизным для macOS: пока Windows
сырая, её код не мешает выпускать macOS-релизы тегами из `main`.

### Шаги reorg (первым делом, ДО Windows-кода)
1. `git mv App Sources Tests tools Package.swift macos/` (история сохраняется).
2. Поправить `macos/App/build-app.sh` / `install.sh` / `make-dmg.sh` (используют
   `dirname/..` → станут указывать на `macos/`; проверить каждую ссылку на `App/`, `Sources`, `build/`).
3. Поправить `.github/workflows/ci.yml` (`cd macos` перед `swift build/test`) и
   `release.yml` (пути `macos/App/Info.plist`, `./macos/App/make-dmg.sh`, `macos/build/...`).
4. **Проверить на Маке**, что `build-app.sh` собирает+подписывает как прежде — до Windows.
5. Обновить `docs/context.md` и root `README` под монорепо.
Только после зелёной macOS-сборки — начинать `windows/`.

## Среда разработки и цикл проверки (выяснено 2026-07-27)

Проверено фактически:
- **В WSL (Linux) .NET SDK нет** (`command -v dotnet` → пусто).
- **На Windows-хосте** (`/mnt/c/Program Files/dotnet/`) есть только **рантаймы**
  (`Microsoft.NETCore.App`, `Microsoft.WindowsDesktop.App` — т.е. WPF запускать есть чем),
  но **папки `sdk/` нет** → собирать нечем. `dotnet.exe --version` не работает.
- Путь репо со стороны Windows: `\\wsl.localhost\Ubuntu\home\oleg\projects\ally-clicker`
  (UNC — MSBuild такие пути переносит плохо, поэтому для Windows-сборок нужна рабочая
  копия на диске `C:` либо сборка через CI).

**Решение (трёхуровневый цикл):**
1. **Ядро + тесты (W1, W2-логика) — .NET SDK для Linux в WSL.** `AllyClicker.Core` и
   `AllyClicker.Core.Tests` кросс-платформенные (`net8.0`, без Win32) → мгновенный локальный
   цикл `dotnet build && dotnet test` прямо в WSL. Это 80% работы по движку.
2. **WPF-приложение (W3+) — .NET SDK на Windows-хосте.** Понадобится, когда дойдём до
   панели/окна настроек и локальных запусков. Ставится один раз (winget/инсталлятор).
   Рабочую копию репо держать на `C:\` (например `C:\dev\ally-clicker`) во избежание UNC.
3. **Windows CI (`windows-ci.yml`) — источник истины.** Собирает и `Core`, и `App` на
   `windows-latest`. Медленнее (~1–2 мин), зато не зависит от локальных установок —
   как и было со спайком Swift.

⚠️ Установка SDK — изменение системы, спросить пользователя перед первой установкой.

## Фазы Windows-реализации
### W0 — Каркас (не требует Windows-машины)
Создать:
```
windows/AllyClicker.sln
windows/AllyClicker.Core/AllyClicker.Core.csproj            (net8.0, без Win32)
windows/AllyClicker.Core.Tests/AllyClicker.Core.Tests.csproj (net8.0, xUnit)
windows/AllyClicker.App/AllyClicker.App.csproj              (net8.0-windows, WPF, UseWPF)
.github/workflows/windows-ci.yml                            (windows-latest: build sln + test)
```
Плюс: раздел «Freeze-immunity» в `docs/spec.md` (правила из этого файла — контракт для обеих
платформ), упоминание Windows в root README.
**Готово, когда:** `windows-ci.yml` зелёный (пустые проекты собираются, тесты запускаются).

### W1 — Порт ядра (без UI, не требует Windows-машины)
Порт 1:1 из `macos/Sources/AllyClickerCore/` (1147 строк, 9 файлов). Соответствие:

| Swift | C# | Заметки |
|---|---|---|
| `Geometry.swift` | `Point.cs` | `readonly record struct Point(double X, double Y)` + `DistanceTo` |
| `Ports.swift` | `Ports.cs` | интерфейсы `IMouseInjector`, `ICursorSampler`, `IZoneMapping` |
| `PanelItem.swift` | `PanelItem.cs` | union action/command; **стабильные строковые id** сохранить как в Swift |
| `Settings.swift` (416) | `Settings.cs` | вложенные `Timing/Stillness/Clicks/AutoScroll/Appearance/Panel/Commands/Calibration`; **устойчивый декод** — отсутствующие поля берут дефолт (в C#: `JsonSerializer` + инициализаторы свойств); те же клампы (`intensity` 0.05–5, `audioVolume` 0–1, `iconScale` 0.5–2) |
| `DwellEngine.swift` (353) | `DwellEngine.cs` | state-machine: `Action/Command/Zone/Effect`; swipe-debounce 15 мс, re-fire gate, двухфазный drag, idle-disarm (дефолт 0) |
| `AutoScrollEngine.swift` | `AutoScrollEngine.cs` | формула: `raw = (base + sqrt(adj)*boost) * intensity`, кламп maxSpeed **последним** |
| `AutoScrollController.swift` | `AutoScrollController.cs` | |
| `DwellController.swift` (129) | `DwellController.cs` | колбэки → C# events/делегаты: `OnUIEffect`, `OnCommand`, `OnZone`, `WillFire`, `OnFired`; `ArmDefaultIfEnabled()` |
| `SettingsStore.swift` | `SettingsStore.cs` | путь `%AppData%\AllyClicker\settings.json` |

Тесты: порт `macos/Tests/AllyClickerTests/` (1053 строки, 8 файлов, **75 кейсов**) в xUnit —
`DwellEngineTests`, `SettingsTests`, `SettingsStoreTests`, `PanelCommandTests`,
`DwellControllerTests`, `AutoScrollEngineTests`, `AutoScrollControllerTests`, `CalibrationTests`.
**Готово, когда:** все 75 портированных тестов зелёные (= поведенческий паритет со Swift).
Ядро не ссылается ни на один Win32/WPF API.
- **W2 — Freeze-safe адаптеры:** `SendInput`-инжектор (async), `GetCursorPos`-семплер на
  таймер-потоке, dwell-петля на своём потоке. + харнесс с «зависшим окном»-заглушкой.
- **W3 — Панель:** WPF borderless topmost click-through overlay, DPI-aware; кнопки, плашка,
  сворачивание, перетаскивание, тёмная тема — по спеке.
- **W4 — Умный MIDDLE:** UIA «ссылка под курсором» на отдельном потоке с таймаутом 100 мс,
  иначе auto-scroll (`SendInput` wheel).
- **W5 — Настройки:** WPF-окно, авто-сохранение в `%AppData%\AllyClicker\settings.json`
  (та же схема, что на маке), live-apply.
- **W6 — Feedback + автозапуск + трей:** звук, визуальная рябь, автозапуск (реестр `Run` /
  папка Startup), иконка в трее.
- **W7 — Упаковка/подпись:** self-contained single-file `.exe` (или MSIX) + Authenticode,
  инсталлятор (Inno Setup), release-workflow.
- **W8 — Проверка на устройстве** с head-tracker.

## Definition of done по остальным фазам
- **W2:** харнесс с «зависшим окном» доказывает, что dwell-петля и инъекция не встают;
  ни одного синхронного вызова в чужой процесс из UI/dwell-потока.
- **W3:** панель по спеке (кнопки, плашка, сворачивание, перетаскивание, тёмная тема),
  click-through, DPI-aware, не воруёт фокус.
- **W4:** над ссылкой — средний клик (новая вкладка), иначе auto-scroll; UIA-запрос
  укладывается в 100 мс или отбрасывается.
- **W5:** окно настроек с авто-сохранением; схема `settings.json` совместима со спекой.
- **W6:** звук + визуальная рябь + автозапуск + иконка в трее.
- **W7:** подписанный `.exe`/MSIX + инсталлятор + release-workflow по тегу.
- **W8:** проверено вживую с head-tracker.

## Как возобновить работу в новой сессии
1. `git checkout feature/windows-app` (вся Windows-работа идёт здесь; `main` остаётся
   релизным для macOS).
2. Прочитать этот файл + `docs/context.md` (там текущий статус) + `docs/spec.md`
   (поведенческий контракт, общий для платформ).
3. Свериться, какая фаза открыта: `windows/` пуст → W0; проекты есть, тестов нет → W1; и т.д.
4. Цикл проверки — см. «Среда разработки»: ядро в WSL (`dotnet test`), Windows-часть через
   `windows-ci.yml` или локальный SDK на хосте.
5. Эталон поведения — Swift-реализация в `macos/Sources/AllyClickerCore/` и её 75 тестов.
   При расхождении прав Swift-вариант (он проверен вживую пользователем).
