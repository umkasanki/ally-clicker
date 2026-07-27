# AllyClicker — macOS app

This directory holds the macOS application layer. It depends on the
`AllyClickerCore` Swift Package (repository root) for all pure logic.

**The Xcode project (`AllyClicker.xcodeproj`) is created on a Mac** — it cannot be
generated on Linux/WSL. The Swift source files here are staged and ready to be
added to that project.

## Creating the Xcode project (on Mac)

1. Xcode → File → New → Project → macOS → **App**
   - Product Name: `AllyClicker`
   - Interface: **AppKit** (not SwiftUI; uncheck "Use SwiftUI")
   - Language: Swift
   - Save inside this `App/` directory.
2. Delete the auto-generated `AppDelegate.swift` / `main.swift` / storyboard;
   add the files already in this directory instead.
3. Add the local package dependency:
   - File → Add Package Dependencies → Add Local… → select the repository root
     (the folder containing `Package.swift`).
   - Add `AllyClickerCore` to the app target's frameworks.
4. Target settings:
   - Deployment target: macOS 14
   - Info.plist: add `NSAccessibilityUsageDescription`
   - Set `LSUIElement = YES` (no Dock icon — runs as a menu bar app)
   - Signing: your personal team (no special entitlements needed for CGEvent,
     only the Accessibility permission granted at runtime)

## Layout

```
App/AllyClicker/
├── main.swift                 # NSApplication entry point
├── App/AppDelegate.swift      # lifecycle + Accessibility permission check
├── Adapters/                  # concrete implementations of Core's port protocols
│   └── CGMouseInjector.swift  # MouseInjecting → CGEvent
└── (next phases)
    ├── Adapters/CursorSampler.swift     # CursorSampling → NSEvent
    ├── Adapters/PanelZoneMapper.swift   # ZoneMapping → panel hit-test
    ├── RunLoop/DwellController.swift     # wires Core ↔ adapters, drives tick()
    ├── Panel/                            # NSPanel + buttons
    ├── Settings/                         # settings window
    └── StatusBar/                        # NSStatusItem menu bar icon
```
