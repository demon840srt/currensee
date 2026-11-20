import CurrencyCore
import Foundation
import Observation

/// The only bridge between CurrencyCore and the UI (ARCHITECTURE.md). Main-actor state for SwiftUI/AppKit.
@MainActor
@Observable
final class AppModel {
    private(set) var snapshot: RateSnapshot = .empty()
    private(set) var settings: AppSettings
    private(set) var watchList: WatchList
    /// Code currently shown in the collapsed pill (driven by `RotationEngine`).
    private(set) var currentCode: String?
    private(set) var interaction = PillInteraction()
    private(set) var summaries: [String: ChangeSummary] = [:]
    private(set) var loginItemState: LoginItemState
    private(set) var lastError: String?
    /// System conditions that pause theme effects (SPEC F26).
    private(set) var effectsEnvironment: EffectsEnvironment
    let catalog = CurrencyCatalog.bundled

    // Window layout, set by `PillPanelController` so the SwiftUI content lines up with the panel.
    var slotSize = PillLayout.collapsedSize
    var dropdownDirection: PillLayout.DropdownDirection = .below
    var listHeight: CGFloat = 0
    /// Called when the pill changes between collapsed / expanded / dropdown.
    @ObservationIgnored var onModeChange: ((PillMode) -> Void)?
    /// Called when Show/Hide pill changes.
    @ObservationIgnored var onPillHiddenChange: ((Bool) -> Void)?

    @ObservationIgnored let store: SettingsStore
    @ObservationIgnored private var editor: PreferencesEditor
    @ObservationIgnored private let loginItems: any LoginItemService
    @ObservationIgnored private let rateService: RateService
    @ObservationIgnored private let history: HistoryStore
    @ObservationIgnored private let rotation: RotationEngine
    @ObservationIgnored private let hoverDelay = HoverDelay()
    @ObservationIgnored private let connectivity = NetworkConnectivityMonitor()
    @ObservationIgnored private let effectsMonitor = EffectsMonitor()
    /// Debug builds only: `CURRENCY_NOTCH_THEME=ice` shows a theme without changing saved settings
    /// (used for performance measurements).
    @ObservationIgnored private let debugThemeOverride: ThemeID?
    /// Debug builds only: `CURRENCY_NOTCH_IGNORE_BATTERY=1` runs effects on battery (for measurements).
    @ObservationIgnored private let debugIgnoreBattery: Bool
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []

    init(store: SettingsStore = SettingsStore(), loginItems: any LoginItemService = MainAppLoginItem()) {
        self.store = store
        self.loginItems = loginItems
        let editor = PreferencesEditor(store: store)
        self.editor = editor
        settings = editor.settings
        watchList = editor.watchList
        loginItemState = LoginItemState(status: loginItems.status)
        effectsEnvironment = effectsMonitor.environment
        #if DEBUG
        debugThemeOverride = ProcessInfo.processInfo.environment["CURRENCY_NOTCH_THEME"].flatMap(ThemeID.init(rawValue:))
        debugIgnoreBattery = ProcessInfo.processInfo.environment["CURRENCY_NOTCH_IGNORE_BATTERY"] == "1"
        #else
        debugThemeOverride = nil
        debugIgnoreBattery = false
        #endif

        let client = URLSessionHTTPClient()
        let coinbase = CoinbaseProvider(client: client)
        let frankfurter = FrankfurterProvider(client: client)
        let cache = (try? DiskCache.defaultDirectory()).map { DiskCache(directory: $0) }
        history = HistoryStore(cache: cache)
        rateService = RateService(primary: coinbase, fallback: frankfurter, cache: cache, history: history,
                                  fiatHistory: frankfurter, cryptoHistory: coinbase)
        rotation = RotationEngine(codes: editor.watchList.orderedCodes, interval: editor.settings.rotationInterval)
        currentCode = editor.watchList.orderedCodes.first
    }

    func start() {
        let service = rateService
        let history = history
        let rotation = rotation
        let hoverDelay = hoverDelay
        let settings = settings
        let watchList = watchList

        tasks.append(Task { [weak self] in
            for await snapshot in service.snapshots {
                self?.snapshot = snapshot
                if self?.mode != .collapsed { self?.refreshSummaries() }
            }
        })
        tasks.append(Task { [weak self] in
            for await code in rotation.currentCodes {
                self?.currentCode = code
            }
        })
        tasks.append(Task { [weak self] in
            for await hovering in hoverDelay.events {
                self?.send(hovering ? .hoverBegan : .hoverEnded)
            }
        })
        tasks.append(Task { await rotation.start() })
        tasks.append(Task {
            await history.load()
            await service.configure(baseCode: watchList.baseCode, codes: watchList.orderedCodes,
                                    refreshInterval: settings.refreshInterval)
            await service.loadCache()
            await service.start()
        })
        // Recompute staleness periodically so "stale" appears even when nothing new arrives.
        tasks.append(Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await service.republish()
            }
        })
        connectivity.start { online in
            Task { await service.setOnline(online) }
        }
        effectsMonitor.onChange = { [weak self] environment in self?.effectsEnvironment = environment }
        effectsMonitor.start()
    }

    // MARK: - Themes (SPEC §5.7)

    func theme(for appearance: ThemeAppearance) -> ThemeSpec {
        ThemeRegistry.spec(debugThemeOverride ?? settings.themeID, appearance: appearance)
    }

    func effectsRunning(for theme: ThemeSpec) -> Bool {
        EffectsPolicy.shouldRun(theme: theme, pauseOnBattery: settings.pauseEffectsOnBattery && !debugIgnoreBattery,
                                environment: effectsEnvironment)
    }

    /// The pill window is fully covered or hidden: effects pause.
    func setPillOccluded(_ occluded: Bool) {
        effectsMonitor.setOccluded(occluded)
    }

    func refreshNow() {
        let service = rateService
        Task { await service.triggerRefresh() }
    }

    // MARK: - Preferences (SPEC F23–F24: every change applies instantly)

    /// Applies a settings change; returns false (and sets `lastError`) if it was rejected.
    @discardableResult
    func apply(_ change: PreferenceChange) -> Bool {
        let effects: PreferenceEffects
        do {
            effects = try editor.apply(change)
        } catch {
            lastError = String(describing: error)
            return false
        }
        lastError = nil
        settings = editor.settings
        watchList = editor.watchList
        react(to: effects)
        return true
    }

    private func react(to effects: PreferenceEffects) {
        let service = rateService
        let rotation = rotation
        let list = watchList
        let settings = settings
        if effects.contains(.reconfigureRates) {
            let refresh = effects.contains(.refreshRatesNow)
            Task {
                await service.configure(baseCode: list.baseCode, codes: list.orderedCodes,
                                        refreshInterval: settings.refreshInterval)
                if refresh { await service.triggerRefresh() }
            }
        }
        if effects.contains(.rotationCodes) { Task { await rotation.setCodes(list.orderedCodes) } }
        if effects.contains(.rotationInterval) { Task { await rotation.setInterval(settings.rotationInterval) } }
        if effects.contains(.summaries) { refreshSummaries() }
        if effects.contains(.loginItem) { updateLoginItem(settings.launchAtLogin) }
        if effects.contains(.pillVisibility) { onPillHiddenChange?(settings.isPillHidden) }
    }

    var isPositionLocked: Bool { settings.isPositionLocked }

    // MARK: - Launch at login (SPEC F32)

    func reloadLoginItemState() {
        loginItemState = LoginItemState(status: loginItems.status)
    }

    private func updateLoginItem(_ on: Bool) {
        do {
            loginItemState = try LoginItemController.set(on, service: loginItems)
        } catch {
            lastError = String(describing: error)
            reloadLoginItemState()
        }
    }

    /// SPEC §4 default is "on": register once, on the first Release launch (ADR-0018).
    func autoRegisterLoginItemIfNeeded(isReleaseBuild: Bool) {
        guard LoginItemController.shouldAutoRegister(alreadyAttempted: store.loadDidAttemptLoginItemRegistration(),
                                                     wantsLaunchAtLogin: settings.launchAtLogin,
                                                     isReleaseBuild: isReleaseBuild) else { return }
        store.saveDidAttemptLoginItemRegistration()
        updateLoginItem(true)
    }

    // MARK: - Interaction (SPEC F9, F11–F14)

    var mode: PillMode { interaction.mode }

    func pointerEntered() {
        let hoverDelay = hoverDelay
        Task { await hoverDelay.mouseEntered() }
    }

    func pointerExited() {
        let hoverDelay = hoverDelay
        Task { await hoverDelay.mouseExited() }
    }

    func send(_ event: PillEvent) {
        let before = interaction.pauseReasons
        let oldMode = interaction.mode
        guard interaction.handle(event) else { return }
        let diff = PillInteraction.diff(from: before, to: interaction.pauseReasons)
        let rotation = rotation
        for reason in diff.pause { Task { await rotation.pause(reason) } }
        for reason in diff.resume { Task { await rotation.resume(reason) } }
        guard interaction.mode != oldMode else { return }
        if interaction.mode != .collapsed { refreshSummaries() }
        onModeChange?(interaction.mode)
    }

    /// Change % and sparkline for every watched currency in the selected range.
    func refreshSummaries() {
        let history = history
        let snapshot = snapshot
        let range = settings.changeRange
        let codes = watchList.orderedCodes
        Task { [weak self] in
            var fresh: [String: ChangeSummary] = [:]
            for code in codes {
                fresh[code] = await history.summary(quote: code, base: snapshot.baseCode, range: range,
                                                    current: snapshot.quotes[code]?.value)
            }
            self?.summaries = fresh
        }
    }

    // MARK: - Display

    var formatter: RateFormatter {
        RateFormatter(catalog: catalog, locale: settings.language.formattingLocale)
    }

    var collapsed: CollapsedRate? {
        guard let code = currentCode else { return nil }
        return formatter.collapsed(code: code, quote: snapshot.quotes[code], baseCode: snapshot.baseCode)
    }

    var isStale: Bool { snapshot.status == .stale || snapshot.status == .offline }

    var rowBuilder: RateRowBuilder { RateRowBuilder(formatter: formatter) }

    func row(for code: String) -> RateRow {
        rowBuilder.row(code: code, quote: snapshot.quotes[code], baseCode: snapshot.baseCode, summary: summaries[code])
    }

    var currentRow: RateRow? { currentCode.map(row(for:)) }

    var rows: [RateRow] { watchList.orderedCodes.map(row(for:)) }

    /// "Updated 5 min ago" when data is stale or offline; "Offline" with no data at all (SPEC F20).
    var freshnessText: String? {
        switch snapshot.status {
        case .live:
            return nil
        case .noData:
            return String(localized: "Offline")
        case .stale, .offline:
            guard let ago = RateRowBuilder.updatedAgo(snapshot.lastUpdated, now: Date(),
                                                      locale: settings.language.formattingLocale) else {
                return String(localized: "Offline")
            }
            return String(localized: "Updated \(ago)")
        }
    }

    /// Cell counts that fit every watch-list currency, so the board keeps one width while rotating.
    var boardWidths: (code: Int, value: Int, symbol: Int) {
        let formatter = formatter
        let parts = watchList.orderedCodes.map {
            formatter.collapsed(code: $0, quote: snapshot.quotes[$0], baseCode: snapshot.baseCode)
        }
        return (parts.map(\.code.count).max() ?? 3,
                parts.map(\.value.count).max() ?? 1,
                parts.map(\.symbol.count).max() ?? 1)
    }

    func localizedName(for code: String) -> String {
        catalog.localizedName(for: code, locale: settings.language.formattingLocale)
    }
}
