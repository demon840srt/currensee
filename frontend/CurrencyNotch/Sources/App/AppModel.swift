import CurrencyCore
import Foundation
import Observation

/// The only bridge between CurrencyCore and the UI (ARCHITECTURE.md). Main-actor state for SwiftUI/AppKit.
@MainActor
@Observable
final class AppModel {
    private(set) var snapshot: RateSnapshot = .empty()
    /// Code currently shown in the collapsed pill (driven by `RotationEngine`).
    private(set) var currentCode: String?
    private(set) var interaction = PillInteraction()
    private(set) var summaries: [String: ChangeSummary] = [:]

    // Window layout, set by `PillPanelController` so the SwiftUI content lines up with the panel.
    var slotSize = PillLayout.collapsedSize
    var dropdownDirection: PillLayout.DropdownDirection = .below
    var listHeight: CGFloat = 0
    /// Called when the pill changes between collapsed / expanded / dropdown.
    @ObservationIgnored var onModeChange: ((PillMode) -> Void)?
    private(set) var settings: AppSettings
    private(set) var watchList: WatchList
    let catalog = CurrencyCatalog.bundled

    @ObservationIgnored let store: SettingsStore
    @ObservationIgnored private let rateService: RateService
    @ObservationIgnored private let history: HistoryStore
    @ObservationIgnored private let rotation: RotationEngine
    @ObservationIgnored private let hoverDelay = HoverDelay()
    @ObservationIgnored private let connectivity = NetworkConnectivityMonitor()
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
        let loadedSettings = store.loadSettings()
        let loadedList = store.loadWatchList()
        settings = loadedSettings
        watchList = loadedList

        let client = URLSessionHTTPClient()
        let coinbase = CoinbaseProvider(client: client)
        let frankfurter = FrankfurterProvider(client: client)
        let cache = (try? DiskCache.defaultDirectory()).map { DiskCache(directory: $0) }
        history = HistoryStore(cache: cache)
        rateService = RateService(primary: coinbase, fallback: frankfurter, cache: cache, history: history,
                                  fiatHistory: frankfurter, cryptoHistory: coinbase)
        rotation = RotationEngine(codes: loadedList.orderedCodes, interval: loadedSettings.rotationInterval)
        currentCode = loadedList.orderedCodes.first
    }

    func start() {
        let service = rateService
        let history = history
        let settings = settings
        let watchList = watchList

        let rotation = rotation
        tasks.append(Task { [weak self] in
            for await snapshot in service.snapshots {
                self?.snapshot = snapshot
                if self?.mode != .collapsed { self?.refreshSummaries() }
            }
        })
        let hoverDelay = hoverDelay
        tasks.append(Task { [weak self] in
            for await hovering in hoverDelay.events {
                self?.send(hovering ? .hoverBegan : .hoverEnded)
            }
        })
        tasks.append(Task { [weak self] in
            for await code in rotation.currentCodes {
                self?.currentCode = code
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
    }

    func refreshNow() {
        let service = rateService
        Task { await service.triggerRefresh() }
    }

    var isPositionLocked: Bool { settings.isPositionLocked }

    func setPositionLocked(_ locked: Bool) {
        settings.isPositionLocked = locked
        store.save(settings)
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
        diff.pause.forEach(pauseRotation)
        diff.resume.forEach(resumeRotation)
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

    // MARK: - Rotation

    /// Hover and the dropdown pause rotation (SPEC F9); wired up in Phase 6.
    func pauseRotation(_ reason: RotationPauseReason) {
        let rotation = rotation
        Task { await rotation.pause(reason) }
    }

    func resumeRotation(_ reason: RotationPauseReason) {
        let rotation = rotation
        Task { await rotation.resume(reason) }
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
}
