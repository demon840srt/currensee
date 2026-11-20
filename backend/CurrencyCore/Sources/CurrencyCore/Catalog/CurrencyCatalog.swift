import Foundation

public enum CatalogError: Error, Equatable, Sendable {
    case duplicateCode(String)
    case invalidCode(String)
    case unreadable
}

/// The currencies the user can pick from: ISO fiat plus a curated crypto list, bundled as JSON.
public struct CurrencyCatalog: Sendable {
    public let currencies: [Currency]
    private let byCode: [String: Currency]

    public var fiat: [Currency] { currencies.filter { $0.kind == .fiat } }
    public var crypto: [Currency] { currencies.filter { $0.kind == .crypto } }

    /// The catalog shipped in the package. Empty (never a crash) if the resource is unreadable;
    /// tests guard against that.
    public static let bundled: CurrencyCatalog = {
        do {
            guard let url = Bundle.module.url(forResource: "currencies", withExtension: "json") else {
                throw CatalogError.unreadable
            }
            return try CurrencyCatalog(jsonData: Data(contentsOf: url))
        } catch {
            assertionFailure("Bundled currency catalog failed to load: \(error)")
            return CurrencyCatalog(validated: [])
        }
    }()

    public init(currencies: [Currency]) throws(CatalogError) {
        var seen = Set<String>()
        for c in currencies {
            guard CurrencyCode.isValid(c.code) else { throw .invalidCode(c.code) }
            guard seen.insert(c.code).inserted else { throw .duplicateCode(c.code) }
        }
        self.init(validated: currencies)
    }

    init(jsonData: Data) throws {
        struct File: Decodable { let version: Int; let currencies: [Currency] }
        let file = try JSONDecoder().decode(File.self, from: jsonData)
        guard file.version == 1 else { throw CatalogError.unreadable }
        try self.init(currencies: file.currencies)
    }

    private init(validated currencies: [Currency]) {
        self.currencies = currencies
        self.byCode = Dictionary(uniqueKeysWithValues: currencies.map { ($0.code, $0) })
    }

    public func currency(for code: String) -> Currency? {
        byCode[code.uppercased()]
    }

    /// Fiat names come from the system for `locale`; crypto (and anything the system doesn't know)
    /// uses the catalog's English name; unknown codes return the code itself.
    public func localizedName(for code: String, locale: Locale) -> String {
        guard let currency = currency(for: code) else { return code }
        if currency.kind == .fiat, let name = locale.localizedString(forCurrencyCode: currency.code) {
            return name
        }
        return currency.name
    }
}
