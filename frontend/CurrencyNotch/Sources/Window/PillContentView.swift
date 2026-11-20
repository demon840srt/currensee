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
    var onPointerEntered: () -> Void = {}
    var onPointerExited: () -> Void = {}
    /// The pill's area in this view; outside it (the dropdown list) events go to SwiftUI so the list can scroll.
    var pillRect: CGRect?

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

    // Route events inside the pill to this view (click/drag/menu); the list area goes to SwiftUI.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard frame.contains(point) else { return nil }
        let local = convert(point, from: superview)
        if let pillRect, !pillRect.contains(local) { return super.hitTest(point) }
        return self
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        debugLog("entered")
        onPointerEntered()
    }

    override func mouseExited(with event: NSEvent) {
        debugLog("exited")
        onPointerExited()
    }

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
