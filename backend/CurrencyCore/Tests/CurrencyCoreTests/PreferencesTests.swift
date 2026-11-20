import Foundation
import Testing
@testable import CurrencyCore

@Suite("CatalogSearch")
struct CatalogSearchTests {
    let en = CatalogSearch(locale: Locale(identifier: "en_US"))
    let he = CatalogSearch(locale: Locale(identifier: "he_IL"))

    @Test func exactCodeRanksFirst() {
        #expect(en.search("usd").first?.code == "USD")
        #expect(en.search("BTC").first?.code == "BTC")
    }

    @Test func codePrefixBeforeNameMatches() {
        let codes = en.search("eu").map(\.code)
        #expect(codes.first == "EUR")
    }

    @Test func englishNameMatches() {
        #expect(en.search("swiss").map(\.code).contains("CHF"))
        #expect(he.search("dollar").map(\.code).contains("USD"))   // English name works in any locale
    }

    @Test func localizedNameMatches() {
        let codes = he.search("דולר").map(\.code)
        #expect(codes.contains("USD"))
        #expect(codes.contains("AUD"))
        #expect(he.search("שקל").map(\.code).contains("ILS"))
    }

    @Test func accentAndCaseInsensitive() {
        let es = CatalogSearch(locale: Locale(identifier: "es_ES"))
        #expect(es.search("DOLAR ESTADOUNIDENSE").map(\.code).contains("USD"))
        #expect(en.search("BITCOIN").map(\.code) == ["BTC", "BCH"])
    }

    @Test func findsFiatAndCryptoAndFilters() {
        #expect(en.search("eth").first?.code == "ETH")
        #expect(en.search("eth", kind: .fiat).allSatisfy { $0.kind == .fiat })
        #expect(en.search("eth", kind: .crypto).map(\.code).contains("ETH"))
        #expect(!en.search("usd", kind: .crypto).contains { $0.code == "USD" })
    }

    @Test func excludesAlreadyListedCodes() {
        #expect(!en.search("usd", excluding: ["USD"]).contains { $0.code == "USD" })
    }

    @Test func emptyQueryListsEverythingSortedFiatThenCrypto() {
        let all = en.search("   ")
        #expect(all.count == CurrencyCatalog.bundled.currencies.count)
        let firstCrypto = all.firstIndex { $0.kind == .crypto }!
        #expect(all[..<firstCrypto].allSatisfy { $0.kind == .fiat })
        #expect(en.search("", kind: .crypto).count == CurrencyCatalog.bundled.crypto.count)
    }

    @Test func noMatchIsEmpty() {
        #expect(en.search("zzzzqqq").isEmpty)
    }
}

@Suite("PreferencesEditor")
struct PreferencesEditorTests {
    @Test func startsFromStoredValues() {
        withTestDefaults { defaults in
            let editor = PreferencesEditor(store: SettingsStore(defaults: defaults))
            #expect(editor.settings == .default)
            #expect(editor.watchList == .default)
        }
    }

    @Test func addCurrencyPersistsAndRefreshes() throws {
        try withTestDefaults { defaults in
            var editor = PreferencesEditor(store: SettingsStore(defaults: defaults))
            let effects = try editor.apply(.addCurrency("SOL"))
            #expect(effects == [.reconfigureRates, .refreshRatesNow, .rotationCodes, .summaries])
            #expect(editor.watchList.orderedCodes.last == "SOL")
            #expect(SettingsStore(defaults: defaults).loadWatchList().orderedCodes.last == "SOL")
        }
    }

    @Test func addRejectsDuplicatesUnknownAndBase() {
        withTestDefaults { defaults in
            var editor = PreferencesEditor(store: SettingsStore(defaults: defaults))
            #expect(throws: PreferenceError.watchList(.duplicate("USD"))) { try editor.apply(.addCurrency("USD")) }
            #expect(throws: PreferenceError.unknownCurrency("XYZ")) { try editor.apply(.addCurrency("XYZ")) }
            #expect(throws: PreferenceError.watchList(.containsBase("ILS"))) { try editor.apply(.addCurrency("ILS")) }
        }
    }

    @Test func removeAndRefuseLast() throws {
        try withTestDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            store.save(try WatchList(baseCode: "ILS", orderedCodes: ["USD", "EUR"]))
            var editor = PreferencesEditor(store: store)
            let effects = try editor.apply(.removeCurrency("USD"))
            #expect(effects == [.reconfigureRates, .rotationCodes, .summaries])
            #expect(SettingsStore(defaults: defaults).loadWatchList().orderedCodes == ["EUR"])
            #expect(throws: PreferenceError.watchList(.cannotRemoveLast)) { try editor.apply(.removeCurrency("EUR")) }
        }
    }

    @Test func reorderPersists() throws {
        try withTestDefaults { defaults in
            var editor = PreferencesEditor(store: SettingsStore(defaults: defaults))
            let effects = try editor.apply(.moveCurrencies(IndexSet(integer: 0), 3))   // USD after GBP
            #expect(effects == [.reconfigureRates, .rotationCodes])
            #expect(SettingsStore(defaults: defaults).loadWatchList().orderedCodes.prefix(3) == ["EUR", "GBP", "USD"])
        }
    }

    @Test func baseChangePersistsRemovesNewBaseAndRefreshes() throws {
        try withTestDefaults { defaults in
            var editor = PreferencesEditor(store: SettingsStore(defaults: defaults))
            let effects = try editor.apply(.setBase("USD"))
            #expect(effects == [.reconfigureRates, .refreshRatesNow, .rotationCodes, .summaries])
            let saved = SettingsStore(defaults: defaults).loadWatchList()
            #expect(saved.baseCode == "USD")
            #expect(!saved.orderedCodes.contains("USD"))
            #expect(throws: PreferenceError.unknownCurrency("XYZ")) { try editor.apply(.setBase("XYZ")) }
        }
    }

    @Test func unchangedValueHasNoEffects() throws {
        try withTestDefaults { defaults in
            var editor = PreferencesEditor(store: SettingsStore(defaults: defaults))
            let sameBase = try editor.apply(.setBase("ILS"))
            let sameTheme = try editor.apply(.setTheme(.classicNotch))
            #expect(sameBase.isEmpty)
            #expect(sameTheme.isEmpty)
        }
    }

    @Test(arguments: [(1.0, 3.0), (3.0, 3.0), (17.0, 17.0), (30.0, 30.0), (99.0, 30.0)])
    func rotationIntervalClamps(input: Double, expected: Double) throws {
        try withTestDefaults { defaults in
            var editor = PreferencesEditor(store: SettingsStore(defaults: defaults))
            _ = try editor.apply(.setRotationInterval(input))
            #expect(editor.settings.rotationInterval == expected)
            #expect(SettingsStore(defaults: defaults).loadSettings().rotationInterval == expected)
        }
    }

    @Test(arguments: [(5.0, 60.0), (60.0, 60.0), (600.0, 600.0)])
    func refreshIntervalClamps(input: Double, expected: Double) throws {
        try withTestDefaults { defaults in
            var editor = PreferencesEditor(store: SettingsStore(defaults: defaults))
            _ = try editor.apply(.setRefreshInterval(input))
            #expect(editor.settings.refreshInterval == expected)
        }
    }

    @Test func settingEffects() throws {
        try withTestDefaults { defaults in
            var editor = PreferencesEditor(store: SettingsStore(defaults: defaults))
            let cases: [(PreferenceChange, PreferenceEffects)] = [
                (.setRotationInterval(9), [.rotationInterval]),
                (.setRefreshInterval(300), [.reconfigureRates]),
                (.setChangeRange(.d30), [.summaries]),
                (.setTheme(.fire), [.appearance]),
                (.setLanguage(.ru), [.formatting, .summaries]),
                (.setLaunchAtLogin(false), [.loginItem]),
                (.setPauseEffectsOnBattery(false), [.appearance]),
                (.setPositionLocked(true), [.positionLock]),
                (.setPillHidden(true), [.pillVisibility])
            ]
            for (change, expected) in cases {
                let effects = try editor.apply(change)
                #expect(effects == expected, "\(change)")
            }
            let saved = SettingsStore(defaults: defaults).loadSettings()
            #expect(saved.rotationInterval == 9 && saved.refreshInterval == 300 && saved.changeRange == .d30)
            #expect(saved.themeID == .fire && saved.language == .ru && !saved.launchAtLogin)
            #expect(!saved.pauseEffectsOnBattery && saved.isPositionLocked && saved.isPillHidden)
        }
    }

    @Test func refreshIntervalChoicesAreAllowed() {
        #expect(PreferencesEditor.refreshIntervalChoices == [60, 120, 300, 600, 900, 1800])
        #expect(PreferencesEditor.refreshIntervalChoices.allSatisfy { $0 >= AppSettings.minimumRefreshInterval })
    }

    @Test func oldSettingsWithoutHiddenFlagDecode() throws {
        let s = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"themeID":"ice"}"#.utf8))
        #expect(s.isPillHidden == false)
    }
}

/// In-memory login-item service for tests.
final class FakeLoginItemService: LoginItemService, @unchecked Sendable {
    var status: LoginItemStatus
    var failRegister = false
    private(set) var calls: [String] = []

    init(_ status: LoginItemStatus) { self.status = status }

    func register() throws {
        calls.append("register")
        if failRegister { throw LoginItemError.failed("denied") }
        status = .enabled
    }

    func unregister() throws {
        calls.append("unregister")
        status = .notRegistered
    }
}

@Suite("LoginItem")
struct LoginItemTests {
    @Test(arguments: [
        (LoginItemStatus.enabled, true, false, true),
        (.requiresApproval, true, true, true),
        (.notRegistered, false, false, true),
        (.notFound, false, false, false)
    ])
    func stateReflectsRealStatus(status: LoginItemStatus, isOn: Bool, needsApproval: Bool, isAvailable: Bool) {
        let state = LoginItemState(status: status)
        #expect(state.isOn == isOn)
        #expect(state.needsApproval == needsApproval)
        #expect(state.isAvailable == isAvailable)
    }

    @Test func turningOnAndOffCallsServiceAndReportsNewStatus() throws {
        let service = FakeLoginItemService(.notRegistered)
        #expect(try LoginItemController.set(true, service: service).isOn)
        #expect(!(try LoginItemController.set(false, service: service).isOn))
        #expect(service.calls == ["register", "unregister"])
    }

    @Test func noCallWhenAlreadyInDesiredState() throws {
        let service = FakeLoginItemService(.enabled)
        _ = try LoginItemController.set(true, service: service)
        #expect(service.calls.isEmpty)
    }

    @Test func registerFailureSurfaces() {
        let service = FakeLoginItemService(.notRegistered)
        service.failRegister = true
        #expect(throws: LoginItemError.failed("denied")) { try LoginItemController.set(true, service: service) }
    }

    @Test func autoRegisterOnlyOnFirstReleaseLaunchWhenWanted() {
        #expect(LoginItemController.shouldAutoRegister(alreadyAttempted: false, wantsLaunchAtLogin: true, isReleaseBuild: true))
        #expect(!LoginItemController.shouldAutoRegister(alreadyAttempted: true, wantsLaunchAtLogin: true, isReleaseBuild: true))
        #expect(!LoginItemController.shouldAutoRegister(alreadyAttempted: false, wantsLaunchAtLogin: false, isReleaseBuild: true))
        #expect(!LoginItemController.shouldAutoRegister(alreadyAttempted: false, wantsLaunchAtLogin: true, isReleaseBuild: false))
    }

    @Test func autoRegisterAttemptIsRemembered() {
        withTestDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            #expect(!store.loadDidAttemptLoginItemRegistration())
            store.saveDidAttemptLoginItemRegistration()
            #expect(SettingsStore(defaults: defaults).loadDidAttemptLoginItemRegistration())
        }
    }
}
