import Foundation
import Testing
@testable import CurrencyCore

@Suite("AlertEvaluator")
struct AlertEvaluatorTests {
    let launch = Date(timeIntervalSince1970: 1_795_000_000)
    var now: Date { launch.addingTimeInterval(600) }
    let list = try! WatchList(baseCode: "ILS", orderedCodes: ["USD", "EUR", "BTC"])

    func quote(_ code: String, _ value: String, base: String = "ILS", fetchedAt: Date? = nil) -> [String: RateQuote] {
        [code: RateQuote(quoteCode: code, baseCode: base, value: dec(value), fetchedAt: fetchedAt ?? now, source: "m")]
    }

    func alert(_ direction: AlertDirection, _ threshold: String, code: String = "USD", base: String = "ILS",
               armed: Bool = true) -> RateAlert {
        RateAlert(quoteCode: code, baseCode: base, direction: direction, threshold: dec(threshold), isArmed: armed)
    }

    func evaluate(_ alerts: [RateAlert], _ quotes: [String: RateQuote], watchList: WatchList? = nil) -> AlertEvaluation {
        AlertEvaluator.evaluate(alerts: alerts, quotes: quotes, watchList: watchList ?? list, freshSince: launch, now: now)
    }

    @Test func aboveFiresAndDisarms() {
        let result = evaluate([alert(.above, "3.80")], quote("USD", "3.81"))
        #expect(result.fired.count == 1)
        #expect(result.alerts[0].isArmed == false)
        #expect(result.alerts[0].lastTriggeredAt == now)
    }

    @Test func belowFiresAndDisarms() {
        let result = evaluate([alert(.below, "3.30")], quote("USD", "3.29"))
        #expect(result.fired.map(\.id) == result.alerts.map(\.id))
        #expect(!result.alerts[0].isArmed)
    }

    @Test func notCrossedDoesNothing() {
        let above = evaluate([alert(.above, "3.80")], quote("USD", "3.79"))
        let below = evaluate([alert(.below, "3.30")], quote("USD", "3.31"))
        #expect(above.fired.isEmpty && above.alerts[0].isArmed)
        #expect(below.fired.isEmpty && below.alerts[0].isArmed)
    }

    @Test func exactThresholdNeverFiresButRearms() {
        let armed = evaluate([alert(.above, "3.80")], quote("USD", "3.80"))
        #expect(armed.fired.isEmpty && armed.alerts[0].isArmed)
        let disarmedAbove = evaluate([alert(.above, "3.80", armed: false)], quote("USD", "3.80"))
        #expect(disarmedAbove.alerts[0].isArmed)
        let disarmedBelow = evaluate([alert(.below, "3.30", armed: false)], quote("USD", "3.30"))
        #expect(disarmedBelow.alerts[0].isArmed)
    }

    @Test func firesOnceWhileStayingPastThreshold() {
        var alerts = [alert(.above, "3.80")]
        var fired = 0
        for value in ["3.81", "3.85", "3.90", "3.82"] {
            let result = evaluate(alerts, quote("USD", value))
            fired += result.fired.count
            alerts = result.alerts
        }
        #expect(fired == 1)
    }

    @Test func rearmsOnCrossBackThenFiresAgain() {
        var alerts = [alert(.above, "3.80")]
        var fired: [Int] = []
        for value in ["3.81", "3.75", "3.82"] {
            let result = evaluate(alerts, quote("USD", value))
            fired.append(result.fired.count)
            alerts = result.alerts
        }
        #expect(fired == [1, 0, 1])
    }

    @Test func missingQuoteLeavesAlertUnchanged() {
        let original = [alert(.above, "3.80")]
        let result = evaluate(original, quote("EUR", "4.0"))
        #expect(result.alerts == original && result.fired.isEmpty)
    }

    @Test func cachedOrHeldQuotesOlderThanFreshSinceAreIgnored() {
        let old = quote("USD", "3.90", fetchedAt: launch.addingTimeInterval(-3600))
        let result = evaluate([alert(.above, "3.80")], old)
        #expect(result.fired.isEmpty && result.alerts[0].isArmed)
    }

    @Test func quoteInAnotherBaseIsIgnored() {
        let result = evaluate([alert(.above, "3.80")], quote("USD", "3.90", base: "EUR"))
        #expect(result.fired.isEmpty)
    }

    @Test func multipleAlertsEvaluateIndependently() {
        let alerts = [alert(.above, "3.80"), alert(.below, "3.90"), alert(.above, "100000", code: "BTC")]
        var quotes = quote("USD", "3.85")
        quotes.merge(quote("BTC", "99000")) { $1 }
        let result = evaluate(alerts, quotes)
        #expect(result.fired.map(\.quoteCode) == ["USD", "USD"])
        #expect(result.alerts[2].isArmed)
    }

    // MARK: Base change / watch list

    @Test func alertsFromAnotherBaseAreInactiveAndNeverFire() throws {
        var newList = list
        try newList.changeBase(to: "USD")
        let eurAlert = alert(.above, "4.00", code: "EUR")
        #expect(AlertEvaluator.activity(of: eurAlert, watchList: newList) == .wrongBase("ILS"))
        let quotes = quote("EUR", "1.10", base: "USD")
        let result = evaluate([eurAlert], quotes, watchList: newList)
        #expect(result.fired.isEmpty && result.alerts == [eurAlert])
    }

    @Test func switchingBackReactivates() throws {
        var list2 = list
        try list2.changeBase(to: "USD")
        try list2.changeBase(to: "ILS")
        try list2.add("USD")
        #expect(AlertEvaluator.activity(of: alert(.above, "3.80"), watchList: list2) == .active)
    }

    @Test func currencyRemovedFromWatchListIsInactive() throws {
        let noUSD = try WatchList(baseCode: "ILS", orderedCodes: ["EUR"])
        #expect(AlertEvaluator.activity(of: alert(.above, "3.80"), watchList: noUSD) == .notWatched("USD"))
        let result = evaluate([alert(.above, "3.80")], quote("USD", "3.90"), watchList: noUSD)
        #expect(result.fired.isEmpty)
    }

    // MARK: Initial state

    @Test func newAlertAlreadyPastThresholdStartsDisarmed() {
        #expect(AlertEvaluator.initialArmState(direction: .above, threshold: dec("3.30"), current: dec("3.34")) == false)
        #expect(AlertEvaluator.initialArmState(direction: .above, threshold: dec("3.80"), current: dec("3.34")) == true)
        #expect(AlertEvaluator.initialArmState(direction: .below, threshold: dec("3.30"), current: dec("3.20")) == false)
        #expect(AlertEvaluator.initialArmState(direction: .below, threshold: dec("3.30"), current: nil) == true)
    }

    @Test func messagePartsUsePrecisionRuleAndBaseSymbol() {
        let formatter = RateFormatter(locale: Locale(identifier: "en_US"))
        let usd = AlertMessage.make(for: alert(.above, "3.8"), formatter: formatter)
        #expect(usd == AlertMessage(code: "USD", direction: .above, threshold: "3.8000 ₪"))
        let btc = AlertMessage.make(for: alert(.below, "300000", code: "BTC"), formatter: formatter)
        #expect(btc.threshold == "300,000.00 ₪")
    }
}

@Suite("PreferencesEditor alerts")
struct AlertPreferencesTests {
    @Test func addAlertPersistsWithBaseAndArmState() throws {
        try withTestDefaults { defaults in
            var editor = PreferencesEditor(store: SettingsStore(defaults: defaults))
            let effects = try editor.apply(.addAlert(quoteCode: "USD", direction: .above, threshold: dec("3.80"),
                                                     current: dec("3.34")))
            #expect(effects == [.alerts, .alertCreated])
            let saved = SettingsStore(defaults: defaults).loadAlerts()
            #expect(saved.count == 1)
            #expect(saved[0].baseCode == "ILS" && saved[0].isArmed && saved[0].quoteCode == "USD")
        }
    }

    @Test func addAlertAlreadyPastThresholdStartsDisarmed() throws {
        try withTestDefaults { defaults in
            var editor = PreferencesEditor(store: SettingsStore(defaults: defaults))
            try editor.apply(.addAlert(quoteCode: "USD", direction: .above, threshold: dec("3.30"), current: dec("3.34")))
            #expect(editor.alerts[0].isArmed == false)
            #expect(editor.alerts[0].lastTriggeredAt == nil)
        }
    }

    @Test func addAlertValidates() {
        withTestDefaults { defaults in
            var editor = PreferencesEditor(store: SettingsStore(defaults: defaults))
            for bad in ["0", "-1", "1e20"] {
                #expect(throws: PreferenceError.invalidThreshold) {
                    try editor.apply(.addAlert(quoteCode: "USD", direction: .above, threshold: dec(bad), current: nil))
                }
            }
            #expect(throws: PreferenceError.invalidThreshold) {
                try editor.apply(.addAlert(quoteCode: "USD", direction: .above, threshold: .nan, current: nil))
            }
            #expect(throws: PreferenceError.notWatched("SOL")) {
                try editor.apply(.addAlert(quoteCode: "SOL", direction: .above, threshold: dec("500"), current: nil))
            }
        }
    }

    @Test func updateAndDelete() throws {
        try withTestDefaults { defaults in
            var editor = PreferencesEditor(store: SettingsStore(defaults: defaults))
            try editor.apply(.addAlert(quoteCode: "USD", direction: .above, threshold: dec("3.80"), current: dec("3.34")))
            let id = editor.alerts[0].id
            let effects = try editor.apply(.updateAlert(id: id, quoteCode: "EUR", direction: .below,
                                                        threshold: dec("3.50"), current: dec("3.66")))
            #expect(effects == [.alerts])
            let updated = SettingsStore(defaults: defaults).loadAlerts()[0]
            #expect(updated.id == id && updated.quoteCode == "EUR" && updated.direction == .below)
            #expect(updated.threshold == dec("3.50") && updated.isArmed)
            try editor.apply(.deleteAlert(id: id))
            #expect(SettingsStore(defaults: defaults).loadAlerts().isEmpty)
            #expect(throws: PreferenceError.alertNotFound) { try editor.apply(.deleteAlert(id: id)) }
        }
    }

    @Test func evaluationStatesArePersisted() throws {
        try withTestDefaults { defaults in
            var editor = PreferencesEditor(store: SettingsStore(defaults: defaults))
            try editor.apply(.addAlert(quoteCode: "USD", direction: .above, threshold: dec("3.80"), current: dec("3.34")))
            var fired = editor.alerts
            fired[0].isArmed = false
            fired[0].lastTriggeredAt = Date(timeIntervalSince1970: 1_795_000_000)
            editor.saveEvaluatedAlerts(fired)
            #expect(SettingsStore(defaults: defaults).loadAlerts() == fired)
        }
    }
}
