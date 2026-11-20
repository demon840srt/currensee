/// Saved pill position on one display. Coordinates are AppKit screen points (not money, so `Double`).
public struct WidgetPlacement: Codable, Sendable, Hashable {
    public let screenID: String
    public var originX: Double
    public var originY: Double
    public var isLocked: Bool

    public init(screenID: String, originX: Double, originY: Double, isLocked: Bool) {
        self.screenID = screenID
        self.originX = originX
        self.originY = originY
        self.isLocked = isLocked
    }
}
