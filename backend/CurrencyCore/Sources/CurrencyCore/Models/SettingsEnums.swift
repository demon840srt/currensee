public enum ThemeID: String, Codable, Sendable, CaseIterable {
    case ice, fire, israel, classicNotch, frostedGlass
}

public enum ChangeRange: String, Codable, Sendable, CaseIterable {
    case h24 = "24h"
    case d7 = "7d"
    case d30 = "30d"
}

/// UI language. `.system` follows the macOS language; the others override it (SPEC F30).
public enum AppLanguage: String, Codable, Sendable, CaseIterable {
    case system, he, en, es, ru
    case zhHans = "zh-Hans"
}
