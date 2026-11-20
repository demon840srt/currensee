/// Validation for currency codes (ISO 4217 like "USD" or crypto tickers like "USDC").
public enum CurrencyCode {
    /// 2–10 uppercase ASCII letters or digits.
    public static func isValid(_ code: String) -> Bool {
        (2...10).contains(code.count) && code.allSatisfy { ("A"..."Z").contains($0) || ("0"..."9").contains($0) }
    }
}
