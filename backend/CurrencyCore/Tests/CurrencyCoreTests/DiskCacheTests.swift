import Foundation
import Testing
@testable import CurrencyCore

@Suite("DiskCache")
struct DiskCacheTests {
    let quotes = [
        RateQuote(quoteCode: "USD", baseCode: "ILS", value: dec("3.7012"),
                  fetchedAt: Date(timeIntervalSince1970: 1_790_000_000), source: "coinbase"),
        RateQuote(quoteCode: "BTC", baseCode: "ILS", value: dec("341234.56"),
                  fetchedAt: Date(timeIntervalSince1970: 1_790_000_000), source: "coinbase")
    ]

    @Test func saveThenLoadRoundTrips() async throws {
        try await withTempDirectory { dir in
            let cache = DiskCache(directory: dir)
            try await cache.save(quotes, to: .quotes)
            let loaded = await cache.load([RateQuote].self, from: .quotes)
            #expect(loaded == quotes)
            #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("cache.json").path))
        }
    }

    @Test func missingFileLoadsAsNil() async {
        await withTempDirectory { dir in
            let cache = DiskCache(directory: dir)
            #expect(await cache.load([RateQuote].self, from: .quotes) == nil)
        }
    }

    @Test func createsDirectoryOnFirstSave() async throws {
        try await withTempDirectory { dir in
            let nested = dir.appendingPathComponent("a/b", isDirectory: true)
            let cache = DiskCache(directory: nested)
            try await cache.save(quotes, to: .history)
            #expect(await cache.load([RateQuote].self, from: .history) == quotes)
        }
    }

    @Test(arguments: [Data(), Data([0xFF, 0xFE, 0x00]), Data("{\"version\":1,\"value\":".utf8),
                      Data("{\"version\":1,\"value\":{\"x\":1}}".utf8), Data("[1,2,3]".utf8)])
    func corruptFileLoadsAsNilWithoutCrashing(_ garbage: Data) async throws {
        try await withTempDirectory { dir in
            try garbage.write(to: dir.appendingPathComponent("cache.json"))
            let cache = DiskCache(directory: dir)
            #expect(await cache.load([RateQuote].self, from: .quotes) == nil)
        }
    }

    @Test func unknownVersionLoadsAsNil() async throws {
        try await withTempDirectory { dir in
            try Data(#"{"version":999,"value":[]}"#.utf8).write(to: dir.appendingPathComponent("cache.json"))
            #expect(await DiskCache(directory: dir).load([RateQuote].self, from: .quotes) == nil)
        }
    }

    @Test func oversizedFileIsIgnored() async throws {
        try await withTempDirectory { dir in
            let big = Data(repeating: 0x20, count: DiskCache.maxFileSize + 1)
            try big.write(to: dir.appendingPathComponent("cache.json"))
            #expect(await DiskCache(directory: dir).load([RateQuote].self, from: .quotes) == nil)
        }
    }

    @Test func overwriteReplacesContentsAndLeavesNoTempFiles() async throws {
        try await withTempDirectory { dir in
            let cache = DiskCache(directory: dir)
            try await cache.save(quotes, to: .quotes)
            try await cache.save(Array(quotes.prefix(1)), to: .quotes)
            #expect(await cache.load([RateQuote].self, from: .quotes) == Array(quotes.prefix(1)))
            let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            #expect(files == ["cache.json"])
        }
    }

    @Test func removeDeletesFile() async throws {
        try await withTempDirectory { dir in
            let cache = DiskCache(directory: dir)
            try await cache.save(quotes, to: .quotes)
            try await cache.remove(.quotes)
            #expect(await cache.load([RateQuote].self, from: .quotes) == nil)
            try await cache.remove(.quotes) // removing a missing file is fine
        }
    }

    @Test func fileNamesMatchSpec() {
        #expect(CacheFile.quotes.fileName == "cache.json")
        #expect(CacheFile.history.fileName == "history.json")
    }
}
