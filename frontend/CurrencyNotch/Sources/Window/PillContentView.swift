import AppKit
import CurrencyCore
import OSLog
import SwiftUI

#if DEBUG
private let eventLog = Logger(subsystem: "com.afik.CurrencyNotch", category: "pointer")
#endif

/// Receives all mouse events for the pill and turns them into click / drag / context-menu actions.
final class PillContentView: NSView {
    var isLocked: () -> Bool = { false }
    var onDragBegan: () -> Void = {}
    var onDragMoved: (CGVector) -> Void = { _ in }
    var onDragEnded: () -> Void = {}
    var onClick: () -> Void = {}
    var contextMenu: () -> NSMenu? = { nil }

    private var gesture: PointerGesture?
    private var didBeginDrag = false

    init<Content: View>(rootView: Content) {
        super.init(frame: CGRect(origin: .zero, size: PillGeometry.collapsedSize))
        let host = NSHostingView(rootView: rootView)
        host.frame = bounds
        host.autoresizingMask = [.width, .height]
        addSubview(host)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    // Route every event inside the pill to this view, not the SwiftUI host.
    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    // Hover expand arrives in Phase 6; for now these only feed the Debug event log (ADR-0004 check).
    override func mouseEntered(with event: NSEvent) { debugLog("entered") }
    override func mouseExited(with event: NSEvent) { debugLog("exited") }

    private func debugLog(_ message: String) {
        #if DEBUG
        eventLog.debug("pill \(message, privacy: .public)")
        #endif
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            rightMouseDown(with: event)
            return
        }
        gesture = PointerGesture(start: NSEvent.mouseLocation, isLocked: isLocked())
        didBeginDrag = false
        debugLog("down")
    }

    override func mouseDragged(with event: NSEvent) {
        guard var current = gesture else { return }
        current.update(to: NSEvent.mouseLocation)
        gesture = current
        guard current.shouldMoveWindow else { return }
        if !didBeginDrag {
            didBeginDrag = true
            onDragBegan()
        }
        onDragMoved(current.offset)
    }

    override func mouseUp(with event: NSEvent) {
        defer { gesture = nil; didBeginDrag = false }
        guard let current = gesture else { return }
        debugLog(current.isClick ? "up: click" : (didBeginDrag ? "up: drag ended" : "up: locked drag ignored"))
        if current.isClick {
            onClick()
        } else if didBeginDrag {
            onDragEnded()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        gesture = nil
        debugLog("right click")
        guard let menu = contextMenu() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}
