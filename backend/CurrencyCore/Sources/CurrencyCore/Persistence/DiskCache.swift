import Foundation

/// Files kept in Application Support/CurrencyNotch.
public struct CacheFile: Sendable, Hashable {
    public let fileName: String
    public static let quotes = CacheFile(fileName: "cache.json")
    public static let history = CacheFile(fileName: "history.json")
}

/// Atomic JSON file storage. Unreadable, oversized, corrupt or other-version files load as `nil`.
public actor DiskCache {
    public static let schemaVersion = 1
    /// Upper bound for reading our own cache files; anything bigger is treated as corrupt.
    public static let maxFileSize = 8 * 1024 * 1024

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// `~/Library/Containers/<bundle id>/Data/Library/Application Support/CurrencyNotch` when sandboxed.
    public static func defaultDirectory() throws -> URL {
        try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("CurrencyNotch", isDirectory: true)
    }

    public func save<T: Encodable & Sendable>(_ value: T, to file: CacheFile) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(Envelope(version: Self.schemaVersion, value: value))
        try data.write(to: url(for: file), options: [.atomic])
    }

    public func load<T: Decodable & Sendable>(_ type: T.Type, from file: CacheFile) -> T? {
        let url = url(for: file)
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= Self.maxFileSize,
              let data = try? Data(contentsOf: url),
              let probe = try? JSONDecoder().decode(VersionProbe.self, from: data),
              probe.version == Self.schemaVersion,
              let envelope = try? JSONDecoder().decode(DecodableEnvelope<T>.self, from: data)
        else { return nil }
        return envelope.value
    }

    public func remove(_ file: CacheFile) throws {
        do {
            try FileManager.default.removeItem(at: url(for: file))
        } catch CocoaError.fileNoSuchFile {
            // Already gone.
        }
    }

    private func url(for file: CacheFile) -> URL {
        directory.appendingPathComponent(file.fileName, isDirectory: false)
    }

    private struct Envelope<V: Encodable>: Encodable { let version: Int; let value: V }
    private struct DecodableEnvelope<V: Decodable>: Decodable { let version: Int; let value: V }
}
