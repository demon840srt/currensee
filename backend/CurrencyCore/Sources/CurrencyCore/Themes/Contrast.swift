import Foundation

/// sRGB color with components in 0…1 (no AppKit/SwiftUI so it stays testable in the core).
public struct RGBA: Sendable, Hashable {
    public let r: Double
    public let g: Double
    public let b: Double
    public let a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// "#RRGGBB" or "RRGGBB". Invalid input yields black (only used with literals in this package).
    public init(hex: String, alpha: Double = 1) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = UInt32(digits, radix: 16) ?? 0
        self.init(r: Double((value >> 16) & 0xFF) / 255, g: Double((value >> 8) & 0xFF) / 255,
                  b: Double(value & 0xFF) / 255, a: alpha)
    }

    public static let white = RGBA(r: 1, g: 1, b: 1)
    public static let black = RGBA(r: 0, g: 0, b: 0)

    public func withAlpha(_ alpha: Double) -> RGBA { RGBA(r: r, g: g, b: b, a: alpha) }

    /// Source-over compositing onto an opaque background.
    public func composited(over background: RGBA) -> RGBA {
        RGBA(r: r * a + background.r * (1 - a), g: g * a + background.g * (1 - a), b: b * a + background.b * (1 - a))
    }

    /// Linear interpolation in sRGB (how gradients are drawn).
    public func mixed(with other: RGBA, _ t: Double) -> RGBA {
        RGBA(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t, a: a + (other.a - a) * t)
    }
}

/// WCAG 2.x relative luminance and contrast ratio (SPEC F27: text ≥ 4.5:1).
public enum Contrast {
    public static let minimumAA = 4.5

    public static func luminance(_ color: RGBA) -> Double {
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
    }

    public static func ratio(_ first: RGBA, _ second: RGBA) -> Double {
        let (l1, l2) = (luminance(first), luminance(second))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }
}
