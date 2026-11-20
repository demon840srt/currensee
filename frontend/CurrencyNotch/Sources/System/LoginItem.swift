import CurrencyCore
import ServiceManagement

/// `SMAppService.mainApp` adapter (SPEC F32).
struct MainAppLoginItem: LoginItemService {
    var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notRegistered: .notRegistered
        case .notFound: .notFound
        @unknown default: .notFound
        }
    }

    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }

    @MainActor
    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
