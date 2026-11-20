import Foundation

/// How a currency is drawn next to its code. No third-party logos are bundled (ADR-0017).
public enum CurrencyIcon: Sendable, Equatable {
    case flag(String)
    case systemSymbol(String)
    /// One character on a colored badge; `hue` in 0..<1, stable per code.
    case monogram(String, hue: Double)

    /// Deterministic hue (Swift's `hashValue` is randomized per launch).
    public static func hue(for code: String) -> Double {
        let sum = code.unicodeScalars.enumerated().reduce(0) { $0 + Int($1.element.value) * ($1.offset + 7) }
        return Double((sum * 47) % 360) / 360
    }
}

public struct ChangeDisplay: Sendable, Equatable {
    /// "+2.50%", "−1.20%", "0.00%"; nil while collecting.
    public let text: String?
    public let direction: ChangeDirection
    /// Normalized to 0…1, oldest → newest.
    public let sparkline: [Double]

    public var isCollecting: Bool { text == nil }

    public var arrow: String {
        switch direction {
        case .up: "▲"
        case .down: "▼"
        case .flat: "="
        }
    }

    public static let collecting = ChangeDisplay(text: nil, direction: .flat, sparkline: [])
}

/// Everything the expanded pill and a dropdown row show for one currency.
public struct RateRow: Sendable, Equatable, Identifiable {
    public var id: String { code }
    public let code: String
    public let icon: CurrencyIcon
    public let valueText: String
    public let symbol: String
    public let change: ChangeDisplay
}

public struct RateRowBuilder: Sendable {
    public let formatter: RateFormatter

    public init(formatter: RateFormatter) {
        self.formatter = formatter
    }

    public func row(code: String, quote: RateQuote?, baseCode: String, summary: ChangeSummary?) -> RateRow {
        let collapsed = formatter.collapsed(code: code, quote: quote, baseCode: baseCode)
        return RateRow(code: code, icon: icon(for: code), valueText: collapsed.value, symbol: collapsed.symbol,
                       change: change(from: summary))
    }

    public func change(from summary: ChangeSummary?) -> ChangeDisplay {
        guard let summary, summary.state == .ready, let percent = summary.percent else { return .collecting }
        return ChangeDisplay(text: changeText(percent: percent), direction: summary.direction,
                             sparkline: Self.normalize(summary.points))
    }

    /// Signed percent with 2 decimals in the formatter's locale; uses a true minus sign (U+2212).
    public func changeText(percent: Decimal) -> String {
        let style = Decimal.FormatStyle(locale: formatter.locale)
            .precision(.fractionLength(2))
            .grouping(.never)
            .sign(strategy: .never)
            .rounded(rule: .toNearestOrAwayFromZero)
        let digits = String(abs(percent).formatted(style).unicodeScalars.filter {
            !((0x200E...0x200F).contains($0.value) || (0x202A...0x202E).contains($0.value) || (0x2066...0x2069).contains($0.value))
        })
        let sign = percent > 0 ? "+" : (percent < 0 ? "\u{2212}" : "")
        return "\(sign)\(digits)%"
    }

    public func icon(for code: String) -> CurrencyIcon {
        guard let currency = formatter.catalog.currency(for: code) else {
            return .monogram(String(code.prefix(1)), hue: CurrencyIcon.hue(for: code))
        }
        switch currency.kind {
        case .fiat:
            return .flag(currency.flagOrIcon)
        case .crypto:
            if currency.code == "BTC" { return .systemSymbol("bitcoinsign") }
            let letter = currency.symbol.count == 1 ? currency.symbol : String(currency.code.prefix(1))
            return .monogram(letter, hue: CurrencyIcon.hue(for: currency.code))
        }
    }

    /// Min–max normalization to 0…1; a flat or single-point series is a centered line (0.5).
    public static func normalize(_ values: [Decimal]) -> [Double] {
        guard let low = values.min(), let high = values.max() else { return [] }
        guard high > low else { return values.map { _ in 0.5 } }
        let span = high - low
        return values.map { NSDecimalNumber(decimal: ($0 - low) / span).doubleValue }
    }

    /// "5 min. ago" in `locale` (the app wraps it as "Updated …").
    public static func updatedAgo(_ date: Date?, now: Date, locale: Locale) -> String? {
        guard let date else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
