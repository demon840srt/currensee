import AppKit
import SwiftUI

/// Pill typography (references/themes.md: SF Pro Rounded semibold, monospaced digits) and the
/// fixed split-flap cell widths derived from it.
@MainActor
enum PillFont {
    static let size: CGFloat = 13

    static let swiftUI = Font.system(size: size, weight: .semibold, design: .rounded).monospacedDigit()

    static let nsFont: NSFont = {
        let base = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .semibold)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: rounded, size: size) ?? base
    }()

    static func width(of string: String) -> CGFloat {
        ceil((string as NSString).size(withAttributes: [.font: nsFont]).width)
    }

    /// Every digit has the same advance; punctuation sits centered in a digit-wide cell.
    static let digitCell = width(of: "0")
    /// Wide enough for any capital letter, so codes never overflow their cells.
    static let letterCell = max(width(of: "M"), width(of: "W"))
    static let symbolCell = ["₪", "€", "$", "£", "¥", "₽", "₹", "₿", "₩"].map { width(of: $0) }.max() ?? digitCell
}
