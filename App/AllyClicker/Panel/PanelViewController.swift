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
        layer?.cornerRadius = 9   // placeholder — set from panel width (0.075·w) in PanelViewController
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

    private var buttonSize: CGFloat
    private var width: CGFloat
    private var orientation: Settings.Panel.Orientation
    private var isHorizontal: Bool { orientation == .horizontal }
    private(set) var isCollapsed = false

    // Drop tolerance/time for panel move mode (reuse the user's tuned values).
    private var dropRadius: Double
    private var dropDwell: TimeInterval
    // Serializes collapse/expand: re-toggling mid-animation could otherwise leave
    // buttons hidden while logically expanded (completion handlers racing).
    private var isTogglingCollapse = false

    /// Supplies the engine's actually-armed action so the pill can re-sync after
    /// expand (the pill parked on ON/OFF must not contradict the real armed state).
    var armedProvider: (() -> DwellEngine.Action?)? = nil

    /// Called after the user drags the panel, with the new TOP-LEFT origin (points).
    /// The app persists it so the panel reappears in place next launch.
    var onPositionChanged: ((_ x: Int, _ y: Int) -> Void)? = nil

    init(settings: Settings) {
        width = CGFloat(settings.panel.width)
        buttonSize = width  // square buttons
        orientation = settings.panel.orientation
        dropRadius = Double(settings.stillness.moveRadiusPx)
        dropDwell = settings.timing.dwellTimeSeconds

        // Build buttons from the configured, normalized layout.
        let items = Settings.Panel.normalize(settings.panel.items)
        let iconStyle = settings.appearance.iconStyle
        let iconScale = settings.appearance.iconScale
        buttons = items.map { PanelButton(item: $0, iconStyle: iconStyle, iconScale: iconScale) }

        // Panel dimensions depend on orientation: a vertical column (width × N·size)
        // or a horizontal row (N·size × height). Buttons are square, size = width.
        let horizontal = settings.panel.orientation == .horizontal
        let run = CGFloat(items.count) * buttonSize
        let panelW = horizontal ? run : width
        let panelH = horizontal ? buttonSize : run

        let screenFrame = Self.primaryScreenFrame()
        let origin = Self.defaultOrigin(settings: settings, horizontal: horizontal,
                                        panelW: panelW, panelH: panelH, screenFrame: screenFrame)
        let initialFrame = Self.clampToScreen(
            NSRect(x: origin.x, y: origin.y, width: panelW, height: panelH))
        window = PanelWindow(contentRect: initialFrame)
        container.frame = NSRect(x: 0, y: 0, width: panelW, height: panelH)
        container.wantsLayer = true
        container.layer?.cornerRadius = width * 0.10   // 10% of panel width
        container.layer?.masksToBounds = true
        pill.layer?.cornerRadius = width * 0.075        // slightly less than the panel
        window.contentView = container
        pill.isHidden = true
        container.addSubview(pill)                       // below the buttons
        buttons.forEach { container.addSubview($0) }     // transparent, icons on top
        // Notify persistence when the move-handle finishes a drag.
        buttons.forEach { $0.onMoved = { [weak self] in self?.reportPosition() } }
        layout()
    }

    func show() {
        window.orderFrontRegardless()
    }

    /// Start the panel collapsed (no animation), used at launch when the user opts
    /// in. No-op if already collapsed or if there's no ON/OFF button to expand with.
    func startCollapsed() {
        guard !isCollapsed,
              buttons.contains(where: { $0.item == .command(.togglePanel) }) else { return }
        isCollapsed = true
        for button in buttons where button.item != .command(.togglePanel) {
            button.isHidden = true
        }
        applyLayout(animated: false)
    }

    /// Rebuild the panel's buttons/size/orientation/transparency from edited
    /// settings, in place (same instance + window, so the DwellController's mapper
    /// reference stays valid). Called on Apply when any of those changed.
    /// If the user has never positioned the panel (positionX == nil), it re-docks to
    /// the orientation's default spot; otherwise it keeps its current top-left corner.
    func rebuild(with settings: Settings) {
        width = CGFloat(settings.panel.width)
        buttonSize = width
        orientation = settings.panel.orientation
        dropRadius = Double(settings.stillness.moveRadiusPx)
        dropDwell = settings.timing.dwellTimeSeconds
        container.layer?.cornerRadius = width * 0.10
        pill.layer?.cornerRadius = width * 0.075

        // Swap out the button views (pill stays below, added in init).
        buttons.forEach { $0.removeFromSuperview() }
        let items = Settings.Panel.normalize(settings.panel.items)
        let iconStyle = settings.appearance.iconStyle
        let iconScale = settings.appearance.iconScale
        buttons = items.map { PanelButton(item: $0, iconStyle: iconStyle, iconScale: iconScale) }
        buttons.forEach { button in
            button.onMoved = { [weak self] in self?.reportPosition() }
            container.addSubview(button)
        }

        // A rebuilt panel is fresh-expanded; drop any stale pill/collapse state.
        isCollapsed = false
        pillTarget = nil
        pill.isHidden = true

        window.alphaValue = CGFloat(settings.appearance.transparency) / 255.0

        // With no user-set position, re-dock to the orientation's default (e.g.
        // switching to horizontal jumps to top-center). applyLayout then keeps this
        // corner fixed. With a saved position, leave the current corner untouched.
        if settings.panel.positionX == nil {
            let run = CGFloat(buttons.count) * buttonSize
            let panelW = isHorizontal ? run : width
            let panelH = isHorizontal ? buttonSize : run
            let origin = Self.defaultOrigin(settings: settings, horizontal: isHorizontal,
                                            panelW: panelW, panelH: panelH,
                                            screenFrame: Self.primaryScreenFrame())
            window.setFrameOrigin(origin)
        }

        layout()
    }

    /// Report the panel's current TOP-LEFT origin so the app can persist it.
    private func reportPosition() {
        let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main
        let screenFrame = screen?.frame ?? .zero
        let x = Int((window.frame.minX - screenFrame.minX).rounded())
        let y = Int((screenFrame.maxY - window.frame.maxY).rounded())  // top-left Y
        onPositionChanged?(x, y)
    }

    // MARK: - ZoneMapping

    func zone(at point: Point) -> DwellEngine.Zone {
        let screenPt = ScreenGeometry.toBottomLeft(point)
        guard window.frame.contains(screenPt) else { return .desktop }
        let winPt = window.convertPoint(fromScreen: screenPt)
        let localPt = container.convert(winPt, from: nil)
        for button in buttons where !button.isHidden {
            if button.frame.contains(localPt) {
                // While the button is physically held (panel being dragged),
                // report it as chrome so the dwell toggle can't fire mid-drag.
                if button.isBeingDragged { return .panel(button: nil) }
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
        pillFadeGeneration += 1   // any pill activity cancels a pending collapsed-fade
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

    // After collapsing, the red pill lingers on ON/OFF; fade it away after 1s so
    // the collapsed button returns to its idle look. Cancelled if anything moves
    // the pill (or the panel re-expands) in the meantime.
    private var pillFadeGeneration = 0

    private func scheduleCollapsedPillFade() {
        pillFadeGeneration += 1
        let generation = pillFadeGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self,
                  self.pillFadeGeneration == generation,   // no newer pill activity
                  self.isCollapsed,
                  self.pillTarget == .command(.togglePanel) else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                self.pill.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                guard let self else { return }
                self.pill.isHidden = true
                self.pill.alphaValue = 1
                self.movePill(to: nil)
            })
        }
    }

    /// The panel must ALWAYS be fully on screen — a control surface that slides
    /// off-screen would be unreachable for a hands-free user. Clamp any frame
    /// into the visible area of the screen it (mostly) belongs to.
    /// The primary screen's full frame (top-left origin at 0,0), with a sane
    /// fallback for headless/edge cases.
    static func primaryScreenFrame() -> NSRect {
        let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main
        return screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }

    /// Bottom-left AppKit origin for the panel. A user-saved X wins; otherwise the
    /// default depends on orientation — horizontal docks TOP-CENTER, vertical docks
    /// to the RIGHT edge at the configured Y offset from the top.
    static func defaultOrigin(settings: Settings, horizontal: Bool,
                              panelW: CGFloat, panelH: CGFloat, screenFrame: NSRect) -> CGPoint {
        if let px = settings.panel.positionX {
            return CGPoint(x: screenFrame.minX + CGFloat(px),
                           y: screenFrame.maxY - CGFloat(settings.panel.positionY) - panelH)
        }
        if horizontal {
            return CGPoint(x: screenFrame.midX - panelW / 2, y: screenFrame.maxY - panelH)
        }
        return CGPoint(x: screenFrame.maxX - panelW,
                       y: screenFrame.maxY - CGFloat(settings.panel.positionY) - panelH)
    }

    static func clampToScreen(_ frame: NSRect) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.intersects(frame) }
            ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return frame }
        var f = frame
        f.origin.x = min(max(f.origin.x, visible.minX), visible.maxX - f.width)
        f.origin.y = min(max(f.origin.y, visible.minY), visible.maxY - f.height)
        return f
    }

    // MARK: - Move mode (hands-free panel drag via the DRAG function)
    //
    // Entered when DRAG is armed and the user dwells the ON/OFF button. The panel
    // follows the cursor (keeping the grab offset); stopping the cursor for
    // dropDwell drops it. The DwellController is paused meanwhile (see AppDelegate).

    private var moveTimer: DispatchSourceTimer?
    private var moveGrabOffset: CGPoint? = nil
    private var moveStillAnchor: CGPoint? = nil
    private var moveStillElapsed: TimeInterval = 0
    private let moveTick = 0.016

    /// Called when move mode ends (dropped), so the app can resume dwelling.
    var onMoveEnded: (() -> Void)? = nil
    var isMoving: Bool { moveTimer != nil }

    func beginMove() {
        guard moveTimer == nil else { return }   // idempotent
        let mouse = NSEvent.mouseLocation
        moveGrabOffset = CGPoint(x: mouse.x - window.frame.origin.x,
                                 y: mouse.y - window.frame.origin.y)
        moveStillAnchor = mouse
        moveStillElapsed = 0

        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: .milliseconds(16))
        t.setEventHandler { [weak self] in self?.moveStep() }
        t.resume()
        moveTimer = t
    }

    private func moveStep() {
        let mouse = NSEvent.mouseLocation
        // Runner is paused during a move, so nothing else drives the cursor —
        // set the move cursor here each tick (no tracking-area competition now).
        CursorPolicy.moving.set()

        if let grab = moveGrabOffset {
            var f = window.frame
            f.origin = CGPoint(x: mouse.x - grab.x, y: mouse.y - grab.y)
            f = Self.clampToScreen(f)
            window.setFrameOrigin(f.origin)
        }

        // Stop the cursor for dropDwell to drop the panel.
        if let anchor = moveStillAnchor {
            let d = hypot(mouse.x - anchor.x, mouse.y - anchor.y)
            if d <= dropRadius {
                moveStillElapsed += moveTick
                if moveStillElapsed >= dropDwell { endMove() }
            } else {
                moveStillAnchor = mouse
                moveStillElapsed = 0
            }
        }
    }

    func endMove() {
        moveTimer?.cancel()
        moveTimer = nil
        moveGrabOffset = nil
        moveStillAnchor = nil
        NSCursor.arrow.set()
        reportPosition()   // persist the new spot
        onMoveEnded?()
    }

    // MARK: - Collapse / expand (ON/OFF)

    func toggleCollapsed() {
        // No-op while a previous toggle is animating — safe (dwell re-fires need
        // a move-away anyway) and prevents the hidden-while-expanded race.
        guard !isTogglingCollapse else { return }
        isTogglingCollapse = true
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
                guard let self else { return }
                affected.forEach { $0.isHidden = true }
                self.applyLayout(animated: true) { [weak self] in
                    self?.scheduleCollapsedPillFade()
                    self?.isTogglingCollapse = false
                }
            })
        } else {
            // Grow the window, then fade the buttons back in.
            affected.forEach { $0.isHidden = false; $0.alphaValue = 0 }
            applyLayout(animated: true) { [weak self] in
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.15
                    affected.forEach { $0.animator().alphaValue = 1 }
                }, completionHandler: { [weak self] in
                    guard let self else { return }
                    // Re-sync the pill with the engine's real armed action — it
                    // must not sit on ON/OFF while (say) .left is actually armed.
                    self.setArmed(self.armedProvider?() ?? nil)
                    self.isTogglingCollapse = false
                })
            }
        }
    }

    // MARK: - Layout

    private func layout() {
        applyLayout(animated: false)
    }

    private func applyLayout(animated: Bool, completion: (() -> Void)? = nil) {
        let visible = buttons.filter { !$0.isHidden }
        let run = CGFloat(visible.count) * buttonSize

        // Lay buttons along the run axis: left→right (horizontal) or top→bottom
        // (vertical, flipped container so index 0 is at the top).
        var offset: CGFloat = 0
        for button in buttons where !button.isHidden {
            button.frame = isHorizontal
                ? NSRect(x: offset, y: 0, width: buttonSize, height: buttonSize)
                : NSRect(x: 0, y: offset, width: width, height: buttonSize)
            offset += buttonSize
        }

        // Resize the window keeping its TOP-LEFT corner fixed (the panel's anchor).
        var frame = window.frame
        let topEdge = frame.maxY
        let leftEdge = frame.minX
        frame.size = isHorizontal ? NSSize(width: run, height: buttonSize)
                                  : NSSize(width: width, height: run)
        frame.origin.x = leftEdge
        frame.origin.y = topEdge - frame.size.height
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
