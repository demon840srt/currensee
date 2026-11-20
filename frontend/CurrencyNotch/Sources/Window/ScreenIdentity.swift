import AppKit
import CurrencyCore

extension NSScreen {
    /// Stable per-display ID: the hardware UUID, which survives restarts and replugging
    /// (the CGDirectDisplayID number can change).
    var stableID: String {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = deviceDescription[key] as? NSNumber else { return "unknown" }
        let displayID = CGDirectDisplayID(number.uint32Value)
        if let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
           let string = CFUUIDCreateString(nil, uuid) as String? {
            return string
        }
        return "display-\(displayID)"
    }

    /// `isMain` means the primary display (menu bar, origin 0,0) — not `NSScreen.main`, which follows focus.
    static var geometries: [ScreenGeometry] {
        screens.enumerated().map { index, screen in
            ScreenGeometry(id: screen.stableID, frame: screen.frame, visibleFrame: screen.visibleFrame,
                           isMain: index == 0)
        }
    }
}
