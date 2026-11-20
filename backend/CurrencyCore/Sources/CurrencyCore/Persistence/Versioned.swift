/// Envelope stored around every persisted value so schema changes can be detected.
struct Versioned<Value: Codable>: Codable {
    let version: Int
    let value: Value
}

/// Reads only the version, so an unknown schema is rejected before decoding the payload.
struct VersionProbe: Decodable {
    let version: Int
}
