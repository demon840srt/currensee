import Foundation
import Testing
@testable import CurrencyCore

@Suite("AppSettings and defaults (SPEC §4)")
struct AppSettingsTests {
    @Test func defaultsMatchSpec() {
        let s = AppSettings.default
        #expect(s.rotationInterval == 5)
        #expect(s.refreshInterval == 120)
        #expect(s.changeRange == .h24)
        #expect(s.themeID == .classicNotch)
        #expect(s.language == .he)
        #expect(s.launchAtLogin == true)
        #expect(s.pauseEffectsOnBattery == true)
    }

    @Test func defaultWatchListMatchesSpec() {
        let w = WatchList.default
        #expect(w.baseCode == "ILS")
        #expect(w.orderedCodes == ["USD", "EUR", "GBP", "JPY", "CHF", "CNY", "BTC", "ETH"])
    }

    @Test(arguments: [(1.0, 3.0), (3.0, 3.0), (7.5, 7.5), (30.0, 30.0), (90.0, 30.0), (-4.0, 3.0)])
    func rotationIntervalIsClamped(input: Double, expected: Double) {
        var s = AppSettings.default
        s.rotationInterval = input
        #expect(s.rotationInterval == expected)
    }

    @Test(arguments: [(10.0, 60.0), (60.0, 60.0), (300.0, 300.0), (-1.0, 60.0)])
    func refreshIntervalHasMinimum(input: Double, expected: Double) {
        var s = AppSettings.default
        s.refreshInterval = input
        #expect(s.refreshInterval == expected)
    }

    @Test func nonFiniteIntervalsFallBackToDefaults() {
        var s = AppSettings.default
        s.rotationInterval = .nan
        s.refreshInterval = .infinity
        #expect(s.rotationInterval == 5)
        #expect(s.refreshInterval == 120)
    }

    @Test func decodingClampsOutOfRangeValues() throws {
        let json = #"{"rotationInterval":1,"refreshInterval":5,"changeRange":"7d","themeID":"fire","language":"en","launchAtLogin":false,"pauseEffectsOnBattery":false}"#
        let s = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        #expect(s.rotationInterval == 3)
        #expect(s.refreshInterval == 60)
        #expect(s.themeID == .fire)
        #expect(s.launchAtLogin == false)
    }

    @Test func decodingFallsBackPerFieldForUnknownOrMissingValues() throws {
        let json = #"{"rotationInterval":10,"themeID":"neon","language":"klingon"}"#
        let s = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        #expect(s.rotationInterval == 10)
        #expect(s.themeID == AppSettings.default.themeID)
        #expect(s.language == AppSettings.default.language)
        #expect(s.refreshInterval == AppSettings.default.refreshInterval)
    }
}
