import Foundation

/// Finds catalog currencies by code or name (in the UI language and in English), ignoring case and accents.
/// Ranking: exact code, exact name, code prefix, name prefix, then anything containing the query.
public struct CatalogSearch: Sendable {
    public enum KindFilter: Sendable, Equatable, CaseIterable { case all, fiat, crypto }

    public let catalog: CurrencyCatalog
    public let locale: Locale

    public init(catalog: CurrencyCatalog = .bundled, locale: Locale = .autoupdatingCurrent) {
        self.catalog = catalog
        self.locale = locale
    }

    public func search(_ query: String, kind: KindFilter = .all, excluding: Set<String> = []) -> [Currency] {
        let candidates = catalog.currencies.filter { currency in
            !excluding.contains(currency.code) && (kind == .all || (kind == .fiat) == (currency.kind == .fiat))
        }
        let needle = fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty else {
            return candidates.sorted { ($0.kind == .crypto ? 1 : 0, $0.code) < ($1.kind == .crypto ? 1 : 0, $1.code) }
        }
        return candidates
            .compactMap { currency in rank(currency, needle).map { (currency, $0) } }
            .sorted { ($0.1, $0.0.code) < ($1.1, $1.0.code) }
            .map(\.0)
    }

    private func rank(_ currency: Currency, _ needle: String) -> Int? {
        let code = fold(currency.code)
        let names = [catalog.localizedName(for: currency.code, locale: locale), currency.name].map(fold)
        if code == needle { return 0 }
        if names.contains(needle) { return 1 }
        if code.hasPrefix(needle) { return 2 }
        if names.contains(where: { $0.hasPrefix(needle) }) { return 3 }
        if code.contains(needle) || names.contains(where: { $0.contains(needle) }) { return 4 }
        return nil
    }

    private func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: locale)
    }
}
