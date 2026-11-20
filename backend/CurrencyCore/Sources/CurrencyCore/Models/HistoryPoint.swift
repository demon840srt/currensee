import Foundation

/// One historical price of `quoteCode` in `baseCode`.
public struct HistoryPoint: Codable, Sendable, Hashable {
    public let quoteCode: String
    public let baseCode: String
    public let timestamp: Date
    public let value: Decimal

    public init(quoteCode: String, baseCode: String, timestamp: Date, value: Decimal) {
        self.quoteCode = quoteCode
        self.baseCode = baseCode
        self.timestamp = timestamp
        self.value = value
    }

    enum CodingKeys: String, CodingKey { case quoteCode, baseCode, timestamp, value }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        quoteCode = try c.decode(String.self, forKey: .quoteCode)
        baseCode = try c.decode(String.self, forKey: .baseCode)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        value = try c.decodeDecimal(forKey: .value)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(quoteCode, forKey: .quoteCode)
        try c.encode(baseCode, forKey: .baseCode)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encodeDecimal(value, forKey: .value)
    }
}
