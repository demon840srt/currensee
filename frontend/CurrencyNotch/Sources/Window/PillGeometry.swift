import CoreGraphics

/// Pure sizing and placement math for the pill (see references/ui-sizes.md).
enum PillGeometry {
    static let collapsedSize = CGSize(width: 200, height: 34)

    /// Origin (AppKit bottom-left coordinates) that centers `size` horizontally
    /// at the top edge of `visibleFrame`.
    static func topCenterOrigin(size: CGSize, in visibleFrame: CGRect) -> CGPoint {
        CGPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.maxY - size.height
        )
    }
}
