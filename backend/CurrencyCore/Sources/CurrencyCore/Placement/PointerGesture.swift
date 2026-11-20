import CoreGraphics

/// Click-vs-drag decision for one mouse-down → mouse-up sequence (SPEC F5–F6).
/// Moving less than 4 pt is a click; once 4 pt is reached it stays a drag.
/// When locked, a drag does nothing and a click still works.
public struct PointerGesture: Sendable, Equatable {
    public enum Kind: Sendable, Equatable { case click, drag }

    public static let dragThreshold: CGFloat = 4

    public let start: CGPoint
    public let isLocked: Bool
    public private(set) var current: CGPoint
    public private(set) var kind: Kind = .click

    public init(start: CGPoint, isLocked: Bool) {
        self.start = start
        self.isLocked = isLocked
        self.current = start
    }

    public mutating func update(to point: CGPoint) {
        current = point
        let dx = point.x - start.x, dy = point.y - start.y
        if (dx * dx + dy * dy).squareRoot() >= Self.dragThreshold { kind = .drag }
    }

    /// Pointer movement since mouse-down (screen points).
    public var offset: CGVector { CGVector(dx: current.x - start.x, dy: current.y - start.y) }

    public var shouldMoveWindow: Bool { kind == .drag && !isLocked }

    /// True when mouse-up should act as a click.
    public var isClick: Bool { kind == .click }
}
