import Foundation
import CurrencyCore

/// `HTTPClient` driven by a handler that returns `(body, statusCode)` or throws. Records requested URLs.
public actor MockHTTPClient: HTTPClient {
    public typealias Handler = @Sendable (URL) throws -> (Data, Int)

    private let handler: Handler
    public private(set) var requestedURLs: [URL] = []

    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    public func get(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        requestedURLs.append(url)
        let (data, status) = try handler(url)
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                             headerFields: ["Content-Type": "application/json"]) else {
            throw RateError.invalidResponse("could not build response")
        }
        return (data, response)
    }

    /// Loads a recorded JSON fixture from a test bundle.
    public static func fixture(_ name: String, in bundle: Bundle) throws -> Data {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw RateError.invalidResponse("missing fixture \(name)")
        }
        return try Data(contentsOf: url)
    }
}
