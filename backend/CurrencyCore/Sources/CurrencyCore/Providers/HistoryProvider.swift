import Foundation

/// A source of daily historical prices (price of 1 quote unit in `base`, one point per UTC day).
public protocol HistoryProvider: Sendable {
    var id: String { get }
    func dailyHistory(quotes: [String], base: String, from: Date, to: Date) async throws -> [HistoryPoint]
}
