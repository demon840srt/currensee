import Foundation

/// Money values are encoded as strings ("3.7012") so JSON never routes them through `Double`.
enum DecimalCoding {
    static let posix = Locale(identifier: "en_US_POSIX")

    static func string(from value: Decimal) -> String {
        var v = value
        return NSDecimalString(&v, posix)
    }

    /// Strict parse: digits with an optional sign and a single decimal point; the whole string must match.
    static func decimal(from string: String) -> Decimal? {
        guard string.wholeMatch(of: /[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?/) != nil else { return nil }
        return Decimal(string: string, locale: posix)
    }
}

extension KeyedDecodingContainer {
    func decodeDecimal(forKey key: Key) throws -> Decimal {
        let raw = try decode(String.self, forKey: key)
        guard let value = DecimalCoding.decimal(from: raw), value.isFinite else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self,
                                                   debugDescription: "Not a decimal number")
        }
        return value
    }
}

extension KeyedEncodingContainer {
    mutating func encodeDecimal(_ value: Decimal, forKey key: Key) throws {
        try encode(DecimalCoding.string(from: value), forKey: key)
    }
}
