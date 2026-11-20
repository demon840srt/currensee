import AppKit
import UserNotifications

enum NotificationStatus: Sendable, Equatable {
    case notDetermined, denied, authorized
}

/// Posts alert notifications (SPEC F29). Abstracted so app tests never touch the real notification center.
@MainActor
protocol AlertNotifying: AnyObject {
    func status() async -> NotificationStatus
    /// Shows the system prompt the first time; afterwards returns the stored decision.
    func requestAuthorization() async -> NotificationStatus
    func post(title: String, body: String, identifier: String)
}

@MainActor
final class Notifier: NSObject, AlertNotifying, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func status() async -> NotificationStatus {
        Self.map(await center.notificationSettings().authorizationStatus)
    }

    func requestAuthorization() async -> NotificationStatus {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        return await status()
    }

    func post(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }

    /// Show the banner even if the app happens to be frontmost (e.g. Settings open).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func map(_ status: UNAuthorizationStatus) -> NotificationStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        default: .authorized
        }
    }
}
