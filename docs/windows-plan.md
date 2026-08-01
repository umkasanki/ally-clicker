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
### W0 — Каркас ✅ СДЕЛАНО (2026-08-01)
Создано (плюс к списку ниже): `windows/Directory.Build.props` (общие свойства),
`windows/AllyClicker.Core.slnf` (подмножество, собираемое на Linux),
`windows/AllyClicker.App/app.manifest` с `PerMonitorV2` (риск №1 закрыт на уровне каркаса),
`App.xaml`/`App.xaml.cs` без `StartupUri` (у приложения панель, а не главное окно).
`windows-ci.yml` — две джобы: полный solution на `windows-latest` + core-only на
`ubuntu-latest` (страхует локальный WSL-цикл).
Засеяно из W1: `Point.cs` + `PointTests.cs` (4 теста) — иначе «тесты запускаются»
не проверить, `dotnet test` без единого теста не доказывает ничего.

✅ **Подтверждено прогоном CI** (run 30693414883, 2026-08-01): обе джобы зелёные,
`AllyClicker.App` собирается на `windows-latest`, тесты 4/4 на обеих платформах.
Это и было единственно возможной проверкой WPF-проекта: apt-версия .NET SDK не содержит
`Microsoft.NET.Sdk.WindowsDesktop`, поэтому локально на WSL он непроверяем в принципе.
**Правило на будущее:** любая правка в `AllyClicker.App` верифицируется только через CI.

Изначальный список:
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
### W2 — Freeze-safe адаптеры (ядро анти-зависания; логика тестируется в WSL, проверка — на Windows)
Файлы:
```
windows/AllyClicker.App/Interop/Win32.cs                    P/Invoke: SendInput, GetCursorPos, INPUT/MOUSEINPUT
windows/AllyClicker.App/Adapters/SendInputMouseInjector.cs  IMouseInjector
windows/AllyClicker.App/Adapters/CursorSampler.cs           ICursorSampler (GetCursorPos)
windows/AllyClicker.App/RunLoop/DwellRunner.cs              dwell-петля
```
**Модель потоков (это и есть защита от зависаний, см. spec.md §3.5):**
- **dwell-поток** — выделенный `Thread` (НЕ ThreadPool), `IsBackground = true`, приоритет
  `AboveNormal`; тикает каждые `trackerIntervalMs`, зовёт `DwellController.Advance(dt)`.
  Обращений к чужим окнам не делает вообще.
- **UI-поток (WPF Dispatcher)** — только рисует. Эффекты приходят через
  `Dispatcher.BeginInvoke` (**асинхронно**; синхронный `Dispatcher.Invoke` в dwell-пути
  запрещён — иначе зависший UI застопорит петлю).
- **Инъекция** — `SendInput` прямо из dwell-потока: он не блокируется по определению.

Двухфазный drag: `LEFTDOWN` → поток `MOUSEEVENTF_MOVE | ABSOLUTE` (координаты нормализованы
в 0..65535) → `LEFTUP`. Паритет с фиксом macOS (`leftMouseDragged`) — без потока move-событий
приложения не видят перетаскивания.

**Харнесс проверки:** тестовое окно с кнопкой «зависнуть на 30 с» (`Thread.Sleep` в его
UI-потоке). Пока оно висит: панель отвечает, dwell тикает, клики уходят, приложение можно
закрыть.

#### W2b — спайк `uiAccess` (перенесён сюда из W7, решение 2026-08-01)
Раньше стоял в W7. Перенесён, потому что от исхода зависят **бюджет, сроки и способ
раздачи** — узнавать это на упаковке поздно. Спайк маленький и от остального W2 независим.

Проверить ровно одно: **проходит ли `uiAccess` с самоподписанным сертификатом.**
1. Создать свой корневой сертификат, положить в «Доверенные корневые центры сертификации»
   (LocalMachine) — схема-близнец того, что уже работает на Маке (`AllyClicker Self-Signed`,
   см. `macos/App/setup-signing.sh`).
2. Подписать им сборку, выставить `uiAccess="true"` в `app.manifest`.
3. Положить приложение в `Program Files` (вне защищённого расположения uiAccess не работает;
   на время отладки ограничение снимается политикой «User Account Control: Only elevate
   UIAccess applications that are installed in secure locations»).
4. Запустить окно, открытое **от имени администратора**, и убедиться, что `SendInput`
   до него доходит. Контрольный замер — то же самое без `uiAccess`: клик обязан НЕ дойти,
   причём молча (см. `docs/spec.md` §3.6). Если оба случая ведут себя одинаково — спайк
   поставлен неверно.

**Три исхода и что делать:**
- **Self-signed проходит** → покупка сертификата нужна только для публичной раздачи, а не
  для работоспособности. Основной сценарий («поставить конкретному человеку») закрыт бесплатно.
- **Нужен публично доверенный сертификат** → закупку начинать немедленно, не в W7.
  Кандидат — Certum Open Source (~€70–105 первый год, ~€30 далее, выдаётся физлицам;
  им подписан OptiKey — открытый ассистивный проект той же ниши). Альтернатива —
  Azure Artifact Signing, $9.99/мес, но ограничен списком стран.
- **`uiAccess` недостижим вовсе** → честно задокументировать окна администратора как
  недоступную зону (аналог `loginwindow` на macOS) и предупредить пользователя в About.

**Готово, когда:** харнесс «зависшего окна» пройден; в коде нет
`SendMessage`/`AttachThreadInput`/journal-хуков; синхронный `Dispatcher.Invoke` в dwell-пути
отсутствует; **исход спайка `uiAccess` записан в этот файл** и, если нужна закупка, она
запущена.

### W3 — Панель (нужен .NET SDK на Windows)
Файлы: `PanelWindow.xaml(.cs)`, `PanelButton.cs`, `ArmedPill.cs`, `ScreenGeometry.cs`, `CursorPolicy.cs`.
- Borderless/поверх всех: `WindowStyle=None`, `AllowsTransparency=True`, `Topmost=True`,
  `ShowInTaskbar=False`; **не забирать фокус** — `WS_EX_NOACTIVATE` (аналог `.nonactivatingPanel`).
- Оверлеи (рябь, индикатор якоря) — click-through: `WS_EX_TRANSPARENT | WS_EX_LAYERED`.
- **DPI — главный подводный камень.** Движок мыслит в «точках» (как на macOS), а
  `GetCursorPos` отдаёт физические пиксели. Нужен пересчёт по DPI-фактору монитора, иначе
  `sensitivity`/`moveRadiusPx` будут вести себя иначе, чем на маке. Манифест: `PerMonitorV2`.
- Анимации (скольжение плашки, сворачивание/разворачивание) — WPF `Storyboard`/`DoubleAnimation`.
- Перемещение панели за ON/OFF (в т.ч. hands-free через DRAG) — паритет со macOS.
**Готово, когда:** панель по спеке; не воруёт фокус; корректна при 100/125/150/200 % и на двух
мониторах с разным DPI.

### W4 — Умный MIDDLE + auto-scroll
- `LinkProbe.cs` — «курсор над ссылкой?»: UI Automation `ElementFromPoint`, проверка
  `ControlType.Hyperlink` / доступности `InvokePattern`. **Строго вне UI/dwell-потока и с
  таймаутом 100 мс** (`Task.WhenAny(uia, Task.Delay(100))`); не успело → считаем «не ссылка»
  и уходим в auto-scroll. Это единственное место, где мы вообще спрашиваем чужое приложение.
- `AutoScroller.cs` — 60 fps; дельта из `AutoScrollEngine` (та же формула); скролл через
  `SendInput` + `MOUSEEVENTF_WHEEL` / `HWHEEL`; выход по остановке курсора → левый клик.
  Знак дельты проверить вживую (на macOS пришлось инвертировать).
**Готово, когда:** над ссылкой — новая вкладка; над пустым местом — скролл; зависший браузер
не тормозит панель (проверить харнессом W2).

### W5 — Настройки
- Хранение: `%AppData%\AllyClicker\settings.json`, **те же ключи**, что в Swift-версии
  (общая схема из спеки), устойчивый декод: отсутствующий ключ → дефолт.
- Окно: `TabControl` — Behavior / Panel / Feedback / About (паритет с macOS).
- Авто-сохранение с дебаунсом ~250 мс + live-apply (как на macOS).
**Готово, когда:** все параметры применяются на лету; файл от старой версии читается без потерь.

### W6 — Feedback, автозапуск, трей
- Звук: `System.Media.SoundPlayer` (или NAudio, если понадобится громкость) — переиспользовать
  готовые `Tock.wav`/`Tap.wav` из `macos/App/AllyClicker/Resources/Sounds/`.
- Визуальная рябь: отдельное click-through оверлей-окно + WPF-анимация (паритет `ClickFeedback.swift`).
- Автозапуск: `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` (или папка Startup).
- Трей: `NotifyIcon` (WinForms-interop либо H.NotifyIcon) с меню Settings… / Quit.
**Готово, когда:** фидбэк и автозапуск на паритете с macOS; автозапуск виден в
Диспетчере задач → Автозагрузка.

### W7 — Упаковка и подпись
> ⚠️ Требования ужесточены после ревью W0 (см. `docs/spec.md` §3.6). Подпись и установка
> в `Program Files` — **не полировка, а условие работоспособности**: без них не включить
> `uiAccess`, а без `uiAccess` клики молча не доходят до окон, запущенных от администратора.
> **Разведка перенесена в W2b** — сюда фаза входит с уже известным ответом, каким
> сертификатом подписывать и куплен ли он.

- Переключить `uiAccess` на `true` в `windows/AllyClicker.App/app.manifest`. **Только
  одновременно с пунктами ниже** — неподписанное uiAccess-приложение Windows не запустит.
- Подпись **Authenticode** — **обязательна** (не «иначе SmartScreen поворчит»). Каким
  именно сертификатом — определено исходом спайка W2b: самоподписанный (бесплатно, работает
  только там, где установлен наш корень) либо публично доверенный (нужен для раздачи).
- Инсталлятор в **`Program Files`** (Inno Setup). Портабельный single-file `.exe`,
  запускаемый из произвольной папки, **не подходит** — uiAccess требует защищённого пути.
  `dotnet publish -r win-x64 --self-contained` остаётся, но результат кладёт инсталлятор.
- Иконка `.ico` из `macos/tools/AppIcon.svg` (расширить скилл `macos-app-icon` веткой .ico).
- `windows-release.yml` по тегу `win-v*` (macOS-релизы остаются на `v*`).
**Готово, когда:** инсталлятор ставится на чистой Windows, приложение запускается **с
`uiAccess="true"`**, и клик доходит до окна, запущенного от администратора.

### W8 — Проверка вживую с head-tracker
Чек-лист по образцу `docs/manual-test.md` (адаптировать под Windows).
**Готово, когда:** все пункты пройдены; отдельным пунктом — сценарий «зависший Viber»:
панель продолжает работать, зависшее приложение можно закрыть самому.

## Риски и открытые вопросы
1. **DPI / точки vs пиксели** (W3) — самое вероятное место расхождения поведения с macOS.
   Решить один раз в `ScreenGeometry` и покрыть тестами.
2. **Head-tracker на Windows** — нужен рабочий тракер на той машине для W8 (вероятно тот же,
   где раньше работал PNC).
3. **Сертификат для подписи** — блокирующий для `uiAccess`, а без `uiAccess` UIPI молча
   глотает клики по окнам, запущенным от администратора (`docs/spec.md` §3.6). Это не
   «предупреждение SmartScreen», как казалось до ревью W0, и не аналог отложенной
   нотаризации на macOS — там неподписанное приложение всё же работает, здесь режется
   функциональность. **Снимается спайком W2b:** если пройдёт самоподписанный, покупка нужна
   только для публичной раздачи. Если нет — закупку начинать сразу, у неё свой срок
   (Certum Open Source ~€70–105 первый год / ~€30 далее, физлицам, проект открытый —
   так подписан OptiKey; либо Azure Artifact Signing $9.99/мес, ограничен по странам).
   Отдельный практический фактор — возможность оплаты и доставки в нашу страну.
4. **Библиотека трея** — `NotifyIcon` через WinForms-interop тянет `UseWindowsForms`;
   альтернатива H.NotifyIcon (NuGet). Выбрать в W6.
5. **UIA-детект ссылок** может работать по-разному в Chrome/Firefox/Edge — проверять на всех
   трёх (на macOS AX-детект пришлось проверять в Safari и Firefox отдельно).
6. **Защищённый рабочий стол UAC** — даже uiAccess-приложения там ограничены. Проверять
   вживую в W8; вероятный итог — честно задокументировать как недоступную зону (аналог
   `loginwindow` на macOS).

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
