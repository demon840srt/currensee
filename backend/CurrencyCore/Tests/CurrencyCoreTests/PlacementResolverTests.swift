import Foundation
import CoreGraphics
import Testing
@testable import CurrencyCore

@Suite("PlacementResolver")
struct PlacementResolverTests {
    let size = CGSize(width: 200, height: 34)
    // Main display with a 25-pt menu bar and a 70-pt Dock at the bottom.
    let main = ScreenGeometry(id: "main", frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                              visibleFrame: CGRect(x: 0, y: 70, width: 1512, height: 887), isMain: true)
    // External display to the left of main, lower, so it has negative coordinates.
    let left = ScreenGeometry(id: "left", frame: CGRect(x: -1920, y: -300, width: 1920, height: 1080),
                              visibleFrame: CGRect(x: -1920, y: -300, width: 1920, height: 1055), isMain: false)
    let top = ScreenGeometry(id: "top", frame: CGRect(x: 0, y: 982, width: 2560, height: 1440),
                             visibleFrame: CGRect(x: 0, y: 982, width: 2560, height: 1415), isMain: false)

    @Test func topCenterOfVisibleFrame() {
        #expect(PlacementResolver.topCenterOrigin(size: size, in: main.visibleFrame) == CGPoint(x: 656, y: 923))
        #expect(PlacementResolver.topCenterOrigin(size: size, in: left.visibleFrame) == CGPoint(x: -1060, y: 721))
    }

    @Test func firstLaunchGoesToMainTopCenter() {
        let result = PlacementResolver.resolve(placements: [:], lastScreenID: nil, screens: [left, main], size: size)
        #expect(result == ResolvedPlacement(screenID: "main", origin: CGPoint(x: 656, y: 923)))
    }

    @Test func restoresSavedPositionOnLastScreen() {
        let saved = WidgetPlacement(screenID: "left", originX: -1500, originY: 100)
        let result = PlacementResolver.resolve(placements: ["left": saved], lastScreenID: "left",
                                               screens: [main, left], size: size)
        #expect(result == ResolvedPlacement(screenID: "left", origin: CGPoint(x: -1500, y: 100)))
    }

    @Test func missingLastScreenFallsBackToSavedMainPosition() {
        let onLeft = WidgetPlacement(screenID: "left", originX: -1500, originY: 100)
        let onMain = WidgetPlacement(screenID: "main", originX: 300, originY: 500)
        let result = PlacementResolver.resolve(placements: ["left": onLeft, "main": onMain], lastScreenID: "left",
                                               screens: [main], size: size)
        #expect(result == ResolvedPlacement(screenID: "main", origin: CGPoint(x: 300, y: 500)))
    }

    @Test func missingLastScreenWithoutMainPositionGoesToMainTopCenter() {
        let onLeft = WidgetPlacement(screenID: "left", originX: -1500, originY: 100)
        let result = PlacementResolver.resolve(placements: ["left": onLeft], lastScreenID: "left",
                                               screens: [top, main], size: size)
        #expect(result == ResolvedPlacement(screenID: "main", origin: CGPoint(x: 656, y: 923)))
    }

    @Test func savedPositionIsClampedWhenScreenShrank() {
        let saved = WidgetPlacement(screenID: "main", originX: 2400, originY: 1300)
        let result = PlacementResolver.resolve(placements: ["main": saved], lastScreenID: "main",
                                               screens: [main], size: size)
        #expect(result.origin == CGPoint(x: 1312, y: 923))
    }

    @Test func noScreensFallsBackToZeroWithoutCrashing() {
        let result = PlacementResolver.resolve(placements: [:], lastScreenID: nil, screens: [], size: size)
        #expect(result.screenID == nil)
        #expect(result.origin == .zero)
    }

    @Test func nonMainFirstScreenIsUsedWhenNoneIsMarkedMain() {
        let lone = ScreenGeometry(id: "x", frame: left.frame, visibleFrame: left.visibleFrame, isMain: false)
        let result = PlacementResolver.resolve(placements: [:], lastScreenID: nil, screens: [lone], size: size)
        #expect(result.screenID == "x")
    }

    @Test(arguments: [
        (CGPoint(x: -50, y: 500), CGPoint(x: 0, y: 500)),        // past leading edge
        (CGPoint(x: 1400, y: 500), CGPoint(x: 1312, y: 500)),    // past trailing edge
        (CGPoint(x: 600, y: 10), CGPoint(x: 600, y: 70)),        // into the Dock
        (CGPoint(x: 600, y: 950), CGPoint(x: 600, y: 923)),      // under the menu bar
        (CGPoint(x: 9999, y: -9999), CGPoint(x: 1312, y: 70)),   // corner
        (CGPoint(x: 600, y: 500), CGPoint(x: 600, y: 500))       // already inside
    ])
    func clampKeepsPillInsideVisibleFrame(input: CGPoint, expected: CGPoint) {
        #expect(PlacementResolver.clamp(origin: input, size: size, in: main.visibleFrame) == expected)
    }

    @Test func clampOnNegativeCoordinateScreen() {
        let clamped = PlacementResolver.clamp(origin: CGPoint(x: -3000, y: -900), size: size, in: left.visibleFrame)
        #expect(clamped == CGPoint(x: -1920, y: -300))
    }

    @Test func pillLargerThanScreenPinsToOrigin() {
        let tiny = CGRect(x: 10, y: 10, width: 100, height: 20)
        #expect(PlacementResolver.clamp(origin: CGPoint(x: 50, y: 50), size: size, in: tiny) == CGPoint(x: 10, y: 10))
    }

    @Test func screenContainingPillCenter() {
        let screens = [main, left, top]
        let onLeft = CGRect(x: -900, y: 200, width: 200, height: 34)
        #expect(PlacementResolver.screen(containing: onLeft, in: screens)?.id == "left")
        // Straddling main/top: the center (y = 982 + 7) is on top.
        let straddle = CGRect(x: 500, y: 972, width: 200, height: 34)
        #expect(PlacementResolver.screen(containing: straddle, in: screens)?.id == "top")
        // Center in a gap between displays → nearest screen.
        let gap = CGRect(x: 1700, y: 400, width: 200, height: 34)
        #expect(PlacementResolver.screen(containing: gap, in: screens)?.id == "main")
        #expect(PlacementResolver.screen(containing: gap, in: []) == nil)
    }

    @Test func finishDragClampsAndReportsScreen() {
        let dropped = CGRect(x: -100, y: 20, width: 200, height: 34)   // center x = 0 → main (frames are half-open)
        let result = PlacementResolver.finishDrag(frame: dropped, screens: [main, left])
        #expect(result == ResolvedPlacement(screenID: "main", origin: CGPoint(x: 0, y: 70)))
    }
}

@Suite("PointerGesture")
struct PointerGestureTests {
    @Test(arguments: [
        (CGPoint(x: 0, y: 0), PointerGesture.Kind.click),
        (CGPoint(x: 3.9, y: 0), .click),
        (CGPoint(x: 2.8, y: 2.8), .click),      // 3.96 pt diagonally
        (CGPoint(x: 4, y: 0), .drag),
        (CGPoint(x: 0, y: -4), .drag),
        (CGPoint(x: 3, y: 3), .drag),           // 4.24 pt diagonally
        (CGPoint(x: 10, y: 10), .drag)
    ])
    func classifiesByDistance(offset: CGPoint, expected: PointerGesture.Kind) {
        var gesture = PointerGesture(start: CGPoint(x: 100, y: 100), isLocked: false)
        gesture.update(to: CGPoint(x: 100 + offset.x, y: 100 + offset.y))
        #expect(gesture.kind == expected)
    }

    @Test func onceDragAlwaysDragEvenIfReturnedToStart() {
        var gesture = PointerGesture(start: .zero, isLocked: false)
        gesture.update(to: CGPoint(x: 20, y: 0))
        gesture.update(to: CGPoint(x: 1, y: 0))
        #expect(gesture.kind == .drag)
        #expect(gesture.shouldMoveWindow)
    }

    @Test func dragOffsetFollowsPointer() {
        var gesture = PointerGesture(start: CGPoint(x: 10, y: 10), isLocked: false)
        gesture.update(to: CGPoint(x: 25, y: 4))
        #expect(gesture.offset == CGVector(dx: 15, dy: -6))
    }

    @Test func lockedClickStillWorks() {
        var gesture = PointerGesture(start: .zero, isLocked: true)
        gesture.update(to: CGPoint(x: 2, y: 1))
        #expect(gesture.kind == .click)
        #expect(gesture.isClick)
    }

    @Test func lockedDragDoesNothing() {
        var gesture = PointerGesture(start: .zero, isLocked: true)
        gesture.update(to: CGPoint(x: 30, y: 0))
        #expect(gesture.kind == .drag)
        #expect(!gesture.shouldMoveWindow)
        #expect(!gesture.isClick)
    }

    @Test func thresholdMatchesSpec() {
        #expect(PointerGesture.dragThreshold == 4)
    }
}

@Suite("SettingsStore placement additions")
struct PlacementPersistenceTests {
    @Test func lastScreenIDPersists() {
        withTestDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            #expect(store.loadLastScreenID() == nil)
            store.saveLastScreenID("screen-uuid-1")
            #expect(SettingsStore(defaults: defaults).loadLastScreenID() == "screen-uuid-1")
        }
    }

    @Test func positionLockPersistsAndDefaultsToUnlocked() {
        withTestDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            #expect(store.loadSettings().isPositionLocked == false)
            var settings = store.loadSettings()
            settings.isPositionLocked = true
            store.save(settings)
            #expect(SettingsStore(defaults: defaults).loadSettings().isPositionLocked == true)
        }
    }

    @Test func oldSettingsWithoutLockFieldStillDecode() throws {
        let json = #"{"rotationInterval":7,"themeID":"ice"}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        #expect(settings.isPositionLocked == false)
        #expect(settings.rotationInterval == 7)
    }
}
