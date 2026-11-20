/// Failures from fetching or validating rates. Messages never contain response bodies.
public enum RateError: Error, Equatable, Sendable {
    case transport(String)
    case badStatus(Int)
    case hostNotAllowed(String)
    case responseTooLarge
    case invalidResponse(String)
    case unsupportedBase(String)
    case noData
}
