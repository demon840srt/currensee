import Foundation

public enum TextTransitionStyle: Sendable, Equatable {
    case splitFlap, crossfade

    /// Reduce Motion replaces the flip with a crossfade (SPEC F26, references/themes.md).
    public static func style(reduceMotion: Bool) -> TextTransitionStyle {
        reduceMotion ? .crossfade : .splitFlap
    }

    public var duration: TimeInterval {
        switch self {
        case .splitFlap: SplitFlapPlan.totalDuration
        case .crossfade: 0.25
        }
    }
}

/// Character-cell plan for one split-flap change: both strings padded to the same number of cells,
/// which cells change, and a staggered start delay per changed cell so the whole flip takes ≈ 0.4 s.
public struct SplitFlapPlan: Sendable, Equatable {
    public enum Alignment: Sendable, Equatable { case leading, trailing }

    public static let totalDuration: TimeInterval = 0.4
    /// Duration of one cell's flip (both halves).
    public static let flipDuration: TimeInterval = 0.2

    public let from: [Character]
    public let to: [Character]
    public let changedCells: [Int]

    public var cellCount: Int { to.count }

    public init(from old: String, to new: String, alignment: Alignment = .leading, minimumLength: Int = 0) {
        let width = max(old.count, new.count, minimumLength)
        let padded = (Self.pad(old, to: width, alignment: alignment), Self.pad(new, to: width, alignment: alignment))
        from = padded.0
        to = padded.1
        changedCells = (0..<width).filter { padded.0[$0] != padded.1[$0] }
    }

    public func delay(forCell cell: Int) -> TimeInterval {
        guard let rank = changedCells.firstIndex(of: cell), changedCells.count > 1 else { return 0 }
        let spread = Self.totalDuration - Self.flipDuration
        return spread * Double(rank) / Double(changedCells.count - 1)
    }

    private static func pad(_ s: String, to width: Int, alignment: Alignment) -> [Character] {
        let padding = Array(repeating: Character(" "), count: max(0, width - s.count))
        return alignment == .leading ? Array(s) + padding : padding + Array(s)
    }
}
