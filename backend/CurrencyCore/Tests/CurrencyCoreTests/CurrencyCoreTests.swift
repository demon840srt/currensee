import Testing
@testable import CurrencyCore

@Suite("CurrencyCore")
struct CurrencyCoreTests {
    @Test func versionIsSet() {
        let parts = CurrencyCore.version.split(separator: ".")
        #expect(parts.count == 3)
        #expect(parts.allSatisfy { Int($0) != nil })
    }
}
