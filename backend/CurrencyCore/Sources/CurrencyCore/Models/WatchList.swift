import Foundation

public enum WatchListError: Error, Equatable, Sendable {
    case empty
    case duplicate(String)
    case containsBase(String)
    case invalidCode(String)
    case notFound(String)
    case cannotRemoveLast
}

/// The base currency plus the ordered currencies the pill rotates through.
/// Invariants: at least one code, no duplicates, the base is never in the list (ADR-0010).
public struct WatchList: Codable, Sendable, Equatable {
    public private(set) var baseCode: String
    public private(set) var orderedCodes: [String]

    public static let `default` = WatchList(
        unchecked: "ILS", ["USD", "EUR", "GBP", "JPY", "CHF", "CNY", "BTC", "ETH"]
    )

    public init(baseCode: String, orderedCodes: [String]) throws(WatchListError) {
        try Self.validate(baseCode: baseCode, orderedCodes: orderedCodes)
        self.baseCode = baseCode
        self.orderedCodes = orderedCodes
    }

    private init(unchecked baseCode: String, _ orderedCodes: [String]) {
        self.baseCode = baseCode
        self.orderedCodes = orderedCodes
    }

    public mutating func add(_ code: String) throws(WatchListError) {
        try Self.validate(baseCode: baseCode, orderedCodes: orderedCodes + [code])
        orderedCodes.append(code)
    }

    public mutating func remove(_ code: String) throws(WatchListError) {
        guard let index = orderedCodes.firstIndex(of: code) else { throw .notFound(code) }
        guard orderedCodes.count > 1 else { throw .cannotRemoveLast }
        orderedCodes.remove(at: index)
    }

    /// Same semantics as SwiftUI's `onMove`: `destination` is an offset in the list before the move.
    /// Out-of-range source offsets are ignored and the destination is clamped.
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let valid = source.filter { orderedCodes.indices.contains($0) }
        guard !valid.isEmpty else { return }
        let target = min(max(destination, 0), orderedCodes.count)
        let moving = valid.map { orderedCodes[$0] }
        var rest = orderedCodes.enumerated().filter { !valid.contains($0.offset) }.map(\.element)
        rest.insert(contentsOf: moving, at: target - valid.filter { $0 < target }.count)
        orderedCodes = rest
    }

    /// Switches the base. The new base leaves the list; if that empties it, the old base takes its place.
    public mutating func changeBase(to newBase: String) throws(WatchListError) {
        guard CurrencyCode.isValid(newBase) else { throw .invalidCode(newBase) }
        guard newBase != baseCode else { return }
        var codes = orderedCodes.filter { $0 != newBase }
        if codes.isEmpty { codes = [baseCode] }
        baseCode = newBase
        orderedCodes = codes
    }

    private static func validate(baseCode: String, orderedCodes: [String]) throws(WatchListError) {
        guard CurrencyCode.isValid(baseCode) else { throw .invalidCode(baseCode) }
        guard !orderedCodes.isEmpty else { throw .empty }
        var seen = Set<String>()
        for code in orderedCodes {
            guard CurrencyCode.isValid(code) else { throw .invalidCode(code) }
            guard code != baseCode else { throw .containsBase(code) }
            guard seen.insert(code).inserted else { throw .duplicate(code) }
        }
    }

    enum CodingKeys: String, CodingKey { case baseCode, orderedCodes }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(baseCode: c.decode(String.self, forKey: .baseCode),
                      orderedCodes: c.decode([String].self, forKey: .orderedCodes))
    }
}
