# DwellClick — идеи для PR / форка

> Репозиторий: https://github.com/pilotmoon/DwellClick
> Лицензия: Apache 2.0 — форк и модификация разрешены
> Язык: Objective-C / macOS

---

## Контекст

DwellClick — зрелое macOS-приложение с dwell-click механикой.
Рассматриваем как основу для macOS-версии вместо написания с нуля.

Недостающие функции по сравнению с нашим AllyClicker:

---

## Идеи для PR

### 1. Кнопка правого клика (ПКМ) на панели
- У них есть иконка `Right-Click.png` и реализация `rightClickerWithModifierController`
- Но кнопка не вынесена на панель по умолчанию
- **Задача:** добавить `Right-Click` как опциональную кнопку панели
- Файлы для изменения: `DCNewClicksPanel.m`, `DCClicksPanel.m`

### 2. Клик средней кнопкой (колёсико / Middle Click)
- Не реализован совсем
- **Задача:** добавить `Middle Click` через `CGEventCreateMouseEvent` с типом `kCGEventOtherMouseDown/Up`
- Добавить иконку и кнопку на панель

### 3. Auto-Scroll (аналог Windows Middle Click scroll)
- После Middle Click — фиксируется якорная точка
- Смещение курсора по Y → генерируется `CGScrollWheelEvent` пропорционально
- Зигзаг курсора — скролл продолжается
- Left click — выход из режима
- **Источник механики:** Scroll Reverser (`kCGScrollWheelEventDeltaAxis1`)
- Файлы: новый `DCAutoScrollController.m` + интеграция в `DCEngine.m`

### 4. Тройной клик (Triple Click) на панели
- Реализован (`DCClickTypeTriple`), иконка есть (`Triple-Click.png`)
- Но не вынесен на панель по умолчанию
- **Задача:** добавить как опциональную кнопку

---

## Статус

| # | Идея | Статус |
|---|---|---|
| 1 | ПКМ на панели | ⬜ не начата |
| 2 | Middle Click | ⬜ не начата |
| 3 | Auto-Scroll | ⬜ не начата |
| 4 | Triple Click на панели | ⬜ не начата |

---

## Решение по платформам

| Платформа | Подход |
|---|---|
| **macOS** | Форк DwellClick + добавить недостающие кнопки |
| **Windows** | Свой AllyClicker на Python |
