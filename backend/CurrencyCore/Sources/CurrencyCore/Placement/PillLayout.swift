import CoreGraphics

/// Window frames for the three pill modes (references/ui-sizes.md). AppKit coordinates (y up).
public enum PillLayout {
    public static let collapsedSize = CGSize(width: 200, height: 34)
    public static let expandedSize = CGSize(width: 280, height: 64)
    public static let rowHeight: CGFloat = 28
    public static let listPadding: CGFloat = 16
    public static let maxVisibleRows = 10
    /// Space between the pill and the dropdown list.
    public static let gap: CGFloat = 6

    public enum DropdownDirection: Sendable, Equatable { case below, above }

    public struct DropdownLayout: Sendable, Equatable {
        public let windowFrame: CGRect
        public let direction: DropdownDirection
        /// List height actually used (may be shorter than requested on small screens; the list scrolls).
        public let listHeight: CGFloat
    }

    /// Expanded pill grows evenly around the collapsed pill's center, then is kept on screen.
    public static func expandedFrame(collapsed: CGRect, in visible: CGRect) -> CGRect {
        let origin = CGPoint(x: collapsed.midX - expandedSize.width / 2, y: collapsed.midY - expandedSize.height / 2)
        return CGRect(origin: PlacementResolver.clamp(origin: origin, size: expandedSize, in: visible), size: expandedSize)
    }

    /// The collapsed "home" frame centered in a (dragged) expanded frame.
    public static func collapsedFrame(centeredIn frame: CGRect) -> CGRect {
        CGRect(x: frame.midX - collapsedSize.width / 2, y: frame.midY - collapsedSize.height / 2,
               width: collapsedSize.width, height: collapsedSize.height)
    }

    public static func visibleRows(_ rows: Int) -> Int { min(max(rows, 1), maxVisibleRows) }

    public static func dropdownHeight(rows: Int) -> CGFloat {
        CGFloat(visibleRows(rows)) * rowHeight + listPadding
    }

    /// Below the pill if it fits, else above if that fits, else whichever side has more room.
    public static func dropdownDirection(pill: CGRect, listHeight: CGFloat, in visible: CGRect) -> DropdownDirection {
        let roomBelow = pill.minY - visible.minY - gap
        let roomAbove = visible.maxY - pill.maxY - gap
        if roomBelow >= listHeight { return .below }
        if roomAbove >= listHeight { return .above }
        return roomBelow >= roomAbove ? .below : .above
    }

    /// Window covering the expanded pill plus the list; the pill stays where it is.
    public static func dropdownLayout(expanded pill: CGRect, rows: Int, in visible: CGRect) -> DropdownLayout {
        let wanted = dropdownHeight(rows: rows)
        let direction = dropdownDirection(pill: pill, listHeight: wanted, in: visible)
        let room = direction == .below ? pill.minY - visible.minY - gap : visible.maxY - pill.maxY - gap
        let listHeight = max(rowHeight, min(wanted, room))
        let height = pill.height + gap + listHeight
        let y = direction == .below ? pill.minY - gap - listHeight : pill.minY
        let frame = CGRect(x: pill.minX, y: y, width: pill.width, height: height)
        let origin = PlacementResolver.clamp(origin: frame.origin, size: frame.size, in: visible)
        return DropdownLayout(windowFrame: CGRect(origin: origin, size: frame.size), direction: direction,
                              listHeight: listHeight)
    }
}
