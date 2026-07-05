import AppKit
import AllyClickerCore

// Owns the panel window and its buttons. Builds the button list from
// Settings.panel.items (order = on-screen order), renders the armed highlight,
// handles collapse/expand, and implements the ZoneMapping port via hit-testing.

// Flipped container so button layout runs top → bottom (matching items order).
// Draws the panel background itself (buttons are transparent) so the sliding
// armed-pill can live between the background and the icons.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
    }
}

// The sliding red highlight behind the armed button's icon.
private final class ArmedPillView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 9   // slightly less than the panel's 12pt
        layer?.backgroundColor = NSColor.systemRed.cgColor
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
}

final class PanelViewController: ZoneMapping {
    let window: PanelWindow
    private let container = FlippedView()
    private let pill = ArmedPillView()
    private var buttons: [PanelButton] = []
    // Where the pill currently sits: an armed click action OR a just-fired command.
    private var pillTarget: PanelItem? = nil
    private let pillInset: CGFloat = 6

    private let buttonSize: CGFloat
    private let width: CGFloat
    private(set) var isCollapsed = false

    init(settings: Settings) {
        width = CGFloat(settings.panel.width)
        buttonSize = width  // square buttons

        // Build buttons from the configured, normalized layout.
        let items = Settings.Panel.normalize(settings.panel.items)
        buttons = items.map { PanelButton(item: $0) }

        // Window docked to the right edge at the configured Y (top-left space).
        let totalHeight = CGFloat(items.count) * buttonSize
        let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        // DEBUG: center on screen to rule out off-screen positioning.
        let originX = screenFrame.midX - width / 2
        let originY = screenFrame.midY - totalHeight / 2

        let initialFrame = Self.clampToScreen(
            NSRect(x: originX, y: originY, width: width, height: totalHeight))
        NSLog("AllyClicker: screenFrame=\(NSStringFromRect(screenFrame)) items=\(items.count) frame=\(NSStringFromRect(initialFrame))")
        window = PanelWindow(contentRect: initialFrame)
        container.frame = NSRect(x: 0, y: 0, width: width, height: totalHeight)
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        window.contentView = container
        pill.isHidden = true
        container.addSubview(pill)                       // below the buttons
        buttons.forEach { container.addSubview($0) }     // transparent, icons on top
        layout()
    }

    func show() {
        window.orderFrontRegardless()
    }

    // MARK: - ZoneMapping

    func zone(at point: Point) -> DwellEngine.Zone {
        let screenPt = ScreenGeometry.toBottomLeft(point)
        guard window.frame.contains(screenPt) else { return .desktop }
        let winPt = window.convertPoint(fromScreen: screenPt)
        let localPt = container.convert(winPt, from: nil)
        for button in buttons where !button.isHidden {
            if button.frame.contains(localPt) {
                switch button.item {
                case .action(let a):  return .panel(button: a)
                case .command(let c): return .panelCommand(c)
                }
            }
        }
        return .panel(button: nil)
    }

    // MARK: - Visual state

    func setArmed(_ action: DwellEngine.Action?) {
        movePill(to: action.map { PanelItem.action($0) })
    }

    /// Slide the pill under a command button when it fires (visual feedback).
    func showCommand(_ command: DwellEngine.Command) {
        movePill(to: .command(command))
    }

    private func movePill(to target: PanelItem?) {
        pillTarget = target

        for button in buttons {
            button.isArmed = (button.item == target)
            button.needsDisplay = true
        }

        guard let targetButton = pillButton(), !targetButton.isHidden else {
            pill.isHidden = true
            return
        }
        let targetFrame = targetButton.frame.insetBy(dx: pillInset, dy: pillInset)

        if pill.isHidden {
            // Appearing from nothing: place instantly (no slide from a stale spot).
            pill.frame = targetFrame
            pill.isHidden = false
        } else {
            // Slide from wherever the pill is to the new button.
            // Custom ease-in-out with a slight overshoot feel: gentle start,
            // confident middle, soft settle — reads as physical motion.
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
                ctx.allowsImplicitAnimation = true
                pill.animator().frame = targetFrame
            }
        }
    }

    private func pillButton() -> PanelButton? {
        guard let target = pillTarget else { return nil }
        return buttons.first { $0.item == target }
    }

    /// The panel must ALWAYS be fully on screen — a control surface that slides
    /// off-screen would be unreachable for a hands-free user. Clamp any frame
    /// into the visible area of the screen it (mostly) belongs to.
    static func clampToScreen(_ frame: NSRect) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.intersects(frame) }
            ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return frame }
        var f = frame
        f.origin.x = min(max(f.origin.x, visible.minX), visible.maxX - f.width)
        f.origin.y = min(max(f.origin.y, visible.minY), visible.maxY - f.height)
        return f
    }

    // MARK: - Collapse / expand (ON/OFF)

    func toggleCollapsed() {
        isCollapsed.toggle()
        let affected = buttons.filter {
            if case .command(.togglePanel) = $0.item { return false }
            return true
        }

        if isCollapsed {
            // Fade the buttons out, then shrink the window.
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.12
                affected.forEach { $0.animator().alphaValue = 0 }
            }, completionHandler: { [weak self] in
                affected.forEach { $0.isHidden = true }
                self?.applyLayout(animated: true)
            })
        } else {
            // Grow the window, then fade the buttons back in.
            affected.forEach { $0.isHidden = false; $0.alphaValue = 0 }
            applyLayout(animated: true) {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.15
                    affected.forEach { $0.animator().alphaValue = 1 }
                }
            }
        }
    }

    // MARK: - Layout

    private func layout() {
        applyLayout(animated: false)
    }

    private func applyLayout(animated: Bool, completion: (() -> Void)? = nil) {
        let visible = buttons.filter { !$0.isHidden }
        let height = CGFloat(visible.count) * buttonSize

        var y: CGFloat = 0
        for button in buttons where !button.isHidden {
            button.frame = NSRect(x: 0, y: y, width: width, height: buttonSize)
            y += buttonSize
        }

        // Resize the window keeping its TOP edge fixed (panel stays docked at top).
        var frame = window.frame
        let topEdge = frame.maxY
        frame.size = NSSize(width: width, height: height)
        frame.origin.y = topEdge - height
        frame = Self.clampToScreen(frame)

        let finish = { [weak self] in
            guard let self else { return }
            // Keep the pill glued to its button through relayouts (no animation).
            if let target = self.pillButton(), !target.isHidden {
                self.pill.frame = target.frame.insetBy(dx: self.pillInset, dy: self.pillInset)
                self.pill.isHidden = false
            } else {
                self.pill.isHidden = true
            }
            completion?()
        }

        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
                window.animator().setFrame(frame, display: true)
            }, completionHandler: finish)
        } else {
            window.setFrame(frame, display: true)
            finish()
        }
    }
}
