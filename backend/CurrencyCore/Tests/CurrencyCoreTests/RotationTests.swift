import Foundation
import Testing
@testable import CurrencyCore
import CurrencyCoreTestSupport

@Suite("RotationState")
struct RotationStateTests {
    @Test func rotatesInOrderAndWrapsAround() {
        var state = RotationState(codes: ["USD", "EUR", "BTC"], interval: 5)
        var seen = [state.currentCode]
        for _ in 0..<4 {
            state.advance()
            seen.append(state.currentCode)
        }
        #expect(seen == ["USD", "EUR", "BTC", "USD", "EUR"])
    }

    @Test func singleCodeNeverRotatesAndEmptyHasNoCode() {
        var one = RotationState(codes: ["USD"], interval: 5)
        #expect(!one.canRotate)
        let movedOne = one.advance()
        #expect(!movedOne)
        #expect(one.currentCode == "USD")
        var none = RotationState(codes: [], interval: 5)
        #expect(none.currentCode == nil)
        let movedNone = none.advance()
        #expect(!movedNone)
    }

    @Test(arguments: [(1.0, 3.0), (3.0, 3.0), (12.0, 12.0), (30.0, 30.0), (45.0, 30.0)])
    func intervalIsClamped(input: Double, expected: Double) {
        var state = RotationState(codes: ["USD", "EUR"], interval: input)
        #expect(state.interval == expected)
        state.setInterval(input)
        #expect(state.interval == expected)
    }

    @Test func pauseNeedsEveryReasonReleased() {
        var state = RotationState(codes: ["USD", "EUR"], interval: 5)
        state.pause(.hover)
        state.pause(.dropdown)
        #expect(state.isPaused)
        let movedWhilePaused = state.advance()
        #expect(!movedWhilePaused)
        state.resume(.hover)
        #expect(state.isPaused)
        state.resume(.dropdown)
        #expect(!state.isPaused)
        let movedAfterResume = state.advance()
        #expect(movedAfterResume)
        #expect(state.currentCode == "EUR")
    }

    @Test func editKeepsCurrentCodeWhenItMoves() {
        var state = RotationState(codes: ["USD", "EUR", "BTC"], interval: 5)
        state.advance()   // EUR
        state.setCodes(["BTC", "GBP", "USD", "EUR"])
        #expect(state.currentCode == "EUR")
        #expect(state.index == 3)
    }

    @Test func removingCurrentShowsTheOneThatTookItsPlace() {
        var state = RotationState(codes: ["USD", "EUR", "BTC"], interval: 5)
        state.advance()   // EUR at index 1
        state.setCodes(["USD", "BTC"])
        #expect(state.currentCode == "BTC")
    }

    @Test func shrinkingListKeepsIndexInRange() {
        var state = RotationState(codes: ["USD", "EUR", "BTC", "ETH"], interval: 5)
        state.advance(); state.advance(); state.advance()   // ETH at index 3
        state.setCodes(["USD"])
        #expect(state.currentCode == "USD")
        state.setCodes([])
        #expect(state.currentCode == nil)
        state.setCodes(["GBP", "JPY"])
        #expect(state.currentCode == "GBP")
    }

    @Test func replacingWholeListStaysValid() {
        var state = RotationState(codes: ["USD", "EUR", "BTC"], interval: 5)
        state.advance(); state.advance()   // BTC at 2
        state.setCodes(["CHF", "CNY", "JPY", "GBP"])
        #expect(state.currentCode == "JPY")
    }
}

@Suite("RotationEngine")
struct RotationEngineTests {
    @Test func ticksAdvanceThroughTheList() async throws {
        let sleeper = MockSleeper(immediateCount: 4)
        let engine = RotationEngine(codes: ["USD", "EUR", "BTC"], interval: 5, sleeper: sleeper)
        await engine.start()
        try await waitUntil { await sleeper.requestedDelays.count == 5 }   // 4 ticks done, 5th sleep pending
        #expect(await engine.currentCode == "EUR")                           // USD→EUR→BTC→USD→EUR
        #expect(await sleeper.requestedDelays.allSatisfy { $0 == 5 })
        await engine.stop()
    }

    @Test func pausedEngineDoesNotAdvance() async throws {
        let sleeper = MockSleeper(immediateCount: 3)
        let engine = RotationEngine(codes: ["USD", "EUR"], interval: 5, sleeper: sleeper)
        await engine.pause(.hover)
        await engine.start()
        try await waitUntil { await sleeper.requestedDelays.count == 4 }
        #expect(await engine.currentCode == "USD")
        await engine.stop()
    }

    @Test func resumeRestartsAFullIntervalWithoutFlipping() async throws {
        let sleeper = MockSleeper(immediateCount: 0)
        let engine = RotationEngine(codes: ["USD", "EUR"], interval: 7, sleeper: sleeper)
        await engine.start()
        try await waitUntil { await sleeper.requestedDelays.count == 1 }
        await engine.pause(.dropdown)
        await engine.resume(.dropdown)
        try await waitUntil { await sleeper.requestedDelays.count == 2 }   // timer restarted
        #expect(await engine.currentCode == "USD")                           // cancelled sleep didn't flip
        #expect(await sleeper.requestedDelays == [7, 7])
        await engine.stop()
    }

    @Test func intervalChangeAppliesToNextSleep() async throws {
        let sleeper = MockSleeper(immediateCount: 0)
        let engine = RotationEngine(codes: ["USD", "EUR"], interval: 5, sleeper: sleeper)
        await engine.start()
        try await waitUntil { await sleeper.requestedDelays.count == 1 }
        await engine.setInterval(12)
        try await waitUntil { await sleeper.requestedDelays.count == 2 }
        #expect(await sleeper.requestedDelays == [5, 12])
        await engine.stop()
    }

    @Test func listEditsPublishTheNewCurrentCode() async throws {
        let engine = RotationEngine(codes: ["USD", "EUR"], interval: 5, sleeper: MockSleeper())
        var iterator = engine.currentCodes.makeAsyncIterator()
        #expect(await iterator.next() == "USD")
        await engine.setCodes(["BTC", "ETH"])
        #expect(await iterator.next() == "BTC")
    }
}
