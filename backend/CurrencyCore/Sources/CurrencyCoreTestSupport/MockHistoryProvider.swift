import CurrencyCore
import Foundation

/// Returns caller-supplied daily points or an error; records each request.
public actor MockHistoryProvider: HistoryProvider {
    public struct Request: Sendable, Equatable {
        public let quotes: [String]
        public let base: String
        public let from: Date
        public let to: Date
    }

    public nonisolated let id: String
    private var result: Result<[HistoryPoint], RateError>
    public private(set) var requests: [Request] = []

    public init(id: String = "mock-history", result: Result<[HistoryPoint], RateError> = .success([])) {
        self.id = id
        self.result = result
    }

    public func setResult(_ result: Result<[HistoryPoint], RateError>) {
        self.result = result
    }

    public func dailyHistory(quotes: [String], base: String, from: Date, to: Date) async throws -> [HistoryPoint] {
        requests.append(Request(quotes: quotes, base: base, from: from, to: to))
        return try result.get().filter { quotes.contains($0.quoteCode) && $0.baseCode == base }
    }
}
