import Foundation
@testable import CurrencyCore

/// Fresh, isolated UserDefaults suite; removed after `body` runs.
func withTestDefaults<R>(_ body: (UserDefaults) throws -> R) rethrows -> R {
    let name = "CurrencyCoreTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    return try body(defaults)
}

/// Fresh temporary directory; removed after `body` runs.
func withTempDirectory<R>(_ body: (URL) async throws -> R) async rethrows -> R {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CurrencyCoreTests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: url) }
    return try await body(url)
}

func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
    try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
}

func dec(_ string: String) -> Decimal {
    Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))!
}

enum Fixture {
    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw RateError.invalidResponse("missing fixture \(name)")
        }
        return try Data(contentsOf: url)
    }
}

/// Midnight UTC of the given calendar day.
func utcDay(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
    var c = DateComponents()
    (c.year, c.month, c.day, c.hour) = (y, m, d, hour)
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal.date(from: c)!
}
