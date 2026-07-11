import AppKit
import AllyClickerCore

// A single panel button. Shows an icon and two visual states:
//   • normal — plain background
//   • armed  — red background (the currently selected click action)
// No dwell countdown is rendered (out of scope by user preference, spec §2).

final class PanelButton: NSView {
    let item: PanelItem
    private let iconStyle: Settings.Appearance.IconStyle
    private let iconScale: CGFloat

    private let iconView = NSImageView()

    var isArmed: Bool = false {
        didSet { needsDisplay = true }
    }

    init(item: PanelItem, iconStyle: Settings.Appearance.IconStyle = .custom, iconScale: Double = 1.0) {
        self.item = item
        self.iconStyle = iconStyle
        self.iconScale = CGFloat(iconScale)
        super.init(frame: .zero)
        wantsLayer = true
        setupIcon()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private func setupIcon() {
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image = item.image(style: iconStyle)
        iconView.contentTintColor = .labelColor
        addSubview(iconView)
    }

    // Frame-based layout (no Auto Layout inside the borderless panel).
    override func layout() {
        super.layout()
        let size: CGFloat = iconSize
        iconView.frame = NSRect(x: (bounds.width - size) / 2,
                                y: (bounds.height - size) / 2,
                                width: size, height: size)
    }

    /// Per-button glyph size as a FRACTION of the (square) button — so any panel
    /// width looks right. Fractions are the original 70pt sizes over 70, so a 70pt
    /// button renders identically to before. ON/OFF is the primary control (largest),
    /// KEYBOARD slightly larger than the click glyphs.
    private var iconSize: CGFloat {
        let w = bounds.width   // square button = panel width
        let frac: CGFloat
        switch item {
        case .command(.togglePanel):    frac = 48.0 / 70
        case .command(.launchKeyboard): frac = 42.0 / 70
        default:                        frac = 36.0 / 70
        }
        // Custom glyphs carry built-in padding and differ per icon, so they use
        // per-button fractions. SF Symbols are optically uniform and fill their frame
        // tightly, so in System mode every glyph shares ONE smaller fraction — this
        // also keeps the power ring from towering over the click glyphs.
        let styled = (iconStyle == .system) ? (21.0 / 70) * w : frac * w
        return styled * iconScale
    }

    // The button itself is transparent — the container draws the panel background
    // and owns the sliding red pill (see PanelViewController). The button only
    // hosts the icon and switches its tint.
    override func draw(_ dirtyRect: NSRect) {
        iconView.contentTintColor = isArmed ? .white : .labelColor
        super.draw(dirtyRect)
    }

    // Cursor is managed centrally (CursorPolicy, driven from the dwell tick in
    // AppDelegate) — not via per-button tracking areas.

    // MARK: - Drag-to-move (ON/OFF is the panel's move handle)
    //
    // Dragging the power button moves the whole panel, clamped on-screen.
    // Works with a physical mouse AND with the app's own DRAG function
    // (arm DRAG → dwell on power → mouseDown → move → dwell → mouseUp).

    private var isMoveHandle: Bool {
        if case .command(.togglePanel) = item { return true }
        return false
    }

    private var dragGrabOffset: NSPoint? = nil

    /// Called when a move-handle drag finishes, so the panel position can persist.
    var onMoved: (() -> Void)? = nil

    /// True while the button is physically held (drag in progress). The zone
    /// mapper uses this to suppress the dwell toggle during a drag — pausing
    /// mid-drag must not collapse the panel under the user's hand.
    var isBeingDragged: Bool { dragGrabOffset != nil }

    override func mouseDown(with event: NSEvent) {
        guard isMoveHandle, let window else { return super.mouseDown(with: event) }
        let mouse = NSEvent.mouseLocation
        dragGrabOffset = NSPoint(x: mouse.x - window.frame.origin.x,
                                 y: mouse.y - window.frame.origin.y)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isMoveHandle, let window, let grab = dragGrabOffset else {
            return super.mouseDragged(with: event)
        }
        let mouse = NSEvent.mouseLocation
        var frame = window.frame
        frame.origin = NSPoint(x: mouse.x - grab.x, y: mouse.y - grab.y)
        frame = PanelViewController.clampToScreen(frame)
        window.setFrameOrigin(frame.origin)
    }

    override func mouseUp(with event: NSEvent) {
        let wasDragging = dragGrabOffset != nil
        dragGrabOffset = nil
        if wasDragging { onMoved?() }
        super.mouseUp(with: event)
    }
}

extension PanelItem {
    /// NSImage for a panel button, honoring the chosen icon style. Custom falls
    /// back to the SF Symbol when a project glyph is missing.
    func image(style: Settings.Appearance.IconStyle) -> NSImage? {
        let symbol = NSImage(systemSymbolName: sfSymbolName, accessibilityDescription: id)
        switch style {
        case .custom: return projectIcon ?? symbol
        case .system: return symbol
        }
    }

    /// Project icon (vector PDF from Resources/icons), template-tinted.
    /// nil → fall back to an SF Symbol.
    var projectIcon: NSImage? {
        guard let name = projectIconName,
              let url = Bundle.main.url(forResource: name, withExtension: "pdf",
                                        subdirectory: "icons"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true  // monochrome glyph → tintable via contentTintColor
        return image
    }

    private var projectIconName: String? {
        switch self {
        case .action(.left):        return "click-left"
        case .action(.right):       return "click-right"
        case .action(.leftDrag):    return "drag"
        case .action(.doubleClick): return "click-double"
        case .action(.middle):      return "wheel"
        case .command(.togglePanel):    return "power"
        case .command(.launchKeyboard): return "keyboard"
        default:                    return nil
        }
    }

    /// Human-readable name shown in the Settings panel editor.
    var displayName: String {
        switch self {
        case .action(.left):            return "Left click"
        case .action(.right):           return "Right click"
        case .action(.doubleClick):     return "Double click"
        case .action(.leftDrag):        return "Drag"
        case .action(.middle):          return "Middle / Scroll"
        case .action(.rightDouble):     return "Right double click"
        case .action(.rightThenLeft):   return "Right then left"
        case .command(.togglePanel):    return "Show / hide panel"
        case .command(.launchKeyboard): return "Keyboard"
        }
    }

    /// Items the user may add / remove / reorder in the panel editor. Excludes the
    /// actions not yet wired for injection (rightDouble, rightThenLeft) and KEYBOARD
    /// (moving to a separate panel).
    static var editorCatalog: [PanelItem] {
        [.command(.togglePanel),
         .action(.left),
         .action(.right),
         .action(.doubleClick),
         .action(.leftDrag),
         .action(.middle)]
    }

    /// SF Symbol fallback for items without a project icon.
    var sfSymbolName: String {
        switch self {
        case .action(.left):        return "cursorarrow.click"
        case .action(.right):       return "cursorarrow.click.2"
        case .action(.leftDrag):    return "hand.draw"
        case .action(.doubleClick): return "cursorarrow.click.badge.clock"
        case .action(.middle):      return "circle.circle"
        case .action(.rightDouble): return "cursorarrow.click.2"
        case .action(.rightThenLeft): return "cursorarrow.and.square.on.square.dashed"
        case .command(.togglePanel):    return "power"
        case .command(.launchKeyboard): return "keyboard"
        }
    }
}
