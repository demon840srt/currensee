import Foundation

/// The three parts of the collapsed pill text: `USD 3.3429 ₪`.
public struct CollapsedRate: Sendable, Equatable {
    public let code: String
    public let value: String
    public let symbol: String

    public var text: String { "\(code) \(value) \(symbol)" }
}

/// Formats rates for display (ADR-0016):
/// - value ≥ 1000 → 2 decimals with grouping;
/// - 1 ≤ value < 1000 → the currency's catalog decimals;
/// - value < 1 → catalog decimals, but at least 4 significant digits.
public struct RateFormatter: Sendable {
    public static let minimumSignificantDigits = 4
    public static let maxFractionDigits = 12
    public static let missingValue = "—"

    public let catalog: CurrencyCatalog
    public let locale: Locale

    public init(catalog: CurrencyCatalog = .bundled, locale: Locale = .autoupdatingCurrent) {
        self.catalog = catalog
        self.locale = locale
    }

    public func fractionDigits(for value: Decimal, quoteCode: String) -> Int {
        let magnitude = abs(value)
        if magnitude >= 1000 { return 2 }
        let catalogDigits = catalog.currency(for: quoteCode)?.decimals ?? 4
        guard magnitude < 1, magnitude > 0 else { return catalogDigits }
        // Position of the first non-zero digit after the decimal point (0.0211 → 2). Double is only
        // used to pick a digit count, never as the displayed value.
        let exponent = -log10(NSDecimalNumber(decimal: magnitude).doubleValue)
        let leadingZeros = Int(exponent.rounded(.up)) - 1
        let significant = leadingZeros + 1 + Self.minimumSignificantDigits - 1
        return min(max(catalogDigits, significant), Self.maxFractionDigits)
    }

    public func number(_ value: Decimal, quoteCode: String) -> String {
        let digits = fractionDigits(for: value, quoteCode: quoteCode)
        let style = Decimal.FormatStyle(locale: locale)
            .precision(.fractionLength(digits))
            .grouping(abs(value) >= 1000 ? .automatic : .never)
            .rounded(rule: .toNearestOrAwayFromZero)
        return Self.stripBidiControls(value.formatted(style))
    }

    public func symbol(for baseCode: String) -> String {
        catalog.currency(for: baseCode)?.symbol ?? baseCode
    }

    public func collapsed(code: String, quote: RateQuote?, baseCode: String) -> CollapsedRate {
        let value = quote.map { number($0.value, quoteCode: code) } ?? Self.missingValue
        return CollapsedRate(code: code, value: value, symbol: symbol(for: baseCode))
    }

    /// The view isolates numbers as LTR itself; drop any direction marks a locale may insert.
    private static func stripBidiControls(_ s: String) -> String {
        String(s.unicodeScalars.filter {
            !((0x200E...0x200F).contains($0.value) || (0x202A...0x202E).contains($0.value) || (0x2066...0x2069).contains($0.value))
        })
    }
}

extension AppLanguage {
    /// Locale used for number formatting. `.system` follows the user's macOS settings.
    public var formattingLocale: Locale {
        switch self {
        case .system: .autoupdatingCurrent
        case .he: Locale(identifier: "he_IL")
        case .en: Locale(identifier: "en_US")
        case .es: Locale(identifier: "es_ES")
        case .ru: Locale(identifier: "ru_RU")
        case .zhHans: Locale(identifier: "zh_Hans_CN")
        }
    }
}
