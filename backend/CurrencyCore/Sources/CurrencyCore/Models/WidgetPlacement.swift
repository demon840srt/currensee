/// Saved pill position on one display. Coordinates are AppKit screen points (not money, so `Double`).
/// The lock is global (`AppSettings.isPositionLocked`, ADR-0015), not per display.
public struct WidgetPlacement: Codable, Sendable, Hashable {
    public let screenID: String
    public var originX: Double
    public var originY: Double

    public init(screenID: String, originX: Double, originY: Double) {
        self.screenID = screenID
        self.originX = originX
        self.originY = originY
    }
}
