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

## Фазы Windows-реализации
- **W0 — Каркас:** `windows/` solution (3 проекта), `windows-ci.yml` (build+test на
  windows-latest), раздел «Freeze-immunity» в `docs/spec.md`, root README про обе платформы.
- **W1 — Порт ядра (без UI):** `DwellEngine`, `AutoScrollEngine`, `Settings`, `Point` →
  C# 1:1 из Swift; тесты → xUnit. Зелёные тесты = паритет поведения. Без Win32.
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
