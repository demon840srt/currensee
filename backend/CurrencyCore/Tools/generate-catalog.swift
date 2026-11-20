import Foundation

// Regenerates Sources/CurrencyCore/Catalog/currencies.json from the system ISO 4217 data.
// Usage (from backend/CurrencyCore): swift Tools/generate-catalog.swift Sources/CurrencyCore/Catalog/currencies.json
let en = Locale(identifier: "en_US")
let excluded: Set<String> = ["XAG", "XAU", "XPD", "XPT", "XDR", "XSU", "XUA", "XBA", "XBB", "XBC", "XBD", "XTS", "XXX"]
let preferredSymbol: [String: String] = [
    "USD": "$", "EUR": "€", "GBP": "£", "JPY": "¥", "CNY": "¥", "ILS": "₪", "CHF": "CHF",
    "KRW": "₩", "INR": "₹", "RUB": "₽", "TRY": "₺", "UAH": "₴", "THB": "฿", "VND": "₫",
    "PHP": "₱", "NGN": "₦", "KZT": "₸", "PLN": "zł", "BRL": "R$", "CAD": "CA$", "AUD": "A$",
    "NZD": "NZ$", "HKD": "HK$", "SGD": "S$", "MXN": "MX$", "TWD": "NT$", "ZAR": "R"
]
let validRegions = Set(Locale.Region.isoRegions.map(\.identifier))

func symbol(for code: String) -> String {
    if let s = preferredSymbol[code] { return s }
    // Use the symbol of a locale whose currency this is, if it's short and not just the code.
    for id in Locale.availableIdentifiers {
        let l = Locale(identifier: id)
        if l.currency?.identifier == code, let s = l.currencySymbol, s != code, s.count <= 4 { return s }
    }
    return code
}

func flag(for code: String) -> String {
    if code == "EUR" { return "🇪🇺" }
    let region = String(code.prefix(2))
    guard !code.hasPrefix("X"), validRegions.contains(region) else { return "🌐" }
    return region.unicodeScalars.map { String(UnicodeScalar(127397 + $0.value)!) }.joined()
}

struct Entry: Encodable { let code, name, kind, symbol, flagOrIcon: String; let decimals: Int }

var fiat: [Entry] = []
for code in Locale.commonISOCurrencyCodes.sorted() where !excluded.contains(code) {
    guard let name = en.localizedString(forCurrencyCode: code) else { continue }
    fiat.append(Entry(code: code, name: name, kind: "fiat", symbol: symbol(for: code),
                      flagOrIcon: flag(for: code), decimals: code == "JPY" ? 2 : 4))
}

let crypto: [(String, String, String)] = [
    ("BTC", "Bitcoin", "₿"), ("ETH", "Ethereum", "Ξ"), ("USDT", "Tether", "USDT"),
    ("USDC", "USD Coin", "USDC"), ("SOL", "Solana", "SOL"), ("XRP", "XRP", "XRP"),
    ("DOGE", "Dogecoin", "Ð"), ("ADA", "Cardano", "ADA"), ("AVAX", "Avalanche", "AVAX"),
    ("DOT", "Polkadot", "DOT"), ("LINK", "Chainlink", "LINK"), ("LTC", "Litecoin", "Ł"),
    ("BCH", "Bitcoin Cash", "BCH"), ("SHIB", "Shiba Inu", "SHIB"), ("XLM", "Stellar", "XLM"),
    ("UNI", "Uniswap", "UNI"), ("ATOM", "Cosmos", "ATOM"), ("ETC", "Ethereum Classic", "ETC"),
    ("FIL", "Filecoin", "FIL"), ("AAVE", "Aave", "AAVE"), ("ALGO", "Algorand", "ALGO"),
    ("NEAR", "NEAR Protocol", "NEAR"), ("APT", "Aptos", "APT"), ("ARB", "Arbitrum", "ARB"),
    ("OP", "Optimism", "OP"), ("SUI", "Sui", "SUI"), ("PEPE", "Pepe", "PEPE"),
    ("DAI", "Dai", "DAI"), ("POL", "Polygon", "POL")
]
let cryptoEntries = crypto.map {
    Entry(code: $0.0, name: $0.1, kind: "crypto", symbol: $0.2,
          flagOrIcon: "coin.\($0.0.lowercased())", decimals: 5)
}
let fiatCodes = Set(fiat.map(\.code))
precondition(cryptoEntries.allSatisfy { !fiatCodes.contains($0.code) }, "crypto/fiat code clash")

struct File: Encodable { let version: Int; let currencies: [Entry] }
let enc = JSONEncoder()
enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
let data = try enc.encode(File(version: 1, currencies: fiat + cryptoEntries))
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("fiat \(fiat.count), crypto \(cryptoEntries.count)")
print(fiat.filter { $0.flagOrIcon == "🌐" }.map(\.code).joined(separator: " "))
