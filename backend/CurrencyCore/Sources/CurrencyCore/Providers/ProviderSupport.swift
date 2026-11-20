import Foundation

/// Shared request plumbing for providers.
enum ProviderSupport {
    /// GETs `url` through the allowlist and size checks. Returns the body and status
    /// (non-200 statuses are returned so callers can map provider-specific errors).
    static func get(_ url: URL, client: any HTTPClient, allowlist: RateHostAllowlist) async throws -> (Data, Int) {
        try allowlist.check(url)
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await client.get(url)
        } catch let error as RateError {
            throw error
        } catch {
            throw RateError.transport("request failed")
        }
        if let finalURL = response.url { try allowlist.check(finalURL) }
        guard data.count <= ResponseValidator.maxBodySize else { throw RateError.responseTooLarge }
        return (data, response.statusCode)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data, context: String) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw RateError.invalidResponse(context)
        }
    }

    static func url(_ base: URL, path: String, query: [(String, String)]) throws -> URL {
        guard var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        else { throw RateError.invalidResponse("bad URL") }
        components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        // Keep commas literal (Frankfurter `quotes=USD,EUR`); codes are validated [A-Z0-9].
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "%2C", with: ",")
        guard let url = components.url else { throw RateError.invalidResponse("bad URL") }
        return url
    }

    /// Inverts "units of X per 1 base" into "price of 1 X in base", rejecting absurd results.
    static func invert(_ unitsPerBase: Decimal) -> Decimal? {
        guard ResponseValidator.isPlausible(unitsPerBase) else { return nil }
        let price = Decimal(1) / unitsPerBase
        return ResponseValidator.isPlausible(price) ? price : nil
    }
}

/// UTC calendar-day helpers (history points are stamped at 00:00 UTC).
public enum UTCDay {
    public static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    public static func start(of date: Date) -> Date { calendar.startOfDay(for: date) }

    public static func adding(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: start(of: date))!
    }

    /// "YYYY-MM-DD"
    public static func string(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    public static func parse(_ string: String) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard string.count == 10, parts.count == 3 else { return nil }
        var c = DateComponents()
        (c.year, c.month, c.day) = (parts[0], parts[1], parts[2])
        guard let date = calendar.date(from: c), UTCDay.string(date) == string else { return nil }
        return date
    }

    /// Every day from `from` to `to` inclusive, at most `limit` (the most recent ones).
    static func days(from: Date, to: Date, limit: Int) -> [Date] {
        var days: [Date] = []
        var day = start(of: from)
        let last = start(of: to)
        while day <= last {
            days.append(day)
            day = adding(1, to: day)
        }
        return Array(days.suffix(limit))
    }
}
