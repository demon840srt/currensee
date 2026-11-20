import Foundation
import Testing
@testable import CurrencyCore

@Suite("RateHostAllowlist")
struct RateHostAllowlistTests {
    let allowlist = RateHostAllowlist.standard

    @Test(arguments: [
        "https://api.coinbase.com/v2/exchange-rates?currency=ILS",
        "https://api.frankfurter.dev/v2/rates?base=ILS",
        "https://API.COINBASE.COM/v2/x",
        "https://api.coinbase.com:443/v2/x"
    ])
    func allowsListedHTTPSHosts(_ string: String) {
        #expect(allowlist.isAllowed(URL(string: string)!))
    }

    @Test(arguments: [
        "http://api.coinbase.com/v2/exchange-rates",      // not HTTPS
        "https://evil.example.com/v2/rates",              // not listed
        "https://api.coinbase.com.evil.com/v2",           // suffix trick
        "https://evilapi.coinbase.com/v2",                // other subdomain
        "https://user:pw@api.coinbase.com/v2",            // credentials in URL
        "https://api.coinbase.com:8443/v2",               // non-default port
        "ftp://api.frankfurter.dev/v2",
        "file:///etc/passwd"
    ])
    func rejectsEverythingElse(_ string: String) {
        #expect(!allowlist.isAllowed(URL(string: string)!))
    }

    @Test func checkThrowsHostNotAllowed() {
        #expect(throws: RateError.hostNotAllowed("evil.example.com")) {
            try allowlist.check(URL(string: "https://evil.example.com/x")!)
        }
    }
}

@Suite("ResponseValidator")
struct ResponseValidatorTests {
    func response(_ url: String = "https://api.coinbase.com/v2/x", status: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: url)!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    @Test func acceptsNormalResponse() throws {
        try ResponseValidator.check(data: Data("{}".utf8), response: response(), allowlist: .standard)
    }

    @Test func rejectsBodyOverOneMegabyte() {
        let big = Data(count: ResponseValidator.maxBodySize + 1)
        #expect(throws: RateError.responseTooLarge) {
            try ResponseValidator.check(data: big, response: response(), allowlist: .standard)
        }
        let exact = Data(count: ResponseValidator.maxBodySize)
        #expect(throws: Never.self) {
            try ResponseValidator.check(data: exact, response: response(), allowlist: .standard)
        }
    }

    @Test func rejectsFinalURLOnOtherHost() {
        #expect(throws: RateError.hostNotAllowed("evil.example.com")) {
            try ResponseValidator.check(data: Data(), response: response("https://evil.example.com/x"),
                                        allowlist: .standard)
        }
    }

    @Test(arguments: [301, 302, 400, 404, 429, 500, 503])
    func rejectsNon200Status(_ status: Int) {
        #expect(throws: RateError.badStatus(status)) {
            try ResponseValidator.check(data: Data(), response: response(status: status), allowlist: .standard)
        }
    }

    @Test(arguments: ["3.7012", "0.000012", "1e-12", "341234.56", "1000000000000000"])
    func plausibleValues(_ s: String) {
        #expect(ResponseValidator.isPlausible(dec(s)))
    }

    @Test(arguments: ["0", "-1", "-0.0001", "1e-13", "1e16"])
    func implausibleValues(_ s: String) {
        #expect(!ResponseValidator.isPlausible(dec(s)))
    }

    @Test func nanIsImplausible() {
        #expect(!ResponseValidator.isPlausible(Decimal.nan))
    }

    @Test(arguments: ["NaN", "nan", "Infinity", "-inf", "", "abc", "1,5", "0x1F", "1.2.3", " 3.7"])
    func strictParsingRejectsNonNumbers(_ s: String) {
        #expect(ResponseValidator.parseRate(s) == nil)
    }

    @Test func parseRateRejectsZeroAndNegative() {
        #expect(ResponseValidator.parseRate("0") == nil)
        #expect(ResponseValidator.parseRate("-3.2") == nil)
        #expect(ResponseValidator.parseRate("0.299027658010035") == dec("0.299027658010035"))
    }

    @Test func jumpDetection() {
        #expect(!ResponseValidator.isJump(from: dec("100"), to: dec("150")))   // exactly 50% is allowed
        #expect(ResponseValidator.isJump(from: dec("100"), to: dec("150.01")))
        #expect(!ResponseValidator.isJump(from: dec("100"), to: dec("50")))
        #expect(ResponseValidator.isJump(from: dec("100"), to: dec("49.99")))
    }
}

@Suite("JumpGuard")
struct JumpGuardTests {
    @Test func firstValueAndSmallMovesPassThrough() {
        var guardian = JumpGuard()
        #expect(guardian.evaluate("USD", new: dec("3.70"), previous: nil) == dec("3.70"))
        #expect(guardian.evaluate("USD", new: dec("3.75"), previous: dec("3.70")) == dec("3.75"))
    }

    @Test func bigJumpIsHeldThenAcceptedWhenConfirmed() {
        var guardian = JumpGuard()
        #expect(guardian.evaluate("BTC", new: dec("200"), previous: dec("100")) == nil)
        #expect(guardian.isHolding("BTC"))
        #expect(guardian.evaluate("BTC", new: dec("205"), previous: dec("100")) == dec("205"))
        #expect(!guardian.isHolding("BTC"))
    }

    @Test func oneOffSpikeIsDropped() {
        var guardian = JumpGuard()
        #expect(guardian.evaluate("USD", new: dec("37"), previous: dec("3.7")) == nil)
        #expect(guardian.evaluate("USD", new: dec("3.71"), previous: dec("3.7")) == dec("3.71"))
        #expect(!guardian.isHolding("USD"))
    }

    @Test func differentSpikeReplacesPending() {
        var guardian = JumpGuard()
        #expect(guardian.evaluate("USD", new: dec("37"), previous: dec("3.7")) == nil)
        #expect(guardian.evaluate("USD", new: dec("0.5"), previous: dec("3.7")) == nil)
        #expect(guardian.evaluate("USD", new: dec("0.51"), previous: dec("3.7")) == dec("0.51"))
    }

    @Test func resetClearsPending() {
        var guardian = JumpGuard()
        _ = guardian.evaluate("USD", new: dec("37"), previous: dec("3.7"))
        guardian.reset()
        #expect(!guardian.isHolding("USD"))
    }
}

@Suite("URLSessionHTTPClient (no network)")
struct URLSessionHTTPClientTests {
    @Test(arguments: [
        "http://api.coinbase.com/v2/exchange-rates",
        "https://example.com/",
        "https://user:pw@api.frankfurter.dev/v2/rates",
        "https://api.coinbase.com:8080/v2"
    ])
    func rejectsDisallowedURLsBeforeAnyRequest(_ string: String) async {
        let client = URLSessionHTTPClient()
        await #expect(throws: RateError.self) { try await client.get(URL(string: string)!) }
    }

    @Test func requestHasSafeDefaults() {
        let client = URLSessionHTTPClient(userAgent: "CurrencyNotch/9.9")
        let request = client.makeRequest(URL(string: "https://api.coinbase.com/v2/x")!)
        #expect(request.timeoutInterval == 10)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "CurrencyNotch/9.9")
        #expect(request.httpShouldHandleCookies == false)
        #expect(request.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
    }

    @Test func sessionIsEphemeralWithoutCookiesOrCache() {
        let config = URLSessionHTTPClient().session.configuration
        #expect(config.httpCookieStorage == nil || config.httpCookieAcceptPolicy == .never)
        #expect(config.urlCache == nil)
        #expect(config.timeoutIntervalForRequest == 10)
        #expect(config.tlsMinimumSupportedProtocolVersion == .TLSv12)
    }
}
