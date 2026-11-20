import CurrencyCore
import Foundation

/// Records requested delays. The first `immediateCount` sleeps return at once; later ones wait until cancelled.
public actor MockSleeper: Sleeper {
    public private(set) var requestedDelays: [TimeInterval] = []
    private let immediateCount: Int

    public init(immediateCount: Int = 0) {
        self.immediateCount = immediateCount
    }

    public func sleep(for seconds: TimeInterval) async throws {
        requestedDelays.append(seconds)
        if requestedDelays.count <= immediateCount { return }
        try await Task.sleep(for: .seconds(3600))
    }
}
