import Foundation

/// The only hosts the app may contact. HTTPS on the default port, no credentials in the URL.
public struct RateHostAllowlist: Sendable {
    public static let standard = RateHostAllowlist(hosts: ["api.coinbase.com", "api.frankfurter.dev"])

    public let hosts: Set<String>

    public init(hosts: Set<String>) {
        self.hosts = Set(hosts.map { $0.lowercased() })
    }

    public func isAllowed(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host()?.lowercased(), hosts.contains(host),
              url.user() == nil, url.password() == nil
        else { return false }
        return url.port == nil || url.port == 443
    }

    public func check(_ url: URL) throws(RateError) {
        guard isAllowed(url) else { throw .hostNotAllowed(url.host() ?? url.absoluteString) }
    }
}
