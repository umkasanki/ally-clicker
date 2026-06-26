# DwellClick — план улучшений (форк)

> Репозиторий: https://github.com/pilotmoon/DwellClick
> Лицензия: Apache 2.0 — форк и модификация разрешены
> Язык: Objective-C / macOS only

---

## Что уже есть в DwellClick

### Клики
- ✅ Single Click (ЛКМ)
- ✅ Double Click
- ✅ Triple Click (реализован, но не на панели по умолчанию)
- ✅ Drag (обычный)
- ✅ Held Drag (залипший drag)
- ✅ Quick Drag (умный drag)
- ✅ Right Click (реализован через `rightClickerWithModifierController`, но **не на панели**)
- ✅ Модификаторы: Cmd+Click, Ctrl+Click, Option+Click, Shift+Click
- ✅ Клик с буфером обмена: Click+Copy, Click+Cut, Click+Paste
- ❌ Middle Click — **отсутствует**
- ❌ Auto-Scroll — **отсутствует**

### Панель
- ✅ Настраиваемый набор кнопок
- ✅ Горизонтальная и вертикальная ориентация
- ✅ Авто-скрытие панели
- ✅ Настройка прозрачности
- ✅ Настройка размера
- ✅ Визуальная анимация dwell (countdown)
- ✅ Звуковая обратная связь
- ✅ Jitter radius (dwell_radius: 2px)
- ✅ Move radius (move_radius: 10px)
- ✅ Sensitivity слайдер

### Механика
- ✅ Стейт-машина Off → MoveDetect → DwellDetect → ButtonDown
- ✅ WH_MOUSE_LL аналог — CGEventTap
- ✅ Default to Single Click
- ✅ Lock Current Click (залипание функции)
- ✅ Application blocking (блокировка в конкретных приложениях)
- ✅ Клавиатурные шорткаты для каждой функции
- ✅ Popup-меню выбора функции (круговое меню)

---

## Чего не хватает (наши улучшения)

### Улучшение 1 — Right Click на панели по умолчанию

**Проблема:** Right Click реализован (`rightClickerWithModifierController`), иконка есть (`Right-Click.png`), но не вынесен как стандартная кнопка панели.

**Решение:** Добавить Right Click в список кнопок панели по умолчанию.

**Сложность:** Низкая — функция уже готова, нужно только добавить в конфигурацию панели.

**Файлы:**
- `src/DCNewClicksPanel.m` — добавить кнопку в дефолтный набор
- `src/DCConstants.m` — добавить константу для нового типа кнопки

---

### Улучшение 2 — Middle Click (клик колёсиком)

**Проблема:** Отсутствует полностью.

**Три сценария использования:**
1. **Открыть ссылку в новой вкладке** — клик колёсиком по ссылке в браузере
2. **Закрыть вкладку** — клик колёсиком по вкладке в браузере
3. **Auto-Scroll** — активирует режим прокрутки (см. Улучшение 3)

**Решение:** Реализовать через `CGEventCreateMouseEvent` с типом `kCGEventOtherMouseDown/Up` (button number = 2).

```objc
// DCMouseClicker.m — добавить метод
+ (id)middleClickerWithModifierController:(DCFlagGroup *)modifierController
                                      tap:(DCMouseTap *)aTap
{
    return [[DCMouseClicker alloc] initWithDownType:kCGEventOtherMouseDown
                                            upType:kCGEventOtherMouseUp
                                          dragType:kCGEventOtherMouseDragged
                                        eventFlags:0
                                modifierController:modifierController
                                               tap:aTap];
}
```

**Файлы:**
- `src/DCMouseClicker.h/.m` — добавить `middleClickerWithModifierController`
- `src/DCClick.h` — добавить `DCClickTypeMiddle` в enum
- `src/DCEngine.m` — инициализировать `DCClickMiddleClick`
- `gfx/` — добавить иконку `Middle-Click.png`
- `src/DCNewClicksPanel.m` — добавить кнопку на панель

**Сложность:** Средняя.

---

### Улучшение 3 — Auto-Scroll (аналог Windows Middle Click Scroll)

**Проблема:** На macOS нет нативного auto-scroll по middle click. Пользователь хедтрекера не может скроллить страницу без этой функции.

**Готовая реализация:** [LinearMouse](https://github.com/linearmouse/linearmouse) — MIT лицензия, Swift.
Файл `LinearMouse/EventTransformer/AutoScrollTransformer.swift` содержит полноценный Auto-Scroll.

**Механика (из LinearMouse):**
1. Middle Click → фиксируется якорная точка
2. Dead zone 10px — движение меньше 10px от якоря игнорируется
3. Смещение курсора → генерируется `CGScrollWheelEvent` 60 FPS
4. Нелинейная скорость: `base + sqrt(adjusted) * boost`, макс 160px/тик
5. Два режима: `toggle` (клик → вкл/выкл) и `hold` (зажать → скролл, отпустить → стоп)
6. `preserveNativeMiddleClick` — если курсор над ссылкой/вкладкой → обычный middle click; если над прокручиваемым контентом → auto-scroll
7. Визуальный индикатор якоря на экране
8. Горизонтальный и вертикальный скролл одновременно

**Генерация scroll события (Swift):**
```swift
let event = CGEvent(scrollWheelEvent2Source: nil,
                    units: .pixel, wheelCount: 2,
                    wheel1: 0, wheel2: 0, wheel3: 0)
event?.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: vertical)
event?.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: horizontal)
event?.post(tap: .cgSessionEventTap)
```

**Стратегия интеграции в DwellClick:**
- Портировать `AutoScrollTransformer.swift` из LinearMouse (MIT → Apache 2.0 совместимо)
- Создать `DCAutoScrollController` на основе этого кода
- Интегрировать в `DCEngine.m` — активация через Middle Click, выход через single click

**Файлы:**
- `src/DCAutoScrollController.h/.m` — новый контроллер (порт из LinearMouse)
- `src/DCEngine.m` — интеграция
- `src/DCClick.h` — добавить `DCClickTypeAutoScroll`

**Сложность:** Средняя (готовый алгоритм из LinearMouse, нужна только интеграция).

---

### Улучшение 4 — Triple Click на панели по умолчанию

**Проблема:** Triple Click реализован и работает, иконка есть, но не вынесен как стандартная кнопка.

**Польза для хедтрекера:** Тройной клик выделяет строку/абзац — частая операция при работе с текстом.

**Решение:** Добавить в дефолтный набор кнопок панели (аналогично Right Click).

**Сложность:** Низкая.

---

## Приоритеты

| # | Улучшение | Сложность | Приоритет |
|---|---|---|---|
| 1 | Right Click на панели | Низкая | 🔴 Высокий |
| 2 | Middle Click | Средняя | 🔴 Высокий |
| 3 | Auto-Scroll | Высокая | 🟡 Средний |
| 4 | Triple Click на панели | Низкая | 🟢 Низкий |

---

## Стратегия

1. Форкнуть репозиторий
2. Начать с улучшений 1 и 4 (низкая сложность, быстрый результат)
3. Добавить Middle Click (улучшение 2)
4. Auto-Scroll — отдельной веткой, после тестирования базовых улучшений
5. Отправить PR в оригинальный репозиторий

---

## Статус

| # | Улучшение | Статус |
|---|---|---|
| 1 | Right Click на панели | ⬜ не начато |
| 2 | Middle Click | ⬜ не начато |
| 3 | Auto-Scroll | ⬜ не начато |
| 4 | Triple Click на панели | ⬜ не начато |
