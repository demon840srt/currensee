/// A source of current exchange rates.
public protocol RateProvider: Sendable {
    /// Stable identifier stored in `RateQuote.source` (e.g. "coinbase").
    var id: String { get }
    /// Whether this provider can price crypto currencies.
    var supportsCrypto: Bool { get }
    /// Price of one unit of each available currency, expressed in `base` (already inverted).
    func latestRates(base: String) async throws -> [RateQuote]
}
