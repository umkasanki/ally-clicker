# Project brief: macOS dwell-click / virtual mouse (Point-N-Click port)

> Kickoff document for a new Claude Code project. Read this first, then see
> `PNCSettings.swift` and `pnc-settings-model.json` for the data model.

## 1. Goal

Build a macOS application that lets a user operate the mouse entirely hands-free
using **dwell clicking**: the cursor (driven by a head tracker) rests over a
target for a short time and a click is injected automatically. A small on-screen
panel lets the user choose which click type (left, right, drag, etc.) the next
dwell will perform.

This is a personal-use re-creation of **Point-N-Click (PNC)** by Polital
Enterprises — a Windows program the user has relied on for years. The macOS
version should reproduce PNC's *behavior* and *configurability*, not its code.
If released, it must credit PNC as the inspiration. Not for sale / no monetization.

## 2. Context & constraints

- The user is fully paralyzed and drives the cursor with a head tracker
  (SmartNav / NaturalPoint class device). Hands-free operation is the whole point.
- The user is a hobbyist developer, not a professional. Favor clear, well-commented,
  incremental code over cleverness. Explain non-obvious macOS specifics.
- Target: modern macOS (Apple Silicon, recent macOS). Swift + AppKit is the
  natural choice. SwiftUI is fine for the settings window; the always-on-top
  panel and event handling are easier reasoned about in AppKit.

## 3. What PNC is (and why this is a rewrite, not a translation)

From the PNC author directly:

- PNC is written in **VB.NET** and is **tightly tied to Windows and .NET**.
- It **senses mouse movement** and **injects mouse clicks/movements at system
  level**, for itself and for any other running program, and can suppress the
  original mouse actions when needed.
- The configuration program is **not** the clever part — it just collects the
  user's input and **stores it in the Windows registry**, where the other PNC
  programs read it. "Mostly lots of forms."

So the split is clean:

- **Low-level layer (Windows-specific, must be rewritten for macOS):** sensing
  cursor movement + injecting synthetic clicks at system level.
- **Behavioral layer (OS-independent, already captured here):** which parameters
  exist, what they mean, and how they relate. This is the valuable part and it
  is fully described in section 6 + the model files.

## 4. macOS technical approach (the rewrite)

The Windows low-level work maps onto these macOS APIs:

- **Reading cursor position:** sample the global mouse location on a timer
  (`CGEvent(source:)?.location` or `NSEvent.mouseLocation`), polling every
  `trackerIntervalMs`. No special entitlement needed just to read location.
- **Injecting clicks:** build `CGEvent` mouse events
  (`.leftMouseDown` / `.leftMouseUp`, right, other button) and post them with
  `CGEvent.post(tap: .cgSessionEventTap)`. Double-click = set the
  `.mouseEventClickState` field. Drag = down, move, up sequence.
- **Permissions (critical):** posting synthetic events system-wide requires the
  app to be granted **Accessibility** access in
  System Settings → Privacy & Security → Accessibility. The app must detect
  when it lacks permission and guide the user to grant it (this is the #1 thing
  that "silently does nothing" if missed). `AXIsProcessTrustedWithOptions` to
  check/prompt.
- **(Optional later) suppressing the real click / intercepting events:** a
  `CGEventTap` can observe and modify/swallow events. Only needed if you want to
  replace the physical click rather than add synthetic ones. Start without this.
- **Always-on-top panel:** a borderless `NSPanel` with
  `.nonactivatingPanel` + high `window.level` so it floats above other apps and
  doesn't steal focus when "clicked" via dwell.

### The core engine (OS-independent state machine)

This is the heart of the app and should be unit-testable without any macOS APIs:

1. Sample cursor position every `trackerIntervalMs`.
2. If the cursor has stayed within the `sensitivity` tolerance (a radius in
   pixels) since the dwell started, keep the dwell timer running; otherwise
   reset it and the dwell start point.
3. When the dwell timer reaches the relevant threshold
   (`dwellTimeMouseMs` for auto-click over the desktop, `dwellTimeMs` for a
   panel button, `dwellTimeExitMs` for the Exit button), fire the currently
   selected action.
4. `autoCancel` governs whether a pending action is cancelled when the user
   moves away before the threshold.

Keep this engine pure (input: positions + time + settings; output: "fire action
X"). Wire it to CGEvent injection at the edges. That makes the proven PNC
behavior portable and testable.

### Click-type selection + swipe-to-reset (CRITICAL feature — verified from video)

This is the single most important "feel" feature and the main reason the user
prefers PNC over alternatives. It must be a first-class part of the engine, not
an afterthought. It was confirmed by frame-by-frame analysis of the user's
screen recordings. Full spec lives in `DwellEngineSpec.swift`.

Model: there is exactly one `armedAction: ClickAction?` (optional — `nil` means
nothing is armed). The panel shows it visually:

- **Red button** = the currently armed action (fires on the next desktop dwell).
- **Yellow button** = the button under the cursor right now, with the dwell
  countdown in progress (not yet committed).
- **No highlight** = nothing armed (`armedAction == nil`).

Transitions (verified):

1. **Cursor enters the panel area → `armedAction = nil` immediately.** The red
   highlight disappears the instant the cursor touches the panel. This is the
   whole trick: cancelling costs zero precision and zero waiting — just brush
   the panel.
2. **Cursor dwells on a panel button for `dwellTimeMs`** (yellow fills) → that
   button's action is committed: `armedAction = thatAction` (turns red). A fast
   pass (a swipe) never completes any dwell, so nothing is committed.
3. **After a swipe (entered + left the panel without dwelling): nothing is
   armed, indefinitely.** No auto-revert, no timeout. The user re-arms whenever
   they want — 2 seconds or 2 hours later. (Verified: panel sits with no red
   highlight until the user deliberately dwells a button.)
4. **After an actual click fires on a target:** armed action reverts to **left**
   (`DefaultLeft = true`) — the common action is left ready. **(Confirmed by the
   PNC author.)**

**When `AutoCancel` is OFF (confirmed by the author):** a selected button stays
armed until the user either selects another button or selects the **Cancel**
button. I.e. there is no brush-to-cancel; cancelling requires aiming at and
dwelling on an explicit Cancel target. This is exactly the tiring behavior the
user wants to avoid — so the macOS version should default `autoCancel = true`
and treat the brush-to-cancel path as the primary design.

Why it reduces fatigue (design rationale — preserve this): by Fitts's law the
cancel target is the *entire panel* (huge, edge-docked, no precision needed) and
requires *no dwell at all*, whereas arming a specific action needs both aim and
a pause. Cancelling is therefore almost free while selecting is deliberate.
Competing tools implement cancel as just another button you must aim at and
dwell on — making cancel as expensive as selection. Keep cancel cheap.

## 5. Suggested milestones

1. **Permissions + injection spike:** request Accessibility access, inject a
   single left click at the current cursor location on a hotkey. Prove the
   pipeline end-to-end.
2. **Stillness engine:** implement the pure dwell state machine + unit tests
   using the values in the model. No UI yet.
3. **Auto-click over desktop:** combine 1 + 2 so resting still triggers a left
   click. Add the sensitivity/dwell sliders.
4. **Click-type panel:** floating non-activating NSPanel with buttons (left,
   right, drag, middle…) selectable by dwell; the next desktop dwell performs
   the chosen action; `defaultLeft` reverts after use.
5. **Settings window + persistence:** bind to `PNCSettings`, persist as JSON
   (or UserDefaults). Recreate the calibration "speed/sensitivity test".
6. **Polish:** audio/visual feedback, transparency, docking/hide behavior,
   repeat modes.

## 6. Settings reference (extracted from the live registry)

Source: `HKCU:\Software\Point-N-Click` on the user's machine, app version
**3.0.3.2**. These are the user's own tuned, working values — use them as the
defaults. Sub-keys `Shortcuts` was empty.

### Timing (stored as integers; the Windows UI shows them ÷1000 as seconds)

| Key             | Value | Meaning                                              |
|-----------------|-------|------------------------------------------------------|
| `DwellTime`     | 320   | Dwell before a panel button is selected → 0.32 s     |
| `DwellTimeExit` | 210   | Dwell before the Exit button → 0.21 s (shorter)      |
| `DwellTimeMouse`| 195   | Dwell before an auto-click fires → ~0.20 s           |
| `UseTimer`      | 30    | **Break Timer interval** (confirmed) — periodic rest-break reminder |
| `UseTimerReset` | 10    | **Break Timer interval** reset counterpart (confirmed)              |

### Stillness detection (OS-independent core)

| Key              | Value | Meaning                                                        |
|------------------|-------|----------------------------------------------------------------|
| `SensitivityV2`  | 1     | **Movement tolerance (confirmed)** — a radius; while the cursor stays within it the dwell timer runs, a larger move resets it. 1 = tightest. |
| `TrackerInterval`| 5     | Cursor sampling interval (ms)                                  |
| `BaselineFlags`  | 3     | **Calibration-done flag (confirmed):** indicates whether the first-run baseline tests have passed. If false, PNC runs the tests on launch and **cannot be used until they pass**. (Treat as: gate the app behind calibration.) |
| `AverageVelocity`| 0.39  | **Measured in the baseline test (confirmed).** Per-user movement speed; feeds the adaptive dwell formula below — it is *the* input that personalizes dwell timing. |

### Adaptive dwell — the core formula (confirmed by the PNC author)

This is the single most valuable thing recovered from the correspondence and the
original reason for wanting the source: **the desktop dwell time is not set
directly by the user — it is computed from a calibration measurement.** The
author gave the exact relation:

```
DwellTimeMouse = Int(DwellMultiplier * Sensitivity_Twips / AverageVelocity)
```

Where:

- `AverageVelocity` is measured during the mandatory first-run **baseline test**
  (the speed/sensitivity calibration). It captures how fast *this* user actually
  moves the cursor with their tracker.
- `Sensitivity_Twips` is the sensitivity setting expressed in twips (a legacy
  Windows VB unit: 1/1440 inch). On macOS there are no twips — replace with a
  points- or pixels-based sensitivity term and re-tune `DwellMultiplier` so the
  output range matches.
- `DwellMultiplier` is a scalar that sets the overall responsiveness.
- `Int(...)` truncates to an integer millisecond value.

**Why this matters / implications for the macOS port:**

1. **Calibration is core, not optional.** `DwellTimeMouse` (≈195 ms in the
   user's registry) is a *derived* value. To reproduce PNC's feel we must build
   the baseline speed test early and store the resulting `averageVelocity`; the
   dwell engine then computes its own timing from it. Slower movers automatically
   get a longer dwell, faster movers a shorter one — that auto-adaptation is what
   makes PNC comfortable for hours.
2. **Units must be re-derived for macOS.** Drop twips; pick a screen-space unit
   and recalibrate `DwellMultiplier` empirically so that, for the user's own
   `averageVelocity`, the formula lands near their known-good ~195 ms. Use the
   registry values as the target to calibrate against.
3. **Keep it in the pure engine.** The formula is OS-independent arithmetic — it
   belongs in the testable dwell engine, with `averageVelocity`,
   `dwellMultiplier`, and the sensitivity term as inputs.

### Click actions (enabled = injectable). User's enabled set in **bold**.

**Left**, **Left2**, **LeftDrag**, **Right**, Middle (**on**); RightDouble,
RightDrag, Middle2, MiddleDrag, RightLeft = off.
`DefaultLeft` = true (left is the default action), `AutoCancel` = true.

Confirmed meanings (from the author):

- `Left` / `Middle` = **single** left / middle click.
- `Left2` / `Middle2` = **double** left / middle click (not "secondary"). So the
  user's enabled set is: single-left, double-left, left-drag, right, middle.
- `RightLeft` = **right-then-left** combo: right-click (e.g. to open a context
  menu) immediately followed by a left-click to select an item. (Off for this
  user, but worth supporting.)

### Repeat

`RepeatMove`, `RepeatNoMove`, `FastRepeat` = all false.
`RAMB` = false; `RAMBTransparency` = 255.

**RAMB = Remote Access Mouse Button (confirmed — earlier "Repeat A Mouse Button"
guess was wrong).** It lets PNC be used when a full-screen app refuses to let the
PNC panel stay on top: the user defines a fixed spot on screen that they can
hover over to arm a mouse function, instead of reaching the normal panel.
`RAMBTransparency` controls that spot's opacity.

→ **macOS analog:** a small floating anchor window placed above full-screen
content. Note this is harder on macOS — windows above a Space's full-screen app
need an elevated window level and the right `collectionBehavior`
(e.g. `.canJoinAllSpaces` / `.fullScreenAuxiliary`), plus Accessibility. Treat
RAMB as a later milestone, after the main panel works.

### Appearance / feedback

`AUDIO` = true, `VISUAL` = false, `Transparency` = 255 (opaque),
`RedColor` = 255, `YellowColor` = 65535 (indicator colors),
`SINGLEROW` = true, `ActiveHide` = true, `AutoHide` = false, `AutoDock` = false.

### Panel geometry (documentation only — don't port literally)

`FormWidth` = 70, `FormHeight2.11` = 350, `FormTop` = 204, `FormLeft` = 1404;
size limits `MinWidth/Height` = 35/106, `MaxWidth/Height` = 150/829.
→ A narrow vertical strip docked near the right screen edge.

### Other

`CMDKEY` = -1, `CMDREPEAT` = -1, `CMDSHIFT` = 0 (command-key params),
`PNCPath` = `C:\Program Files (x86)\Point-N-Click NET\`, `Version` = 3.0.3.2.

## 7. Open questions — RESOLVED by the PNC author (2026-06-29)

All of the items previously listed here were confirmed in correspondence with
Anne York. Kept for the record:

- **Post-click revert:** confirmed — after an action fires, the armed action
  reverts to **left** (`DefaultLeft`). The *swipe* reset (clear to nothing) is a
  separate path. See §4.
- **`UseTimer` / `UseTimerReset`:** confirmed — Break Timer intervals (rest-break
  reminder), see §6.
- **`BaselineFlags` / `AverageVelocity`:** confirmed — `BaselineFlags` is the
  "calibration passed" gate; `AverageVelocity` is measured in the mandatory
  baseline test and feeds the dwell formula
  `DwellTimeMouse = Int(DwellMultiplier * Sensitivity_Twips / AverageVelocity)`.
  See §6 "Adaptive dwell".
- **`RAMB`:** confirmed — Remote Access Mouse Button (floating anchor for
  full-screen apps), **not** "repeat". See §6 Repeat.
- **`Left2` / `Middle2`:** confirmed — double left / middle click. See §6 Click
  actions.
- **`SensitivityV2`:** confirmed — a movement-tolerance radius. See §6 Stillness.

Remaining genuinely-open items are macOS-side design decisions, not PNC unknowns:
whether to implement the baseline calibration test (vs. a manual dwell value),
and how to re-derive the formula's units for macOS (twips → points/pixels).

## 8. Files in this project

- `PNCSettings.swift` — Swift `Codable` model (nested structs, documented units,
  defaults = the user's real values). Drop into the Xcode project.
- `DwellEngineSpec.swift` — the runtime state machine for dwell-clicking and
  click-type selection / swipe-reset (types + heavily-commented transition
  logic). This encodes the §4 behavior; build the engine from it.
- `pnc-settings-model.json` — the same model as JSON; load with
  `PNCSettings.load(from:)`. Keys are faithful to the registry names.

## 9. Attribution

The macOS app is an independent re-creation inspired by **Point-N-Click by
Polital Enterprises**. Credit Polital in the about/description. The author was
contacted directly and confirmed the configuration is straightforward
(input → registry); no PNC source code is used.
