import AppKit
import SwiftUI

/// Borderless, non-activating panel hosting the pill.
/// Phase 1: normal level, fixed position. Desktop level, Spaces, drag and lock arrive in Phase 4.
final class PillPanel: NSPanel {
    init() {
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
        contentView = NSHostingView(rootView: PillView())
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func moveToTopCenter(of screen: NSScreen?) {
        guard let screen = screen ?? NSScreen.screens.first else { return }
        setFrameOrigin(PillGeometry.topCenterOrigin(size: frame.size, in: screen.visibleFrame))
    }
}

private struct PillView: View {
    var body: some View {
        Capsule()
            .fill(Color.black)
            .frame(width: PillGeometry.collapsedSize.width, height: PillGeometry.collapsedSize.height)
    }
}
