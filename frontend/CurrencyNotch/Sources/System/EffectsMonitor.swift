import AppKit
import CurrencyCore
import IOKit.ps

/// Watches the system conditions that pause theme effects (SPEC F26): power source, Low Power Mode and
/// Reduce Motion. Occlusion comes from the pill window (`PillPanelController`). Event-driven, no polling.
@MainActor
final class EffectsMonitor {
    private(set) var environment: EffectsEnvironment
    var onChange: (EffectsEnvironment) -> Void = { _ in }

    private var observers: [NSObjectProtocol] = []
    private var powerSource: CFRunLoopSource?

    init() {
        environment = EffectsEnvironment(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                                         onBattery: Self.isOnBattery(),
                                         lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                                         occluded: false)
    }

    func start() {
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.update { $0.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.update { $0.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled }
            }
        })
        // Power source changes (AC ⇄ battery), delivered on the main run loop.
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<EffectsMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.update { $0.onBattery = EffectsMonitor.isOnBattery() } }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            powerSource = source
        }
    }

    func setOccluded(_ occluded: Bool) {
        update { $0.occluded = occluded }
    }

    private func update(_ change: (inout EffectsEnvironment) -> Void) {
        var next = environment
        change(&next)
        guard next != environment else { return }
        environment = next
        onChange(next)
    }

    nonisolated static func isOnBattery() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return false }
        return (type as String) == kIOPSBatteryPowerValue
    }
}
