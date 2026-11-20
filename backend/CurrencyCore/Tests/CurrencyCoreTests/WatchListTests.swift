import Foundation
import Testing
@testable import CurrencyCore

@Suite("WatchList")
struct WatchListTests {
    @Test func acceptsSingleCurrency() throws {
        let list = try WatchList(baseCode: "ILS", orderedCodes: ["USD"])
        #expect(list.orderedCodes == ["USD"])
    }

    @Test func acceptsManyCurrenciesAndKeepsOrder() throws {
        let codes = ["BTC", "USD", "EUR", "JPY", "GBP", "CHF", "CNY", "ETH", "SOL", "CAD", "AUD", "SEK"]
        let list = try WatchList(baseCode: "ILS", orderedCodes: codes)
        #expect(list.orderedCodes == codes)
    }

    @Test func rejectsEmpty() {
        #expect(throws: WatchListError.empty) { try WatchList(baseCode: "ILS", orderedCodes: []) }
    }

    @Test func rejectsDuplicates() {
        #expect(throws: WatchListError.duplicate("USD")) {
            try WatchList(baseCode: "ILS", orderedCodes: ["USD", "EUR", "USD"])
        }
    }

    @Test func rejectsBaseInList() {
        #expect(throws: WatchListError.containsBase("ILS")) {
            try WatchList(baseCode: "ILS", orderedCodes: ["USD", "ILS"])
        }
    }

    @Test(arguments: ["", "usd", "US D", "TOOLONGCODE1", "€UR"])
    func rejectsInvalidCodes(_ code: String) {
        #expect(throws: WatchListError.invalidCode(code)) {
            try WatchList(baseCode: "ILS", orderedCodes: [code])
        }
        #expect(throws: WatchListError.invalidCode(code)) {
            try WatchList(baseCode: code, orderedCodes: ["USD"])
        }
    }

    @Test func addAppendsAtEnd() throws {
        var list = try WatchList(baseCode: "ILS", orderedCodes: ["USD", "EUR"])
        try list.add("BTC")
        #expect(list.orderedCodes == ["USD", "EUR", "BTC"])
        #expect(throws: WatchListError.duplicate("EUR")) { try list.add("EUR") }
        #expect(throws: WatchListError.containsBase("ILS")) { try list.add("ILS") }
    }

    @Test func removeKeepsOrderAndRefusesLast() throws {
        var list = try WatchList(baseCode: "ILS", orderedCodes: ["USD", "EUR", "BTC"])
        try list.remove("EUR")
        #expect(list.orderedCodes == ["USD", "BTC"])
        #expect(throws: WatchListError.notFound("GBP")) { try list.remove("GBP") }
        try list.remove("USD")
        #expect(throws: WatchListError.cannotRemoveLast) { try list.remove("BTC") }
        #expect(list.orderedCodes == ["BTC"])
    }

    @Test func moveSingleItem() throws {
        var list = try WatchList(baseCode: "ILS", orderedCodes: ["A1", "B1", "C1", "D1"])
        list.move(fromOffsets: [0], toOffset: 3)   // SwiftUI onMove semantics
        #expect(list.orderedCodes == ["B1", "C1", "A1", "D1"])
        list.move(fromOffsets: [3], toOffset: 0)
        #expect(list.orderedCodes == ["D1", "B1", "C1", "A1"])
    }

    @Test func moveMultipleItemsAndIgnoresOutOfRange() throws {
        var list = try WatchList(baseCode: "ILS", orderedCodes: ["A1", "B1", "C1", "D1", "E1"])
        list.move(fromOffsets: [0, 2], toOffset: 5)
        #expect(list.orderedCodes == ["B1", "D1", "E1", "A1", "C1"])
        list.move(fromOffsets: [42], toOffset: 0)
        #expect(list.orderedCodes == ["B1", "D1", "E1", "A1", "C1"])
        list.move(fromOffsets: [0], toOffset: 99)
        #expect(list.orderedCodes == ["D1", "E1", "A1", "C1", "B1"])
    }

    @Test func changeBaseRemovesNewBaseFromList() throws {
        var list = try WatchList(baseCode: "ILS", orderedCodes: ["USD", "EUR", "BTC"])
        try list.changeBase(to: "USD")
        #expect(list.baseCode == "USD")
        #expect(list.orderedCodes == ["EUR", "BTC"])
    }

    @Test func changeBaseToOnlyItemPutsOldBaseInList() throws {
        var list = try WatchList(baseCode: "ILS", orderedCodes: ["USD"])
        try list.changeBase(to: "USD")
        #expect(list.baseCode == "USD")
        #expect(list.orderedCodes == ["ILS"])
    }

    @Test func changeBaseToSameIsNoOp() throws {
        var list = try WatchList(baseCode: "ILS", orderedCodes: ["USD"])
        try list.changeBase(to: "ILS")
        #expect(list == (try WatchList(baseCode: "ILS", orderedCodes: ["USD"])))
        #expect(throws: WatchListError.invalidCode("x")) { try list.changeBase(to: "x") }
    }

    @Test func decodingValidates() {
        let json = #"{"baseCode":"ILS","orderedCodes":["USD","USD"]}"#
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(WatchList.self, from: Data(json.utf8))
        }
    }
}
