import Foundation

/// Debounces raw mouse enter/exit into hover begin/end: 300 ms to expand, 200 ms to collapse
/// (references/ui-sizes.md). Leaving before the enter delay, or re-entering before the exit delay,
/// cancels the pending change.
public actor HoverDelay {
    public static let enterDelay: TimeInterval = 0.3
    public static let exitDelay: TimeInterval = 0.2

    public nonisolated let events: AsyncStream<Bool>
    /// Every reported change (true = hover began), for tests and diagnostics.
    public private(set) var history: [Bool] = []

    private let continuation: AsyncStream<Bool>.Continuation
    private let sleeper: any Sleeper
    private var isReportedHovering = false
    private var pending: Task<Void, Never>?
    private var generation = 0

    public init(sleeper: any Sleeper = TaskSleeper()) {
        self.sleeper = sleeper
        (events, continuation) = AsyncStream.makeStream(bufferingPolicy: .unbounded)
    }

    deinit {
        continuation.finish()
    }

    public func mouseEntered() {
        cancelPending()
        guard !isReportedHovering else { return }
        schedule(true, after: Self.enterDelay)
    }

    public func mouseExited() {
        cancelPending()
        guard isReportedHovering else { return }
        schedule(false, after: Self.exitDelay)
    }

    private func cancelPending() {
        generation += 1
        pending?.cancel()
        pending = nil
    }

    private func schedule(_ hovering: Bool, after delay: TimeInterval) {
        let ticket = generation
        let sleeper = self.sleeper
        pending = Task {
            do { try await sleeper.sleep(for: delay) } catch { return }
            self.report(hovering, ticket: ticket)
        }
    }

    private func report(_ hovering: Bool, ticket: Int) {
        guard ticket == generation, hovering != isReportedHovering else { return }
        isReportedHovering = hovering
        history.append(hovering)
        continuation.yield(hovering)
    }
}
