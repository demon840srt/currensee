import Foundation

/// Primary source: Coinbase public data API, fiat + crypto, no key.
/// `GET /v2/exchange-rates?currency=BASE` returns string rates as units of X per 1 BASE.
public struct CoinbaseProvider: RateProvider, HistoryProvider {
    public let id = "coinbase"
    public let supportsCrypto = true
    public static let defaultBaseURL = URL(string: "https://api.coinbase.com/v2")!
    /// Upper bound on spot calls per currency per history request.
    public static let maxHistoryDays = 35

    private let client: any HTTPClient
    private let baseURL: URL
    private let allowlist: RateHostAllowlist
    private let now: @Sendable () -> Date

    public init(client: any HTTPClient, baseURL: URL = Self.defaultBaseURL,
                allowlist: RateHostAllowlist = .standard, now: @escaping @Sendable () -> Date = { Date() }) {
        self.client = client
        self.baseURL = baseURL
        self.allowlist = allowlist
        self.now = now
    }

    public func latestRates(base: String) async throws -> [RateQuote] {
        guard CurrencyCode.isValid(base) else { throw RateError.unsupportedBase(base) }
        let url = try ProviderSupport.url(baseURL, path: "exchange-rates", query: [("currency", base)])
        let (data, status) = try await ProviderSupport.get(url, client: client, allowlist: allowlist)
        if status == 400 { throw RateError.unsupportedBase(base) }
        guard status == 200 else { throw RateError.badStatus(status) }

        let body = try ProviderSupport.decode(RatesResponse.self, from: data, context: "coinbase rates")
        guard body.data.currency == base else { throw RateError.invalidResponse("base mismatch") }

        let fetchedAt = now()
        let quotes = body.data.rates.compactMap { code, raw -> RateQuote? in
            guard code != base, CurrencyCode.isValid(code),
                  let unitsPerBase = ResponseValidator.parseRate(raw),
                  let price = ProviderSupport.invert(unitsPerBase)
            else { return nil }
            return RateQuote(quoteCode: code, baseCode: base, value: price, fetchedAt: fetchedAt, source: id)
        }
        guard !quotes.isEmpty else { throw RateError.noData }
        return quotes.sorted { $0.quoteCode < $1.quoteCode }
    }

    /// One spot-price call per currency per day (`/v2/prices/CODE-BASE/spot?date=`). Days the API
    /// doesn't know (404) are skipped; transport errors abort.
    public func dailyHistory(quotes: [String], base: String, from: Date, to: Date) async throws -> [HistoryPoint] {
        guard CurrencyCode.isValid(base) else { throw RateError.unsupportedBase(base) }
        var points: [HistoryPoint] = []
        for code in quotes where CurrencyCode.isValid(code) && code != base {
            for day in UTCDay.days(from: from, to: to, limit: Self.maxHistoryDays) {
                let url = try ProviderSupport.url(baseURL, path: "prices/\(code)-\(base)/spot",
                                                  query: [("date", UTCDay.string(day))])
                let (data, status) = try await ProviderSupport.get(url, client: client, allowlist: allowlist)
                guard status == 200,
                      let body = try? JSONDecoder().decode(SpotResponse.self, from: data),
                      body.data.base == code, body.data.currency == base,
                      let price = ResponseValidator.parseRate(body.data.amount)
                else { continue }
                points.append(HistoryPoint(quoteCode: code, baseCode: base, timestamp: day, value: price))
            }
        }
        return points
    }

    private struct RatesResponse: Decodable {
        struct Payload: Decodable { let currency: String; let rates: [String: String] }
        let data: Payload
    }

    private struct SpotResponse: Decodable {
        struct Payload: Decodable { let amount: String; let base: String; let currency: String }
        let data: Payload
    }
}
