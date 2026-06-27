import CoreGraphics
import AllyClickerCore

// Injects synthetic mouse events at the OS level via CGEvent.
// Requires Accessibility permission — see AppDelegate.checkAccessibilityPermission().

struct InputController {

    func execute(_ action: DwellEngine.Action, at point: CGPoint) {
        switch action {
        case .left:        leftClick(at: point)
        case .right:       rightClick(at: point)
        case .middle:      middleClick(at: point)
        case .doubleClick: doubleClick(at: point)
        case .leftDrag:      break  // TODO: Phase 3.4 — two-phase drag (mouseDown + move + mouseUp)
        case .rightDouble:   break  // TODO: Phase 4+ — right double click
        case .rightThenLeft: break  // TODO: Phase 4+ — right then left sequence
        }
    }

    func leftClick(at point: CGPoint) {
        post(.leftMouseDown, at: point)
        post(.leftMouseUp, at: point)
    }

    func rightClick(at point: CGPoint) {
        post(.rightMouseDown, at: point)
        post(.rightMouseUp, at: point)
    }

    func doubleClick(at point: CGPoint) {
        for clickState in 1...2 {
            guard
                let down = makeEvent(.leftMouseDown, at: point),
                let up   = makeEvent(.leftMouseUp,   at: point)
            else { continue }
            down.setIntegerValueField(.mouseEventClickState, value: Int64(clickState))
            up.setIntegerValueField(.mouseEventClickState,   value: Int64(clickState))
            down.post(tap: .cgSessionEventTap)
            up.post(tap: .cgSessionEventTap)
        }
    }

    func middleClick(at point: CGPoint) {
        post(.otherMouseDown, at: point, button: .center)
        post(.otherMouseUp,   at: point, button: .center)
    }

    func mouseDown(at point: CGPoint) { post(.leftMouseDown, at: point) }
    func mouseUp(at point: CGPoint)   { post(.leftMouseUp,   at: point) }

    // MARK: Private

    private func post(_ type: CGEventType, at point: CGPoint, button: CGMouseButton = .left) {
        makeEvent(type, at: point, button: button)?.post(tap: .cgSessionEventTap)
    }

    private func makeEvent(_ type: CGEventType, at point: CGPoint, button: CGMouseButton = .left) -> CGEvent? {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button)
    }
}
