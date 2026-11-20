import Foundation

/// Drives `RotationState` on a timer and publishes the code to show.
/// After a resume, an interval change or a change of the shown code, the timer restarts so the
/// current code stays on screen for a full interval (ADR-0016).
public actor RotationEngine {
    public nonisolated let currentCodes: AsyncStream<String?>
    private let continuation: AsyncStream<String?>.Continuation
    private let sleeper: any Sleeper
    private var state: RotationState
    private var loopTask: Task<Void, Never>?
    private var sleepTask: Task<Void, any Error>?

    public init(codes: [String], interval: TimeInterval, sleeper: any Sleeper = TaskSleeper()) {
        state = RotationState(codes: codes, interval: interval)
        self.sleeper = sleeper
        (currentCodes, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuation.yield(state.currentCode)
    }

    deinit {
        continuation.finish()
    }

    public var currentCode: String? { state.currentCode }
    public var snapshot: RotationState { state }

    public func start() {
        guard loopTask == nil else { return }
        loopTask = Task { await self.runLoop() }
    }

    public func stop() {
        loopTask?.cancel()
        sleepTask?.cancel()
        loopTask = nil
        sleepTask = nil
    }

    public func pause(_ reason: RotationPauseReason) {
        state.pause(reason)
    }

    public func resume(_ reason: RotationPauseReason) {
        let wasPaused = state.isPaused
        state.resume(reason)
        if wasPaused && !state.isPaused { restartTimer() }
    }

    public func setInterval(_ seconds: TimeInterval) {
        state.setInterval(seconds)
        restartTimer()
    }

    public func setCodes(_ codes: [String]) {
        let before = state.currentCode
        state.setCodes(codes)
        if state.currentCode != before {
            continuation.yield(state.currentCode)
            restartTimer()
        }
    }

    private func restartTimer() {
        sleepTask?.cancel()
    }

    private func runLoop() async {
        while !Task.isCancelled {
            let sleeper = self.sleeper
            let interval = state.interval
            let task = Task { try await sleeper.sleep(for: interval) }
            sleepTask = task
            let completed = (try? await task.value) != nil
            sleepTask = nil
            guard !Task.isCancelled else { return }
            if completed, state.advance() {
                continuation.yield(state.currentCode)
            }
        }
    }
}
