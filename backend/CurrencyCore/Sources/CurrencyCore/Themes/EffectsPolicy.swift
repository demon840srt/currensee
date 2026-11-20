import Foundation

public enum EffectsPauseReason: String, Sendable, Hashable {
    /// The theme has no particles or animated effects.
    case noEffects
    case reduceMotion
    case battery
    case lowPowerMode
    /// The pill window is fully covered.
    case occluded
}

public struct EffectsEnvironment: Sendable, Equatable {
    public var reduceMotion: Bool
    public var onBattery: Bool
    public var lowPowerMode: Bool
    public var occluded: Bool

    public init(reduceMotion: Bool, onBattery: Bool, lowPowerMode: Bool, occluded: Bool) {
        self.reduceMotion = reduceMotion
        self.onBattery = onBattery
        self.lowPowerMode = lowPowerMode
        self.occluded = occluded
    }
}

/// When particles and shimmer run (SPEC F26): never with Reduce Motion or while covered; not on battery or
/// in Low Power Mode when "pause effects on battery" is on.
public enum EffectsPolicy {
    public static func pauseReasons(theme: ThemeSpec, pauseOnBattery: Bool,
                                    environment env: EffectsEnvironment) -> Set<EffectsPauseReason> {
        guard theme.hasEffects else { return [.noEffects] }
        var reasons: Set<EffectsPauseReason> = []
        if env.reduceMotion { reasons.insert(.reduceMotion) }
        if pauseOnBattery && env.onBattery { reasons.insert(.battery) }
        if pauseOnBattery && env.lowPowerMode { reasons.insert(.lowPowerMode) }
        if env.occluded { reasons.insert(.occluded) }
        return reasons
    }

    public static func shouldRun(theme: ThemeSpec, pauseOnBattery: Bool, environment: EffectsEnvironment) -> Bool {
        pauseReasons(theme: theme, pauseOnBattery: pauseOnBattery, environment: environment).isEmpty
    }
}
