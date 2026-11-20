import CoreGraphics
import Testing
@testable import CurrencyNotch

@Suite("PillGeometry")
struct PillGeometryTests {
    @Test func collapsedSizeIsNotchSized() {
        #expect(PillGeometry.collapsedSize == CGSize(width: 200, height: 34))
    }

    @Test @MainActor func panelUsesDesktopLevel() {
        #expect(PillPanel.desktopLevel.rawValue == Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    }
}
