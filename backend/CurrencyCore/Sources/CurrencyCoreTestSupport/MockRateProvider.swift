import Foundation
import CurrencyCore

/// Scripted `RateProvider` for tests. Returns results in order, then repeats the last one.
public actor MockRateProvider: RateProvider {
    public nonisolated let id: String
    public nonisolated let supportsCrypto: Bool
    private var script: [Result<[RateQuote], RateError>]
    private var nextIndex = 0
    public private(set) var requestedBases: [String] = []

    public init(id: String = "mock", supportsCrypto: Bool = true, script: [Result<[RateQuote], RateError>]) {
        self.id = id
        self.supportsCrypto = supportsCrypto
        self.script = script
    }

    public func setScript(_ script: [Result<[RateQuote], RateError>]) {
        self.script = script
        nextIndex = 0
    }

    public func latestRates(base: String) async throws -> [RateQuote] {
        requestedBases.append(base)
        guard !script.isEmpty else { throw RateError.noData }
        let result = script[min(nextIndex, script.count - 1)]
        nextIndex += 1
        return try result.get()
    }

    /// Builds quotes sorted by code from a `code → price in base` table.
    public static func quotes(base: String, _ prices: [String: Decimal], at date: Date,
                              source: String = "mock") -> [RateQuote] {
        prices.keys.sorted().map {
            RateQuote(quoteCode: $0, baseCode: base, value: prices[$0]!, fetchedAt: date, source: source)
        }
    }
}
