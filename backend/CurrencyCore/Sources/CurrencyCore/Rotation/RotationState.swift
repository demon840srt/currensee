import Foundation

public enum RotationPauseReason: Hashable, Sendable {
    case hover, dropdown
}

/// Which watch-list currency the pill shows, and when it may move on (SPEC F7, F9).
public struct RotationState: Sendable, Equatable {
    public private(set) var codes: [String]
    public private(set) var index = 0
    public private(set) var interval: TimeInterval
    public private(set) var pauseReasons: Set<RotationPauseReason> = []

    public init(codes: [String], interval: TimeInterval) {
        self.codes = codes
        self.interval = AppSettings.clampRotation(interval)
    }

    public var currentCode: String? { codes.indices.contains(index) ? codes[index] : nil }
    public var isPaused: Bool { !pauseReasons.isEmpty }
    public var canRotate: Bool { codes.count > 1 && !isPaused }

    /// Moves to the next code (wrapping). Returns false when paused or there's nothing to rotate to.
    @discardableResult
    public mutating func advance() -> Bool {
        guard canRotate else { return false }
        index = (index + 1) % codes.count
        return true
    }

    /// Keeps showing the current code if it's still in the list (wherever it moved); if it was removed,
    /// the code that took its position shows next; the index always stays in range.
    public mutating func setCodes(_ newCodes: [String]) {
        if let current = currentCode, let newIndex = newCodes.firstIndex(of: current) {
            index = newIndex
        } else {
            index = min(index, max(newCodes.count - 1, 0))
        }
        codes = newCodes
    }

    public mutating func setInterval(_ seconds: TimeInterval) {
        interval = AppSettings.clampRotation(seconds)
    }

    public mutating func pause(_ reason: RotationPauseReason) { pauseReasons.insert(reason) }
    public mutating func resume(_ reason: RotationPauseReason) { pauseReasons.remove(reason) }
}
