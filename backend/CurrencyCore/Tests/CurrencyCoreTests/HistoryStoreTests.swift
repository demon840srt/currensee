import Foundation
import Testing
@testable import CurrencyCore
import CurrencyCoreTestSupport

@Suite("HistoryStore")
struct HistoryStoreTests {
    let clock = TestClock(utcDay(2026, 11, 20, hour: 12))

    func quote(_ code: String = "USD", _ value: String, at date: Date? = nil) -> RateQuote {
        RateQuote(quoteCode: code, baseCode: "ILS", value: dec(value), fetchedAt: date ?? clock.now, source: "m")
    }

    func point(_ code: String = "USD", _ value: String, day: Date) -> HistoryPoint {
        HistoryPoint(quoteCode: code, baseCode: "ILS", timestamp: day, value: dec(value))
    }

    @Test func snapshotsAreDownsampledTo15MinuteBuckets() async {
        let store = HistoryStore(cache: nil, now: clock.provider)
        let start = utcDay(2026, 11, 20, hour: 12)
        for (minute, value) in [(0, "3.70"), (5, "3.71"), (14, "3.72"), (15, "3.73"), (31, "3.74")] {
            clock.set(start.addingTimeInterval(TimeInterval(minute * 60)))
            await store.record([quote("USD", value)])
        }
        let points = await store.intradayPoints(quote: "USD", base: "ILS")
        #expect(points.map(\.value) == [dec("3.72"), dec("3.73"), dec("3.74")])   // last value per bucket
        #expect(points.map(\.timestamp) == [start, start.addingTimeInterval(900), start.addingTimeInterval(1800)])
    }

    @Test func intradayKeeps48HoursAndDailyKeeps35Days() async {
        let store = HistoryStore(cache: nil, now: clock.provider)
        clock.set(utcDay(2026, 11, 1))
        await store.record([quote("USD", "3.6")])
        await store.mergeDaily([point("USD", "3.5", day: utcDay(2026, 10, 1)),
                                point("USD", "3.55", day: utcDay(2026, 10, 20))])
        clock.set(utcDay(2026, 11, 20, hour: 12))
        await store.record([quote("USD", "3.7")])
        await store.mergeDaily([point("USD", "3.69", day: utcDay(2026, 11, 19))])
        #expect(await store.intradayPoints(quote: "USD", base: "ILS").map(\.value) == [dec("3.7")])
        #expect(await store.dailyPoints(quote: "USD", base: "ILS").map(\.timestamp) ==
                [utcDay(2026, 10, 20), utcDay(2026, 11, 19)])
    }

    @Test func mergeDailyReplacesSameDayAndSorts() async {
        let store = HistoryStore(cache: nil, now: clock.provider)
        await store.mergeDaily([point("USD", "3.6", day: utcDay(2026, 11, 18)),
                                point("USD", "3.5", day: utcDay(2026, 11, 10))])
        await store.mergeDaily([point("USD", "3.65", day: utcDay(2026, 11, 18))])
        let values = await store.dailyPoints(quote: "USD", base: "ILS").map(\.value)
        #expect(values == [dec("3.5"), dec("3.65")])
    }

    @Test func sevenDayChangeAndSparkline() async {
        let store = HistoryStore(cache: nil, now: clock.provider)
        let days = (13...19).map { utcDay(2026, 11, $0) }
        await store.mergeDaily(zip(days, ["3.50", "3.52", "3.55", "3.51", "3.60", "3.58", "3.62"]).map {
            point("USD", $1, day: $0)
        })
        await store.mergeDaily([point("USD", "3.00", day: utcDay(2026, 11, 1))])   // outside 7d
        let s = await store.summary(quote: "USD", base: "ILS", range: .d7, current: dec("3.85"))
        #expect(s.state == .ready)
        #expect(s.points.first == dec("3.50"))
        #expect(s.points.last == dec("3.85"))
        #expect(s.points.count == 8)
        #expect(s.percent == dec("10"))   // (3.85 - 3.50) / 3.50 = +10.00%
        #expect(s.direction == .up)
    }

    @Test func thirtyDayDownChange() async {
        let store = HistoryStore(cache: nil, now: clock.provider)
        await store.mergeDaily([point("BTC", "400000", day: utcDay(2026, 10, 22)),
                                point("BTC", "350000", day: utcDay(2026, 11, 10))])
        let s = await store.summary(quote: "BTC", base: "ILS", range: .d30, current: dec("300000"))
        #expect(s.percent == dec("-25"))
        #expect(s.direction == .down)
    }

    @Test func percentIsRoundedToTwoDecimalsAndFlatWhenUnchanged() async {
        let store = HistoryStore(cache: nil, now: clock.provider)
        await store.mergeDaily([point("EUR", "3", day: utcDay(2026, 11, 19))])
        let up = await store.summary(quote: "EUR", base: "ILS", range: .d7, current: dec("3.1"))
        #expect(up.percent == dec("3.33"))
        let flat = await store.summary(quote: "EUR", base: "ILS", range: .d7, current: dec("3.0001"))
        #expect(flat.percent == dec("0"))
        #expect(flat.direction == .flat)
    }

    @Test func twentyFourHourUsesSnapshotsSeededByYesterday() async {
        let store = HistoryStore(cache: nil, now: clock.provider)
        await store.mergeDaily([point("USD", "3.60", day: utcDay(2026, 11, 19))])   // 36 h before now
        clock.set(utcDay(2026, 11, 20, hour: 10))
        await store.record([quote("USD", "3.65")])
        clock.set(utcDay(2026, 11, 20, hour: 12))
        await store.record([quote("USD", "3.66")])
        let s = await store.summary(quote: "USD", base: "ILS", range: .h24, current: dec("3.69"))
        #expect(s.state == .ready)
        #expect(s.points == [dec("3.60"), dec("3.65"), dec("3.66"), dec("3.69")])
        #expect(s.percent == dec("2.5"))
    }

    @Test func twentyFourHourWithoutSeedWhenSnapshotsCoverTheDay() async {
        let store = HistoryStore(cache: nil, now: clock.provider)
        await store.mergeDaily([point("USD", "3.60", day: utcDay(2026, 11, 19))])
        clock.set(utcDay(2026, 11, 19, hour: 13))
        await store.record([quote("USD", "3.62")])
        clock.set(utcDay(2026, 11, 20, hour: 12))
        let s = await store.summary(quote: "USD", base: "ILS", range: .h24, current: dec("3.70"))
        #expect(s.points.first == dec("3.62"))
    }

    @Test func collectingWhenNotEnoughData() async {
        let store = HistoryStore(cache: nil, now: clock.provider)
        let none = await store.summary(quote: "USD", base: "ILS", range: .h24, current: dec("3.7"))
        #expect(none.state == .collecting)
        #expect(none.percent == nil)
        let noCurrent = await store.summary(quote: "USD", base: "ILS", range: .d7, current: nil)
        #expect(noCurrent.state == .collecting)
    }

    @Test func sparklineIsCappedAt48PointsAndKeepsEnds() async {
        let store = HistoryStore(cache: nil, now: clock.provider)
        let start = clock.now.addingTimeInterval(-23 * 3600)
        for i in 0..<92 {
            clock.set(start.addingTimeInterval(TimeInterval(i * 900)))
            await store.record([quote("USD", "\(3 + Double(i) / 100)")])
        }
        let s = await store.summary(quote: "USD", base: "ILS", range: .h24, current: dec("9"))
        #expect(s.points.count == HistoryStore.maxSparklinePoints)
        #expect(s.points.first == dec("3"))
        #expect(s.points.last == dec("9"))
    }

    @Test func dailyRefreshDueOncePerUTCDayWithHourlyRetryAfterFailure() async {
        let store = HistoryStore(cache: nil, now: clock.provider)
        #expect(await store.needsDailyRefresh(quote: "USD", base: "ILS"))
        await store.markDailyFetched(quote: "USD", base: "ILS")
        clock.advance(by: 6 * 3600)
        #expect(!(await store.needsDailyRefresh(quote: "USD", base: "ILS")))
        clock.set(utcDay(2026, 11, 21, hour: 0))
        #expect(await store.needsDailyRefresh(quote: "USD", base: "ILS"))
        await store.markDailyAttemptFailed(quote: "USD", base: "ILS")
        clock.advance(by: 1800)
        #expect(!(await store.needsDailyRefresh(quote: "USD", base: "ILS")))
        clock.advance(by: 1801)
        #expect(await store.needsDailyRefresh(quote: "USD", base: "ILS"))
    }

    @Test func missingRangeStartsAfterLastStoredDay() async {
        let store = HistoryStore(cache: nil, now: clock.provider)
        let fresh = await store.missingDailyRange(quote: "USD", base: "ILS")
        #expect(fresh?.from == utcDay(2026, 10, 20))   // 31 days back
        #expect(fresh?.to == utcDay(2026, 11, 19))     // yesterday
        await store.mergeDaily([point("USD", "3.6", day: utcDay(2026, 11, 15))])
        let gap = await store.missingDailyRange(quote: "USD", base: "ILS")
        #expect(gap?.from == utcDay(2026, 11, 16))
        await store.mergeDaily([point("USD", "3.6", day: utcDay(2026, 11, 19))])
        #expect(await store.missingDailyRange(quote: "USD", base: "ILS") == nil)
    }

    @Test func persistsAndReloads() async throws {
        await withTempDirectory { dir in
            let cache = DiskCache(directory: dir)
            let store = HistoryStore(cache: cache, now: clock.provider)
            await store.record([quote("USD", "3.7")])
            await store.mergeDaily([point("USD", "3.6", day: utcDay(2026, 11, 19))])
            await store.markDailyFetched(quote: "USD", base: "ILS")

            let reloaded = HistoryStore(cache: cache, now: clock.provider)
            await reloaded.load()
            #expect(await reloaded.intradayPoints(quote: "USD", base: "ILS").count == 1)
            #expect(await reloaded.dailyPoints(quote: "USD", base: "ILS").count == 1)
            #expect(!(await reloaded.needsDailyRefresh(quote: "USD", base: "ILS")))
        }
    }

    @Test func seriesAreSeparatedByBase() async {
        let store = HistoryStore(cache: nil, now: clock.provider)
        await store.record([quote("EUR", "4.0"),
                            RateQuote(quoteCode: "EUR", baseCode: "USD", value: dec("1.08"), fetchedAt: clock.now, source: "m")])
        #expect(await store.intradayPoints(quote: "EUR", base: "ILS").map(\.value) == [dec("4.0")])
        #expect(await store.intradayPoints(quote: "EUR", base: "USD").map(\.value) == [dec("1.08")])
    }
}
