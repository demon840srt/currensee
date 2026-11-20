import Foundation

/// Minimal HTTP GET abstraction so providers can be tested with recorded fixtures (no network).
/// The URLSession-backed implementation arrives in Phase 3.
public protocol HTTPClient: Sendable {
    func get(_ url: URL) async throws -> (Data, HTTPURLResponse)
}
