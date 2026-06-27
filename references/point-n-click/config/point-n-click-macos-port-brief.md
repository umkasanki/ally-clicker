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
   (`DefaultLeft = true`) — the common action is left ready. (Strongly
   indicated by video but flagged in open questions to confirm.)

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
| `UseTimer`      | 30    | "Use timer" — units unconfirmed (tenths/ticks?)      |
| `UseTimerReset` | 10    | Reset counterpart — units unconfirmed                |

### Stillness detection (OS-independent core)

| Key              | Value | Meaning                                                        |
|------------------|-------|----------------------------------------------------------------|
| `SensitivityV2`  | 1     | Movement tolerance ("Units" in UI). 1 = tightest. Pixel radius (confirm). |
| `TrackerInterval`| 5     | Cursor sampling interval (ms)                                  |
| `BaselineFlags`  | 3     | Calibration bit field — meaning unconfirmed, treat as opaque   |
| `AverageVelocity`| 0.39  | Avg cursor velocity measured in the speed test                 |

### Click actions (enabled = injectable). User's enabled set in **bold**.

**Left**, **Left2**, **LeftDrag**, **Right**, Middle (**on**); RightDouble,
RightDrag, Middle2, MiddleDrag, RightLeft = off.
`DefaultLeft` = true (left is the default action), `AutoCancel` = true.

### Repeat

`RepeatMove`, `RepeatNoMove`, `FastRepeat` = all false.
`RAMB` = false (RAMB ≈ "Repeat A Mouse Button"; `RAMBTransparency` = 255).

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

## 7. Open questions to confirm later

- **Post-click revert:** after an action fires on a target, does the armed action
  revert to left (`DefaultLeft`) or clear to nothing? Video strongly suggests
  revert-to-left; confirm with one observation. (Note: the *swipe* reset is
  confirmed to clear to nothing — these are two different paths, see §4.)
- Units of `UseTimer` / `UseTimerReset` (seconds tenths? internal ticks?).
- Exact meaning of `BaselineFlags` bits and how the speed test produces
  `AverageVelocity`.
- Precise behavior of `RAMB` and the `Left2` / `Middle2` "secondary" actions.
- Whether `SensitivityV2` is a pixel radius, and its real-world range.

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
