public enum CurrencyKind: String, Codable, Sendable, CaseIterable {
    case fiat, crypto
}

/// A currency the user can watch. Fiat comes from ISO 4217, crypto from the Coinbase list.
public struct Currency: Codable, Sendable, Hashable, Identifiable {
    public var id: String { code }
    public let code: String
    /// English name; UI uses `CurrencyCatalog.localizedName(for:locale:)`.
    public let name: String
    public let kind: CurrencyKind
    public let symbol: String
    /// Flag emoji for fiat ("🇺🇸", "🌐" when no single country), asset name for crypto ("coin.btc").
    public let flagOrIcon: String
    /// Digits after the decimal point when displaying a rate quoted in this currency.
    public let decimals: Int

    public init(code: String, name: String, kind: CurrencyKind, symbol: String, flagOrIcon: String, decimals: Int) {
        self.code = code
        self.name = name
        self.kind = kind
        self.symbol = symbol
        self.flagOrIcon = flagOrIcon
        self.decimals = decimals
    }
}
