import AppKit
import AllyClickerCore

// Owns the panel window and its buttons. Builds the button list from
// Settings.panel.items (order = on-screen order), renders the armed highlight,
// handles collapse/expand, and implements the ZoneMapping port via hit-testing.

// Flipped container so button layout runs top → bottom (matching items order).
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class PanelViewController: ZoneMapping {
    let window: PanelWindow
    private let container = FlippedView()
    private var buttons: [PanelButton] = []

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
        let originX = screenFrame.maxX - width
        // positionY is a top-left offset; convert to bottom-left window origin.
        let originY = screenFrame.maxY - CGFloat(settings.panel.positionY) - totalHeight

        window = PanelWindow(contentRect: NSRect(x: originX, y: originY, width: width, height: totalHeight))
        container.frame = NSRect(x: 0, y: 0, width: width, height: totalHeight)
        window.contentView = container
        buttons.forEach { container.addSubview($0) }
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
        for button in buttons {
            if case .action(let a) = button.item {
                button.isArmed = (a == action)
            } else {
                button.isArmed = false
            }
        }
    }

    // MARK: - Collapse / expand (ON/OFF)

    func toggleCollapsed() {
        isCollapsed.toggle()
        for button in buttons {
            if case .command(.togglePanel) = button.item { continue }
            button.isHidden = isCollapsed
        }
        layout()
    }

    // MARK: - Layout

    private func layout() {
        let visible = buttons.filter { !$0.isHidden }
        let height = CGFloat(visible.count) * buttonSize

        var y: CGFloat = 0
        for button in buttons where !button.isHidden {
            button.frame = NSRect(x: 0, y: y, width: width, height: buttonSize)
            y += buttonSize
        }
        container.frame = NSRect(x: 0, y: 0, width: width, height: height)

        // Resize the window keeping its TOP edge fixed (panel stays docked at top).
        var frame = window.frame
        let topEdge = frame.maxY
        frame.size = NSSize(width: width, height: height)
        frame.origin.y = topEdge - height
        window.setFrame(frame, display: true)
    }
}
