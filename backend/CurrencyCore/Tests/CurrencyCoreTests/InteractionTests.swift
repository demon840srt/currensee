import Foundation
import Testing
@testable import CurrencyCore
import CurrencyCoreTestSupport

@Suite("PillInteraction")
struct PillInteractionTests {
    @Test func hoverExpandsAndLeavingCollapses() {
        var state = PillInteraction()
        #expect(state.mode == .collapsed)
        state.handle(.hoverBegan)
        #expect(state.mode == .expanded)
        #expect(state.pauseReasons == [.hover])
        state.handle(.hoverEnded)
        #expect(state.mode == .collapsed)
        #expect(state.pauseReasons.isEmpty)
    }

    @Test func clickOpensDropdownAndClickAgainCloses() {
        var state = PillInteraction()
        state.handle(.hoverBegan)
        state.handle(.click)
        #expect(state.mode == .dropdown)
        #expect(state.pauseReasons == [.hover, .dropdown])
        state.handle(.click)
        #expect(state.mode == .expanded)   // still hovering
        #expect(state.pauseReasons == [.hover])
    }

    @Test func leavingDoesNotCloseOpenDropdown() {
        var state = PillInteraction()
        state.handle(.hoverBegan)
        state.handle(.click)
        state.handle(.hoverEnded)
        #expect(state.mode == .dropdown)
        #expect(state.pauseReasons == [.dropdown])
    }

    @Test(arguments: [PillEvent.clickOutside, .escape])
    func clickOutsideOrEscapeCloses(_ event: PillEvent) {
        var state = PillInteraction()
        state.handle(.hoverBegan)
        state.handle(.click)
        state.handle(.hoverEnded)
        state.handle(event)
        #expect(state.mode == .collapsed)
        #expect(state.pauseReasons.isEmpty)
    }

    @Test func escapeWhileHoveringReturnsToExpanded() {
        var state = PillInteraction()
        state.handle(.hoverBegan)
        state.handle(.click)
        state.handle(.escape)
        #expect(state.mode == .expanded)
    }

    @Test func clickWithoutHoverOpensAndClosesToCollapsed() {
        var state = PillInteraction()
        state.handle(.click)
        #expect(state.mode == .dropdown)
        state.handle(.click)
        #expect(state.mode == .collapsed)
    }

    @Test func outsideAndEscapeAreIgnoredWhenClosed() {
        var state = PillInteraction()
        let outsideChanged = state.handle(.clickOutside)
        let escapeChanged = state.handle(.escape)
        #expect(!outsideChanged && !escapeChanged)
        state.handle(.hoverBegan)
        let escapeWhileExpanded = state.handle(.escape)
        #expect(!escapeWhileExpanded)
        #expect(state.mode == .expanded)
    }

    @Test func handleReportsChanges() {
        var state = PillInteraction()
        let first = state.handle(.hoverBegan)
        let second = state.handle(.hoverBegan)
        #expect(first)
        #expect(!second)
    }

    @Test func pauseDiff() {
        let diff = PillInteraction.diff(from: [.hover], to: [.dropdown])
        #expect(diff.pause == [.dropdown])
        #expect(diff.resume == [.hover])
    }

    @Test func fullCycleDrivesRotationEnginePause() async {
        let engine = RotationEngine(codes: ["USD", "EUR"], interval: 5, sleeper: MockSleeper())
        var state = PillInteraction()
        func send(_ event: PillEvent) async {
            let before = state.pauseReasons
            state.handle(event)
            let diff = PillInteraction.diff(from: before, to: state.pauseReasons)
            for reason in diff.pause { await engine.pause(reason) }
            for reason in diff.resume { await engine.resume(reason) }
        }
        await send(.hoverBegan)
        #expect(await engine.snapshot.isPaused)
        await send(.click)
        await send(.hoverEnded)
        #expect(await engine.snapshot.pauseReasons == [.dropdown])
        await send(.clickOutside)
        #expect(!(await engine.snapshot.isPaused))
    }
}

@Suite("HoverDelay")
struct HoverDelayTests {
    @Test func enterReportsHoverAfterDelay() async throws {
        let sleeper = MockSleeper(immediateCount: 1)
        let hover = HoverDelay(sleeper: sleeper)
        await hover.mouseEntered()
        try await waitUntil { await hover.history == [true] }
        #expect(await sleeper.requestedDelays == [HoverDelay.enterDelay])
    }

    @Test func leavingBeforeEnterDelayNeverExpands() async throws {
        let sleeper = MockSleeper(immediateCount: 0)
        let hover = HoverDelay(sleeper: sleeper)
        await hover.mouseEntered()
        try await waitUntil { await sleeper.requestedDelays.count == 1 }
        await hover.mouseExited()
        try await Task.sleep(for: .milliseconds(50))
        #expect(await hover.history.isEmpty)
    }

    @Test func reenteringBeforeExitDelayNeverCollapses() async throws {
        let sleeper = MockSleeper(immediateCount: 1)
        let hover = HoverDelay(sleeper: sleeper)
        await hover.mouseEntered()
        try await waitUntil { await hover.history == [true] }
        await hover.mouseExited()
        try await waitUntil { await sleeper.requestedDelays.count == 2 }
        #expect(await sleeper.requestedDelays.last == HoverDelay.exitDelay)
        await hover.mouseEntered()
        try await Task.sleep(for: .milliseconds(50))
        #expect(await hover.history == [true])
    }

    @Test func leavingAfterHoverReportsEnd() async throws {
        let sleeper = MockSleeper(immediateCount: 2)
        let hover = HoverDelay(sleeper: sleeper)
        await hover.mouseEntered()
        try await waitUntil { await hover.history == [true] }
        await hover.mouseExited()
        try await waitUntil { await hover.history == [true, false] }
    }

    @Test func delaysMatchSpec() {
        #expect(HoverDelay.enterDelay == 0.3)
        #expect(HoverDelay.exitDelay == 0.2)
    }
}

@Suite("PillLayout")
struct PillLayoutTests {
    let visible = CGRect(x: 0, y: 70, width: 1512, height: 887)   // maxY 957

    @Test func expandedGrowsAroundCenter() {
        let pill = CGRect(x: 656, y: 500, width: 200, height: 34)
        #expect(PillLayout.expandedFrame(collapsed: pill, in: visible) == CGRect(x: 616, y: 485, width: 280, height: 64))
    }

    @Test func expandedIsClampedAtEdges() {
        let topLeft = CGRect(x: 0, y: 923, width: 200, height: 34)
        #expect(PillLayout.expandedFrame(collapsed: topLeft, in: visible) == CGRect(x: 0, y: 893, width: 280, height: 64))
        let bottomRight = CGRect(x: 1312, y: 70, width: 200, height: 34)
        #expect(PillLayout.expandedFrame(collapsed: bottomRight, in: visible) == CGRect(x: 1232, y: 70, width: 280, height: 64))
    }

    @Test func expandedOnNegativeCoordinateDisplay() {
        let left = CGRect(x: -1920, y: -300, width: 1920, height: 1055)
        let pill = CGRect(x: -1920, y: -300, width: 200, height: 34)
        #expect(PillLayout.expandedFrame(collapsed: pill, in: left).origin == CGPoint(x: -1920, y: -300))
    }

    @Test(arguments: [(0, CGFloat(44)), (1, 44), (8, 240), (10, 296), (25, 296)])
    func dropdownHeightCapsAtTenRows(rows: Int, expected: CGFloat) {
        #expect(PillLayout.dropdownHeight(rows: rows) == expected)
    }

    @Test func visibleRowsCap() {
        #expect(PillLayout.visibleRows(25) == 10)
        #expect(PillLayout.visibleRows(3) == 3)
    }

    @Test func dropdownOpensBelowNearTop() {
        let expanded = CGRect(x: 616, y: 893, width: 280, height: 64)
        let layout = PillLayout.dropdownLayout(expanded: expanded, rows: 8, in: visible)
        #expect(layout.direction == .below)
        // window = list (240) + gap (6) + pill (64), pill stays where it was
        #expect(layout.windowFrame == CGRect(x: 616, y: 893 - 6 - 240, width: 280, height: 310))
    }

    @Test func dropdownOpensAboveNearBottom() {
        let expanded = CGRect(x: 616, y: 100, width: 280, height: 64)
        let layout = PillLayout.dropdownLayout(expanded: expanded, rows: 8, in: visible)
        #expect(layout.direction == .above)
        #expect(layout.windowFrame == CGRect(x: 616, y: 100, width: 280, height: 310))
    }

    @Test func dropdownPicksSideWithMoreRoomWhenNeitherFits() {
        let short = CGRect(x: 0, y: 0, width: 800, height: 300)
        let nearTop = CGRect(x: 100, y: 200, width: 280, height: 64)
        let layout = PillLayout.dropdownLayout(expanded: nearTop, rows: 10, in: short)
        #expect(layout.direction == .below)
        #expect(short.contains(layout.windowFrame) || layout.windowFrame.minY == short.minY)
    }

    @Test func dropdownDirectionFunction() {
        let pill = CGRect(x: 0, y: 500, width: 280, height: 64)
        #expect(PillLayout.dropdownDirection(pill: pill, listHeight: 300, in: visible) == .below)
        let low = CGRect(x: 0, y: 200, width: 280, height: 64)
        #expect(PillLayout.dropdownDirection(pill: low, listHeight: 300, in: visible) == .above)
    }

    @Test func collapsedHomeFromDraggedExpandedFrame() {
        let expanded = CGRect(x: 300, y: 400, width: 280, height: 64)
        #expect(PillLayout.collapsedFrame(centeredIn: expanded) == CGRect(x: 340, y: 415, width: 200, height: 34))
    }
}

@Suite("RateRow")
struct RateRowTests {
    let builder = RateRowBuilder(formatter: RateFormatter(locale: Locale(identifier: "en_US")))

    func quote(_ code: String, _ value: String) -> RateQuote {
        RateQuote(quoteCode: code, baseCode: "ILS", value: dec(value), fetchedAt: Date(), source: "m")
    }

    func summary(_ percent: String?, _ direction: ChangeDirection, points: [String] = ["1", "2"]) -> ChangeSummary {
        ChangeSummary(state: percent == nil ? .collecting : .ready, percent: percent.map(dec), direction: direction,
                      points: points.map(dec))
    }

    @Test func upRowHasPlusSignAndUpDirection() {
        let row = builder.row(code: "USD", quote: quote("USD", "3.3429"), baseCode: "ILS", summary: summary("2.5", .up))
        #expect(row.valueText == "3.3429")
        #expect(row.symbol == "₪")
        #expect(row.change.text == "+2.50%")
        #expect(row.change.direction == .up)
        #expect(row.change.arrow == "▲")
    }

    @Test func downRowUsesMinusSign() {
        let row = builder.row(code: "BTC", quote: quote("BTC", "194557.83"), baseCode: "ILS", summary: summary("-25", .down))
        #expect(row.change.text == "−25.00%")
        #expect(row.change.arrow == "▼")
    }

    @Test func flatRow() {
        let row = builder.row(code: "EUR", quote: quote("EUR", "3.6"), baseCode: "ILS", summary: summary("0", .flat))
        #expect(row.change.text == "0.00%")
        #expect(row.change.arrow == "=")
    }

    @Test func collectingAndMissingSummaryHideChange() {
        let collecting = builder.row(code: "EUR", quote: quote("EUR", "3.6"), baseCode: "ILS", summary: .collecting)
        #expect(collecting.change.isCollecting)
        #expect(collecting.change.text == nil)
        #expect(collecting.change.sparkline.isEmpty)
        let none = builder.row(code: "EUR", quote: quote("EUR", "3.6"), baseCode: "ILS", summary: nil)
        #expect(none.change.isCollecting)
    }

    @Test func missingQuoteShowsDash() {
        let row = builder.row(code: "EUR", quote: nil, baseCode: "ILS", summary: nil)
        #expect(row.valueText == "—")
    }

    @Test func changeTextIsLocalized() {
        let ru = RateRowBuilder(formatter: RateFormatter(locale: Locale(identifier: "ru_RU")))
        #expect(ru.changeText(percent: dec("2.5")) == "+2,50%")
        let he = RateRowBuilder(formatter: RateFormatter(locale: Locale(identifier: "he_IL")))
        #expect(he.changeText(percent: dec("-1.2")) == "−1.20%")
    }

    @Test func sparklineNormalization() {
        #expect(RateRowBuilder.normalize([dec("10"), dec("15"), dec("20")]) == [0, 0.5, 1])
        #expect(RateRowBuilder.normalize([dec("3"), dec("3"), dec("3")]) == [0.5, 0.5, 0.5])
        #expect(RateRowBuilder.normalize([dec("7")]) == [0.5])
        #expect(RateRowBuilder.normalize([]) == [])
        let row = builder.row(code: "USD", quote: quote("USD", "3"), baseCode: "ILS",
                              summary: summary("1", .up, points: ["2", "4", "3"]))
        #expect(row.change.sparkline == [0, 1, 0.5])
    }

    @Test func icons() {
        #expect(builder.row(code: "USD", quote: nil, baseCode: "ILS", summary: nil).icon == .flag("🇺🇸"))
        #expect(builder.row(code: "BTC", quote: nil, baseCode: "ILS", summary: nil).icon == .systemSymbol("bitcoinsign"))
        guard case .monogram(let eth, _) = builder.row(code: "ETH", quote: nil, baseCode: "ILS", summary: nil).icon else {
            Issue.record("ETH should be a monogram"); return
        }
        #expect(eth == "Ξ")
        guard case .monogram(let sol, let hue) = builder.row(code: "SOL", quote: nil, baseCode: "ILS", summary: nil).icon else {
            Issue.record("SOL should be a monogram"); return
        }
        #expect(sol == "S")
        #expect((0..<1).contains(hue))
        // Hue is deterministic across runs (not Swift's randomized hashValue).
        #expect(CurrencyIcon.hue(for: "SOL") == hue)
        #expect(builder.row(code: "ZZZ", quote: nil, baseCode: "ILS", summary: nil).icon == .monogram("Z", hue: CurrencyIcon.hue(for: "ZZZ")))
    }

    @Test func relativeUpdatedText() {
        let now = Date(timeIntervalSince1970: 1_795_000_000)
        let en = RateRowBuilder.updatedAgo(now.addingTimeInterval(-300), now: now, locale: Locale(identifier: "en_US"))
        #expect(en == "5 min. ago")
        let he = RateRowBuilder.updatedAgo(now.addingTimeInterval(-300), now: now, locale: Locale(identifier: "he_IL"))
        #expect(he?.isEmpty == false && he != en)
        #expect(RateRowBuilder.updatedAgo(nil, now: now, locale: Locale(identifier: "en_US")) == nil)
    }
}
