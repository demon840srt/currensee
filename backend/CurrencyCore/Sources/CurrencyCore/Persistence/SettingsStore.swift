import Foundation

/// UserDefaults-backed storage for settings, watch list, alerts and per-screen placements.
/// Anything unreadable, invalid or from another schema version loads as the default; it never throws.
/// Not `Sendable` (UserDefaults isn't in this SDK): create and use it on one actor, normally the main actor.
public struct SettingsStore {
    public static let schemaVersion = 1

    public enum Key: String, CaseIterable, Sendable {
        case settings = "settings"
        case watchList = "watchList"
        case alerts = "alerts"
        case placements = "placements"
    }

    private let defaults: UserDefaults

    /// The app passes `.standard` (its sandboxed `com.afik.CurrencyNotch` domain); tests pass a private suite.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadSettings() -> AppSettings { load(AppSettings.self, .settings) ?? .default }
    public func save(_ settings: AppSettings) { store(settings, .settings) }

    public func loadWatchList() -> WatchList { load(WatchList.self, .watchList) ?? .default }
    public func save(_ watchList: WatchList) { store(watchList, .watchList) }

    public func loadAlerts() -> [RateAlert] { load([RateAlert].self, .alerts) ?? [] }
    public func save(_ alerts: [RateAlert]) { store(alerts, .alerts) }

    /// Placements keyed by screen ID.
    public func loadPlacements() -> [String: WidgetPlacement] {
        load([String: WidgetPlacement].self, .placements) ?? [:]
    }

    public func placement(forScreen screenID: String) -> WidgetPlacement? {
        loadPlacements()[screenID]
    }

    public func savePlacement(_ placement: WidgetPlacement) {
        var all = loadPlacements()
        all[placement.screenID] = placement
        store(all, .placements)
    }

    // MARK: - Private

    private func load<T: Codable>(_ type: T.Type, _ key: Key) -> T? {
        guard let data = defaults.data(forKey: key.rawValue),
              let probe = try? JSONDecoder().decode(VersionProbe.self, from: data),
              probe.version == Self.schemaVersion,
              let envelope = try? JSONDecoder().decode(Versioned<T>.self, from: data)
        else { return nil }
        return envelope.value
    }

    private func store<T: Codable>(_ value: T, _ key: Key) {
        // Encoding our own value types cannot fail; if it ever did, keep the previous value.
        guard let data = try? JSONEncoder().encode(Versioned(version: Self.schemaVersion, value: value)) else {
            assertionFailure("Failed to encode \(key.rawValue)")
            return
        }
        defaults.set(data, forKey: key.rawValue)
    }
}
