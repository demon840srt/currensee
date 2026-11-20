import Foundation

public enum AlertDirection: String, Codable, Sendable, CaseIterable {
    case above, below
}

/// Notify once when `quoteCode` (priced in `baseCode`) crosses `threshold`; re-arm on cross-back.
public struct RateAlert: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public var quoteCode: String
    public var baseCode: String
    public var direction: AlertDirection
    public var threshold: Decimal
    public var isArmed: Bool
    public var lastTriggeredAt: Date?

    public init(id: UUID = UUID(), quoteCode: String, baseCode: String, direction: AlertDirection,
                threshold: Decimal, isArmed: Bool = true, lastTriggeredAt: Date? = nil) {
        self.id = id
        self.quoteCode = quoteCode
        self.baseCode = baseCode
        self.direction = direction
        self.threshold = threshold
        self.isArmed = isArmed
        self.lastTriggeredAt = lastTriggeredAt
    }

    enum CodingKeys: String, CodingKey { case id, quoteCode, baseCode, direction, threshold, isArmed, lastTriggeredAt }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        quoteCode = try c.decode(String.self, forKey: .quoteCode)
        baseCode = try c.decode(String.self, forKey: .baseCode)
        direction = try c.decode(AlertDirection.self, forKey: .direction)
        threshold = try c.decodeDecimal(forKey: .threshold)
        isArmed = try c.decode(Bool.self, forKey: .isArmed)
        lastTriggeredAt = try c.decodeIfPresent(Date.self, forKey: .lastTriggeredAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(quoteCode, forKey: .quoteCode)
        try c.encode(baseCode, forKey: .baseCode)
        try c.encode(direction, forKey: .direction)
        try c.encodeDecimal(threshold, forKey: .threshold)
        try c.encode(isArmed, forKey: .isArmed)
        try c.encodeIfPresent(lastTriggeredAt, forKey: .lastTriggeredAt)
    }
}
