import Foundation
import Synchronization

/// Manually advanced clock for deterministic time in tests.
public final class TestClock: Sendable {
    private let current: Mutex<Date>

    public init(_ start: Date = Date(timeIntervalSince1970: 1_795_000_000)) {
        current = Mutex(start)
    }

    public var now: Date { current.withLock { $0 } }

    public func advance(by seconds: TimeInterval) {
        current.withLock { $0 = $0.addingTimeInterval(seconds) }
    }

    public func set(_ date: Date) {
        current.withLock { $0 = date }
    }

    /// Closure suitable for `now:` parameters.
    public var provider: @Sendable () -> Date { { [self] in self.now } }
}
