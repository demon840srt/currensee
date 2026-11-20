import Foundation

/// User preferences. Interval setters clamp to the allowed ranges, so stored values are always valid.
public struct AppSettings: Codable, Sendable, Equatable {
    public static let rotationRange: ClosedRange<TimeInterval> = 3...30
    public static let minimumRefreshInterval: TimeInterval = 60

    /// SPEC §4 defaults.
    public static let `default` = AppSettings()

    public var rotationInterval: TimeInterval {
        get { storedRotation }
        set { storedRotation = Self.clampRotation(newValue) }
    }

    public var refreshInterval: TimeInterval {
        get { storedRefresh }
        set { storedRefresh = Self.clampRefresh(newValue) }
    }

    public var changeRange: ChangeRange = .h24
    public var themeID: ThemeID = .classicNotch
    public var language: AppLanguage = .he
    public var launchAtLogin = true
    public var pauseEffectsOnBattery = true

    private var storedRotation: TimeInterval = 5
    private var storedRefresh: TimeInterval = 120

    public init() {}

    static func clampRotation(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite else { return 5 }
        return min(max(value, rotationRange.lowerBound), rotationRange.upperBound)
    }

    static func clampRefresh(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite else { return 120 }
        return max(value, minimumRefreshInterval)
    }

    enum CodingKeys: String, CodingKey {
        case rotationInterval, refreshInterval, changeRange, themeID, language, launchAtLogin, pauseEffectsOnBattery
    }

    /// Lenient per-field decoding: a missing or unknown value falls back to its default instead of
    /// discarding every other setting.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        if let v = try? c.decode(TimeInterval.self, forKey: .rotationInterval) { rotationInterval = v }
        if let v = try? c.decode(TimeInterval.self, forKey: .refreshInterval) { refreshInterval = v }
        if let v = try? c.decode(ChangeRange.self, forKey: .changeRange) { changeRange = v }
        if let v = try? c.decode(ThemeID.self, forKey: .themeID) { themeID = v }
        if let v = try? c.decode(AppLanguage.self, forKey: .language) { language = v }
        if let v = try? c.decode(Bool.self, forKey: .launchAtLogin) { launchAtLogin = v }
        if let v = try? c.decode(Bool.self, forKey: .pauseEffectsOnBattery) { pauseEffectsOnBattery = v }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(rotationInterval, forKey: .rotationInterval)
        try c.encode(refreshInterval, forKey: .refreshInterval)
        try c.encode(changeRange, forKey: .changeRange)
        try c.encode(themeID, forKey: .themeID)
        try c.encode(language, forKey: .language)
        try c.encode(launchAtLogin, forKey: .launchAtLogin)
        try c.encode(pauseEffectsOnBattery, forKey: .pauseEffectsOnBattery)
    }
}
