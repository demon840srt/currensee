import Foundation

/// Treats every API response as untrusted (SPEC §8).
public enum ResponseValidator {
    public static let maxBodySize = 1_048_576
    /// Values outside this range are considered absurd for any currency pair.
    public static let minimumValue = Decimal(sign: .plus, exponent: -12, significand: 1)
    public static let maximumValue = Decimal(sign: .plus, exponent: 15, significand: 1)
    /// A change larger than this fraction of the previous value is held until confirmed.
    public static let maxJumpFraction = Decimal(string: "0.5")!

    /// Final URL must be allowlisted (catches redirects), status must be 200, body ≤ 1 MB.
    public static func check(data: Data, response: HTTPURLResponse, allowlist: RateHostAllowlist) throws(RateError) {
        if let url = response.url { try allowlist.check(url) }
        guard data.count <= maxBodySize else { throw .responseTooLarge }
        guard response.statusCode == 200 else { throw .badStatus(response.statusCode) }
    }

    public static func isPlausible(_ value: Decimal) -> Bool {
        value.isFinite && !value.isNaN && value >= minimumValue && value <= maximumValue
    }

    /// Strictly parses a rate string; returns nil unless it's a plain number in the plausible range.
    public static func parseRate(_ string: String) -> Decimal? {
        guard let value = DecimalCoding.decimal(from: string), isPlausible(value) else { return nil }
        return value
    }

    public static func isJump(from old: Decimal, to new: Decimal) -> Bool {
        guard old > 0 else { return false }
        return abs(new - old) / old > maxJumpFraction
    }
}

/// Holds a value that jumped more than 50% until the next refresh confirms it (SPEC §8).
public struct JumpGuard: Sendable {
    private var pending: [String: Decimal] = [:]

    public init() {}

    /// Returns the value to accept, or nil while a jump is held.
    public mutating func evaluate(_ code: String, new: Decimal, previous: Decimal?) -> Decimal? {
        guard let previous, ResponseValidator.isJump(from: previous, to: new) else {
            pending[code] = nil
            return new
        }
        if let held = pending[code], !ResponseValidator.isJump(from: held, to: new) {
            pending[code] = nil
            return new
        }
        pending[code] = new
        return nil
    }

    public func isHolding(_ code: String) -> Bool { pending[code] != nil }

    public mutating func reset() { pending.removeAll() }
}
