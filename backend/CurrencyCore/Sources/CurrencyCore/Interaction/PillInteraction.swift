import Foundation

public enum PillMode: Sendable, Equatable {
    case collapsed, expanded, dropdown
}

/// Hover events arrive after `HoverDelay` (300 ms in / 200 ms out).
public enum PillEvent: Sendable, Equatable {
    case hoverBegan, hoverEnded, click, clickOutside, escape
}

/// Collapsed ⇄ expanded (hover) ⇄ dropdown (click) state machine (SPEC F9, F11–F14).
public struct PillInteraction: Sendable, Equatable {
    public private(set) var mode: PillMode = .collapsed
    public private(set) var isHovering = false

    public init() {}

    /// Rotation pauses while hovered or while the dropdown is open (SPEC F9).
    public var pauseReasons: Set<RotationPauseReason> {
        var reasons: Set<RotationPauseReason> = []
        if isHovering { reasons.insert(.hover) }
        if mode == .dropdown { reasons.insert(.dropdown) }
        return reasons
    }

    /// Applies an event; returns true if mode or hover changed.
    @discardableResult
    public mutating func handle(_ event: PillEvent) -> Bool {
        let before = self
        switch event {
        case .hoverBegan:
            isHovering = true
            if mode == .collapsed { mode = .expanded }
        case .hoverEnded:
            isHovering = false
            if mode == .expanded { mode = .collapsed }   // an open dropdown stays open
        case .click:
            mode = mode == .dropdown ? restingMode : .dropdown
        case .clickOutside, .escape:
            if mode == .dropdown { mode = restingMode }
        }
        return self != before
    }

    private var restingMode: PillMode { isHovering ? .expanded : .collapsed }

    /// Which pause reasons to add and remove when going from `old` to `new`.
    public static func diff(from old: Set<RotationPauseReason>, to new: Set<RotationPauseReason>)
        -> (pause: Set<RotationPauseReason>, resume: Set<RotationPauseReason>) {
        (new.subtracting(old), old.subtracting(new))
    }
}
