import Foundation
import Network

/// Reports network reachability changes (feeds `RateService.setOnline`). Not unit-tested: thin wrapper.
public final class NetworkConnectivityMonitor: Sendable {
    private let monitor = NWPathMonitor()
    // NWPathMonitor requires a dispatch queue.
    private let queue = DispatchQueue(label: "CurrencyNotch.connectivity")

    public init() {}

    public func start(onChange: @escaping @Sendable (Bool) -> Void) {
        monitor.pathUpdateHandler = { path in onChange(path.status == .satisfied) }
        monitor.start(queue: queue)
    }

    public func cancel() {
        monitor.cancel()
    }
}
