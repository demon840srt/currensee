import Foundation

/// Fallback + fiat history: Frankfurter v2, no key. Responses are flat arrays of
/// `{"date","base","quote","rate"}` with `rate` as a JSON number = units of quote per 1 base.
/// Crypto rows are dropped: the fallback serves fiat only (SPEC F17, ADR-0013).
public struct FrankfurterProvider: RateProvider, HistoryProvider {
    public let id = "frankfurter"
    public let supportsCrypto = false
    public static let defaultBaseURL = URL(string: "https://api.frankfurter.dev/v2")!

    private let client: any HTTPClient
    private let baseURL: URL
    private let allowlist: RateHostAllowlist
    private let catalog: CurrencyCatalog
    private let now: @Sendable () -> Date

    public init(client: any HTTPClient, baseURL: URL = Self.defaultBaseURL,
                allowlist: RateHostAllowlist = .standard, catalog: CurrencyCatalog = .bundled,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.client = client
        self.baseURL = baseURL
        self.allowlist = allowlist
        self.catalog = catalog
        self.now = now
    }

    public func latestRates(base: String) async throws -> [RateQuote] {
        let rows = try await fetchRows(base: base, query: [("base", base)])
        let fetchedAt = now()
        var latest: [String: RateQuote] = [:]
        for row in rows {
            guard let price = ProviderSupport.invert(row.rate) else { continue }
            latest[row.quote] = RateQuote(quoteCode: row.quote, baseCode: base, value: price,
                                          fetchedAt: fetchedAt, source: id)
        }
        guard !latest.isEmpty else { throw RateError.noData }
        return latest.values.sorted { $0.quoteCode < $1.quoteCode }
    }

    public func dailyHistory(quotes: [String], base: String, from: Date, to: Date) async throws -> [HistoryPoint] {
        let wanted = quotes.filter { CurrencyCode.isValid($0) && $0 != base && isFiat($0) }
        guard !wanted.isEmpty else { return [] }
        let rows = try await fetchRows(base: base, query: [
            ("from", UTCDay.string(from)), ("to", UTCDay.string(to)),
            ("base", base), ("quotes", wanted.joined(separator: ","))
        ])
        return rows.compactMap { row in
            guard wanted.contains(row.quote), let day = UTCDay.parse(row.date),
                  let price = ProviderSupport.invert(row.rate) else { return nil }
            return HistoryPoint(quoteCode: row.quote, baseCode: base, timestamp: day, value: price)
        }
        .sorted { ($0.quoteCode, $0.timestamp) < ($1.quoteCode, $1.timestamp) }
    }

    /// Valid fiat rows for `base`; malformed rows are skipped individually.
    private func fetchRows(base: String, query: [(String, String)]) async throws -> [Row] {
        guard CurrencyCode.isValid(base) else { throw RateError.unsupportedBase(base) }
        let url = try ProviderSupport.url(baseURL, path: "rates", query: query)
        let (data, status) = try await ProviderSupport.get(url, client: client, allowlist: allowlist)
        if status == 404 || status == 422 { throw RateError.unsupportedBase(base) }
        guard status == 200 else { throw RateError.badStatus(status) }
        let rows = try ProviderSupport.decode([Lossy<Row>].self, from: data, context: "frankfurter rates")
        return rows.compactMap(\.value).filter { $0.base == base && $0.quote != base && isFiat($0.quote) }
    }

    private func isFiat(_ code: String) -> Bool {
        catalog.currency(for: code)?.kind == .fiat
    }

    private struct Row: Decodable {
        let date: String
        let base: String
        let quote: String
        let rate: Decimal
    }
}

/// Decodes an element if possible, otherwise yields nil instead of failing the whole array.
struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: any Decoder) throws {
        value = try? T(from: decoder)
    }
}
