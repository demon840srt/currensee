import Foundation

public enum PreferenceChange: Sendable, Equatable {
    case addCurrency(String)
    case removeCurrency(String)
    case moveCurrencies(IndexSet, Int)
    case setBase(String)
    case setRotationInterval(TimeInterval)
    case setRefreshInterval(TimeInterval)
    case setChangeRange(ChangeRange)
    case setTheme(ThemeID)
    case setLanguage(AppLanguage)
    case setLaunchAtLogin(Bool)
    case setPauseEffectsOnBattery(Bool)
    case setPositionLocked(Bool)
    case setPillHidden(Bool)
}

/// What the app must do after a change.
public struct PreferenceEffects: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let reconfigureRates = PreferenceEffects(rawValue: 1 << 0)
    public static let refreshRatesNow = PreferenceEffects(rawValue: 1 << 1)
    public static let rotationCodes = PreferenceEffects(rawValue: 1 << 2)
    public static let rotationInterval = PreferenceEffects(rawValue: 1 << 3)
    public static let summaries = PreferenceEffects(rawValue: 1 << 4)
    public static let loginItem = PreferenceEffects(rawValue: 1 << 5)
    public static let appearance = PreferenceEffects(rawValue: 1 << 6)
    public static let formatting = PreferenceEffects(rawValue: 1 << 7)
    public static let pillVisibility = PreferenceEffects(rawValue: 1 << 8)
    public static let positionLock = PreferenceEffects(rawValue: 1 << 9)
}

public enum PreferenceError: Error, Equatable, Sendable {
    case watchList(WatchListError)
    case unknownCurrency(String)
}

/// Single entry point for every settings change (SPEC F23–F24): validates, saves immediately (no Save
/// button), and reports what needs to react. Use on one actor (it holds a `SettingsStore`).
public struct PreferencesEditor {
    /// Refresh interval choices offered in Settings (seconds); all ≥ the 60 s minimum.
    public static let refreshIntervalChoices: [TimeInterval] = [60, 120, 300, 600, 900, 1800]

    public private(set) var settings: AppSettings
    public private(set) var watchList: WatchList
    private let store: SettingsStore
    private let catalog: CurrencyCatalog

    public init(store: SettingsStore, catalog: CurrencyCatalog = .bundled) {
        self.store = store
        self.catalog = catalog
        settings = store.loadSettings()
        watchList = store.loadWatchList()
    }

    @discardableResult
    public mutating func apply(_ change: PreferenceChange) throws(PreferenceError) -> PreferenceEffects {
        switch change {
        case .addCurrency(let code):
            try requireKnown(code)
            return try editWatchList([.reconfigureRates, .refreshRatesNow, .rotationCodes, .summaries]) { try $0.add(code) }
        case .removeCurrency(let code):
            return try editWatchList([.reconfigureRates, .rotationCodes, .summaries]) { try $0.remove(code) }
        case .moveCurrencies(let source, let destination):
            return try editWatchList([.reconfigureRates, .rotationCodes]) { $0.move(fromOffsets: source, toOffset: destination) }
        case .setBase(let code):
            try requireKnown(code)
            return try editWatchList([.reconfigureRates, .refreshRatesNow, .rotationCodes, .summaries]) { try $0.changeBase(to: code) }
        case .setRotationInterval(let seconds):
            return editSettings(.rotationInterval) { $0.rotationInterval = seconds }
        case .setRefreshInterval(let seconds):
            return editSettings(.reconfigureRates) { $0.refreshInterval = seconds }
        case .setChangeRange(let range):
            return editSettings(.summaries) { $0.changeRange = range }
        case .setTheme(let theme):
            return editSettings(.appearance) { $0.themeID = theme }
        case .setLanguage(let language):
            return editSettings([.formatting, .summaries]) { $0.language = language }
        case .setLaunchAtLogin(let on):
            return editSettings(.loginItem) { $0.launchAtLogin = on }
        case .setPauseEffectsOnBattery(let on):
            return editSettings(.appearance) { $0.pauseEffectsOnBattery = on }
        case .setPositionLocked(let locked):
            return editSettings(.positionLock) { $0.isPositionLocked = locked }
        case .setPillHidden(let hidden):
            return editSettings(.pillVisibility) { $0.isPillHidden = hidden }
        }
    }

    private func requireKnown(_ code: String) throws(PreferenceError) {
        guard catalog.currency(for: code) != nil else { throw .unknownCurrency(code) }
    }

    private mutating func editWatchList(_ effects: PreferenceEffects,
                                        _ edit: (inout WatchList) throws -> Void) throws(PreferenceError) -> PreferenceEffects {
        var next = watchList
        do {
            try edit(&next)
        } catch let error as WatchListError {
            throw .watchList(error)
        } catch {
            throw .watchList(.invalidCode("?"))   // unreachable: WatchList only throws WatchListError
        }
        guard next != watchList else { return [] }
        watchList = next
        store.save(next)
        return effects
    }

    private mutating func editSettings(_ effects: PreferenceEffects, _ edit: (inout AppSettings) -> Void) -> PreferenceEffects {
        var next = settings
        edit(&next)
        guard next != settings else { return [] }
        settings = next
        store.save(next)
        return effects
    }
}
