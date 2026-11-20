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
    let catalog = CurrencyCatalog.bundled

    @ObservationIgnored let store: SettingsStore
    @ObservationIgnored private let rateService: RateService
    @ObservationIgnored private let history: HistoryStore
    @ObservationIgnored private let connectivity = NetworkConnectivityMonitor()
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
        settings = store.loadSettings()
        watchList = store.loadWatchList()

        let client = URLSessionHTTPClient()
        let coinbase = CoinbaseProvider(client: client)
        let frankfurter = FrankfurterProvider(client: client)
        let cache = (try? DiskCache.defaultDirectory()).map { DiskCache(directory: $0) }
        history = HistoryStore(cache: cache)
        rateService = RateService(primary: coinbase, fallback: frankfurter, cache: cache, history: history,
                                  fiatHistory: frankfurter, cryptoHistory: coinbase)
    }

    func start() {
        let service = rateService
        let history = history
        let settings = settings
        let watchList = watchList

        tasks.append(Task { [weak self] in
            for await snapshot in service.snapshots {
                self?.snapshot = snapshot
            }
        })
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

    /// The currency shown in the collapsed pill. Phase 5 replaces this with the rotation engine.
    var displayedCode: String? { watchList.orderedCodes.first }
}
