import AppKit

/// Borderless, non-activating panel at desktop level on every Space (SPEC F1–F2, ADR-0004).
final class PillPanel: NSPanel {
    /// Just above the desktop icons, below normal app windows.
    static let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)

    /// Only while the dropdown is open, so Esc can close it (ADR-0017). Being a non-activating panel,
    /// taking key focus does not switch away from the user's current app.
    var allowsKey = false
    var onEscape: () -> Void = {}

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
        // Note: `.fullScreenNone` hides the window on macOS 26 (ADR-0004).
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape() } else { super.keyDown(with: event) }   // 53 = Esc
    }
}
