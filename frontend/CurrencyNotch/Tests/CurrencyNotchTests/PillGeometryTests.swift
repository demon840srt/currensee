import CoreGraphics
import Testing
@testable import CurrencyNotch

@Suite("PillGeometry")
struct PillGeometryTests {
    @Test func collapsedSizeIsNotchSized() {
        #expect(PillGeometry.collapsedSize == CGSize(width: 200, height: 34))
    }

    @Test func topCenterOriginIsCenteredAtTopOfVisibleFrame() {
        let visible = CGRect(x: 0, y: 0, width: 1512, height: 944)
        let origin = PillGeometry.topCenterOrigin(size: PillGeometry.collapsedSize, in: visible)
        #expect(origin == CGPoint(x: 656, y: 910))
    }

    @Test func topCenterOriginRespectsOffsetScreens() {
        // A secondary display placed to the trailing side of the main one.
        let visible = CGRect(x: 1512, y: -200, width: 1920, height: 1055)
        let origin = PillGeometry.topCenterOrigin(size: CGSize(width: 200, height: 34), in: visible)
        #expect(origin == CGPoint(x: 2372, y: 821))
    }
}
