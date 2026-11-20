import Foundation

/// Production `HTTPClient`: allowlisted HTTPS only, ephemeral session, 10 s timeout, no redirects,
/// body streamed and cut off past 1 MB.
public final class URLSessionHTTPClient: HTTPClient {
    public static let timeout: TimeInterval = 10

    let session: URLSession
    private let allowlist: RateHostAllowlist
    private let userAgent: String

    public init(allowlist: RateHostAllowlist = .standard,
                userAgent: String = "CurrenSee/\(CurrencyCore.version)") {
        self.allowlist = allowlist
        self.userAgent = userAgent
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = Self.timeout
        config.timeoutIntervalForResource = Self.timeout * 2
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.urlCache = nil
        config.urlCredentialStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        config.waitsForConnectivity = false
        session = URLSession(configuration: config, delegate: RedirectBlocker(), delegateQueue: nil)
    }

    deinit {
        session.invalidateAndCancel()
    }

    func makeRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                 timeoutInterval: Self.timeout)
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    public func get(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        try allowlist.check(url)
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: makeRequest(url))
        } catch let error as URLError {
            throw RateError.transport("URLError \(error.code.rawValue)")
        } catch {
            throw RateError.transport("request failed")
        }
        guard let http = response as? HTTPURLResponse else { throw RateError.invalidResponse("not HTTP") }
        if let finalURL = http.url { try allowlist.check(finalURL) }
        if http.expectedContentLength > Int64(ResponseValidator.maxBodySize) { throw RateError.responseTooLarge }

        var data = Data()
        data.reserveCapacity(max(0, min(Int(http.expectedContentLength), ResponseValidator.maxBodySize)))
        do {
            for try await byte in bytes {
                data.append(byte)
                if data.count > ResponseValidator.maxBodySize { throw RateError.responseTooLarge }
            }
        } catch let error as RateError {
            throw error
        } catch {
            throw RateError.transport("read failed")
        }
        return (data, http)
    }
}

/// Refuses every redirect; the 3xx response is then rejected as a bad status.
private final class RedirectBlocker: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        nil
    }
}
