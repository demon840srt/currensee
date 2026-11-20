import Foundation

/// Price of one unit of `quoteCode`, expressed in `baseCode` (e.g. USD in ILS = 3.7012).
public struct RateQuote: Codable, Sendable, Hashable {
    public let quoteCode: String
    public let baseCode: String
    public let value: Decimal
    public let fetchedAt: Date
    /// Provider id that produced the quote (e.g. "coinbase").
    public let source: String

    public init(quoteCode: String, baseCode: String, value: Decimal, fetchedAt: Date, source: String) {
        self.quoteCode = quoteCode
        self.baseCode = baseCode
        self.value = value
        self.fetchedAt = fetchedAt
        self.source = source
    }

    enum CodingKeys: String, CodingKey { case quoteCode, baseCode, value, fetchedAt, source }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        quoteCode = try c.decode(String.self, forKey: .quoteCode)
        baseCode = try c.decode(String.self, forKey: .baseCode)
        value = try c.decodeDecimal(forKey: .value)
        fetchedAt = try c.decode(Date.self, forKey: .fetchedAt)
        source = try c.decode(String.self, forKey: .source)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(quoteCode, forKey: .quoteCode)
        try c.encode(baseCode, forKey: .baseCode)
        try c.encodeDecimal(value, forKey: .value)
        try c.encode(fetchedAt, forKey: .fetchedAt)
        try c.encode(source, forKey: .source)
    }
}
