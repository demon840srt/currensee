import AppKit

/// Borderless, non-activating panel at desktop level on every Space (SPEC F1–F2, ADR-0004).
final class PillPanel: NSPanel {
    /// Just above the desktop icons, below normal app windows.
    static let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)

    init(contentView: NSView) {
        super.init(
            contentRect: CGRect(origin: .zero, size: PillGeometry.collapsedSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false            // we move it ourselves so clicks and drags can be told apart
        acceptsMouseMovedEvents = true
        level = Self.desktopLevel
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
