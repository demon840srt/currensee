import Foundation

/// Mirrors `SMAppService.Status` so the logic is testable without ServiceManagement.
public enum LoginItemStatus: Sendable, Equatable {
    case enabled, requiresApproval, notRegistered, notFound
}

public enum LoginItemError: Error, Equatable, Sendable {
    case failed(String)
}

/// The app wraps `SMAppService.mainApp`; tests use a fake.
public protocol LoginItemService {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
}

/// What the "Launch at login" toggle shows, derived from the real service status (SPEC F32).
public struct LoginItemState: Sendable, Equatable {
    public let isOn: Bool
    /// Registered, but the user must allow it in System Settings › Login Items.
    public let needsApproval: Bool
    /// False when macOS can't find the app to register (e.g. not in /Applications on some setups).
    public let isAvailable: Bool

    public init(status: LoginItemStatus) {
        isOn = status == .enabled || status == .requiresApproval
        needsApproval = status == .requiresApproval
        isAvailable = status != .notFound
    }
}

public enum LoginItemController {
    /// Registers or unregisters as needed and returns the state read back from the service.
    public static func set(_ on: Bool, service: some LoginItemService) throws -> LoginItemState {
        let current = LoginItemState(status: service.status)
        if on != current.isOn {
            do {
                try on ? service.register() : service.unregister()
            } catch let error as LoginItemError {
                throw error
            } catch {
                throw LoginItemError.failed(String(describing: type(of: error)))
            }
        }
        return LoginItemState(status: service.status)
    }

    /// SPEC §4 defaults launch-at-login to on: register once, on the first Release launch (ADR-0018).
    public static func shouldAutoRegister(alreadyAttempted: Bool, wantsLaunchAtLogin: Bool, isReleaseBuild: Bool) -> Bool {
        !alreadyAttempted && wantsLaunchAtLogin && isReleaseBuild
    }
}
