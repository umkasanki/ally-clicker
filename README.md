# AllyClicker

A native macOS dwell-click tool for head tracker users.

Hover over a button on the floating panel, hold still for a moment — the click fires automatically. No hands required.

Inspired by [Point-N-Click](https://polital.com/pnc/) by Polital Enterprises.

---

## What it does

AllyClicker shows a small vertical panel docked to the screen edge. Each button represents a mouse action:

| Button | Action |
|--------|--------|
| ⏻ | Show / hide the panel |
| Left click | Single left click |
| Right click | Single right click |
| Drag | Click and drag (select text, move files) |
| Double click | Double left click |
| Middle click | Middle click / auto-scroll |
| Keyboard | Launch a configurable app (e.g. on-screen keyboard) |

**How dwell works:** stop the cursor over a button → it arms that action (red highlight). Move the cursor anywhere on screen and stop → the action fires at that position. Brush the panel to cancel instantly — no dwell required.

---

## Requirements

- macOS 14+
- **Accessibility permission** — required for click injection  
  System Settings → Privacy & Security → Accessibility → enable AllyClicker

---

## Building

Open the project in Xcode:

```bash
git clone git@github.com:umkasanki/ally-clicker.git
cd ally-clicker
open Package.swift
```

Then press **Cmd+R** to build and run.

To run tests: **Cmd+U**

---

## Project structure

```
Sources/
  AllyClickerCore/   — pure logic (DwellEngine state machine, Settings model)
  AllyClicker/       — macOS app (AppKit panel, CGEvent injection)
Tests/
  AllyClickerTests/  — unit tests for DwellEngine
```

`AllyClickerCore` has no macOS UI dependencies and is fully unit-testable.

---

## Status

Work in progress. See [docs/plan.md](docs/plan.md) for the implementation roadmap.

---

## Credits

Inspired by **Point-N-Click** by Polital Enterprises — a Windows dwell-click tool.  
Auto-scroll algorithm based on [LinearMouse](https://github.com/linearmouse/linearmouse) (MIT).
