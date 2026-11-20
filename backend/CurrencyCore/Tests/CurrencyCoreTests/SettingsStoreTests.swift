import Foundation
import Testing
@testable import CurrencyCore

@Suite("SettingsStore")
struct SettingsStoreTests {
    @Test func emptyStoreReturnsDefaults() {
        withTestDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            #expect(store.loadSettings() == .default)
            #expect(store.loadWatchList() == .default)
            #expect(store.loadAlerts().isEmpty)
            #expect(store.loadPlacements().isEmpty)
        }
    }

    @Test func valuesPersistAcrossInstances() throws {
        try withTestDefaults { defaults in
            var settings = AppSettings.default
            settings.themeID = .ice
            settings.rotationInterval = 12
            let list = try WatchList(baseCode: "USD", orderedCodes: ["EUR", "BTC"])
            let alert = RateAlert(quoteCode: "EUR", baseCode: "USD", direction: .below, threshold: dec("1.05"))
            let placement = WidgetPlacement(screenID: "s1", originX: 10, originY: 20, isLocked: true)

            let writer = SettingsStore(defaults: defaults)
            writer.save(settings)
            writer.save(list)
            writer.save([alert])
            writer.savePlacement(placement)

            let reader = SettingsStore(defaults: defaults)
            #expect(reader.loadSettings() == settings)
            #expect(reader.loadWatchList() == list)
            #expect(reader.loadAlerts() == [alert])
            #expect(reader.placement(forScreen: "s1") == placement)
            #expect(reader.placement(forScreen: "other") == nil)
        }
    }

    @Test func placementsAreStoredPerScreen() {
        withTestDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            store.savePlacement(WidgetPlacement(screenID: "a", originX: 1, originY: 1, isLocked: false))
            store.savePlacement(WidgetPlacement(screenID: "b", originX: 2, originY: 2, isLocked: false))
            store.savePlacement(WidgetPlacement(screenID: "a", originX: 3, originY: 3, isLocked: true))
            let all = store.loadPlacements()
            #expect(all.count == 2)
            #expect(all["a"]?.originX == 3)
            #expect(all["b"]?.originX == 2)
        }
    }

    @Test func unknownSchemaVersionFallsBackToDefaults() {
        withTestDefaults { defaults in
            let future = #"{"version":999,"value":{"rotationInterval":20}}"#
            defaults.set(Data(future.utf8), forKey: SettingsStore.Key.settings.rawValue)
            let olderList = #"{"version":0,"value":{"baseCode":"USD","orderedCodes":["EUR"]}}"#
            defaults.set(Data(olderList.utf8), forKey: SettingsStore.Key.watchList.rawValue)

            let store = SettingsStore(defaults: defaults)
            #expect(store.loadSettings() == .default)
            #expect(store.loadWatchList() == .default)
        }
    }

    @Test func corruptOrWrongTypeDataFallsBackToDefaults() {
        withTestDefaults { defaults in
            defaults.set(Data([0xFF, 0x00, 0x13]), forKey: SettingsStore.Key.settings.rawValue)
            defaults.set("not data", forKey: SettingsStore.Key.watchList.rawValue)
            defaults.set(Data(#"{"version":1,"value":[{"bogus":true}]}"#.utf8),
                         forKey: SettingsStore.Key.alerts.rawValue)
            defaults.set(42, forKey: SettingsStore.Key.placements.rawValue)

            let store = SettingsStore(defaults: defaults)
            #expect(store.loadSettings() == .default)
            #expect(store.loadWatchList() == .default)
            #expect(store.loadAlerts().isEmpty)
            #expect(store.loadPlacements().isEmpty)
        }
    }

    @Test func invalidStoredWatchListFallsBackToDefault() {
        withTestDefaults { defaults in
            let bad = #"{"version":1,"value":{"baseCode":"ILS","orderedCodes":[]}}"#
            defaults.set(Data(bad.utf8), forKey: SettingsStore.Key.watchList.rawValue)
            #expect(SettingsStore(defaults: defaults).loadWatchList() == .default)
        }
    }
}
