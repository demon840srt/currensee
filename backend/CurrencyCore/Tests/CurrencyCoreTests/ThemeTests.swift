import Foundation
import Testing
@testable import CurrencyCore

@Suite("Contrast")
struct ContrastTests {
    @Test func formulaMatchesWCAGReferencePoints() {
        #expect(abs(Contrast.ratio(RGBA(hex: "#000000"), RGBA(hex: "#FFFFFF")) - 21) < 0.01)
        #expect(Contrast.ratio(RGBA(hex: "#777777"), RGBA(hex: "#777777")) == 1)
        // Order doesn't matter.
        #expect(Contrast.ratio(RGBA(hex: "#0038B8"), .white) == Contrast.ratio(.white, RGBA(hex: "#0038B8")))
        // Known value: #767676 on white is the classic 4.54:1 AA threshold color.
        #expect(abs(Contrast.ratio(RGBA(hex: "#767676"), .white) - 4.54) < 0.01)
    }

    @Test func hexParsing() {
        #expect(RGBA(hex: "#FF8000") == RGBA(r: 1, g: 128.0 / 255, b: 0))
        #expect(RGBA(hex: "0038B8").b == 184.0 / 255)
    }

    @Test func alphaBlending() {
        let half = RGBA(hex: "#FFFFFF").withAlpha(0.5).composited(over: RGBA(hex: "#000000"))
        #expect(abs(half.r - 0.5) < 0.001 && half.a == 1)
    }
}

@Suite("ThemeRegistry")
struct ThemeRegistryTests {
    static let allSpecs: [ThemeSpec] = ThemeID.allCases.flatMap { id in
        ThemeAppearance.allCases.map { ThemeRegistry.spec(id, appearance: $0) }
    }

    @Test(arguments: ThemeID.allCases)
    func everyThemeResolves(_ id: ThemeID) {
        #expect(ThemeRegistry.spec(id, appearance: .light).id == id)
        #expect(ThemeRegistry.spec(id, appearance: .dark).id == id)
    }

    @Test func particleThemesMatchSpec() {
        let withParticles = ThemeID.allCases.filter { ThemeRegistry.spec($0, appearance: .dark).particles != nil }
        #expect(withParticles == [.ice, .fire, .israel])
        #expect(ThemeRegistry.spec(.ice, appearance: .dark).particles?.kind == .snow)
        #expect(ThemeRegistry.spec(.fire, appearance: .dark).particles?.kind == .sparks)
        #expect(ThemeRegistry.spec(.israel, appearance: .dark).particles?.kind == .sparkles)
    }

    @Test(arguments: [ThemeID.ice, .fire, .israel])
    func particleSettingsAreValid(_ id: ThemeID) throws {
        let p = try #require(ThemeRegistry.spec(id, appearance: .dark).particles)
        #expect(p.birthRate > 0 && p.lifetime > 0)
        #expect(p.size.lowerBound > 0 && p.size.lowerBound <= p.size.upperBound)
        #expect(p.speed.lowerBound >= 0 && p.speed.lowerBound <= p.speed.upperBound)
        #expect(!p.colors.isEmpty)
    }

    @Test func effectsMatchSpec() {
        #expect(ThemeRegistry.spec(.ice, appearance: .dark).effects == [.rimShimmer(period: 4)])
        #expect(ThemeRegistry.spec(.fire, appearance: .dark).effects == [.emberFlicker(amount: 0.06, minInterval: 0.1, maxInterval: 0.4)])
        #expect(ThemeRegistry.spec(.israel, appearance: .dark).effects == [.stripeShimmer(period: 3)])
        #expect(ThemeRegistry.spec(.classicNotch, appearance: .dark).effects.isEmpty)
        #expect(ThemeRegistry.spec(.frostedGlass, appearance: .light).effects.isEmpty)
    }

    @Test func classicIsPureBlackAndIsraelUsesFlagBlue() {
        #expect(ThemeRegistry.spec(.classicNotch, appearance: .light).pillBackground == .solid(RGBA(hex: "#000000")))
        let israel = ThemeRegistry.spec(.israel, appearance: .light)
        guard case .stripes(let body, let stripe, let fraction, let watermark) = israel.pillBackground else {
            Issue.record("Israel should use stripes"); return
        }
        #expect(body == .white && stripe == RGBA(hex: "#0038B8"))
        #expect(fraction == 0.12 && watermark == 0.06)
    }

    @Test func onlyGlassDependsOnAppearance() {
        for id in ThemeID.allCases where id != .frostedGlass {
            #expect(ThemeRegistry.spec(id, appearance: .light) == ThemeRegistry.spec(id, appearance: .dark))
        }
        #expect(ThemeRegistry.spec(.frostedGlass, appearance: .light) != ThemeRegistry.spec(.frostedGlass, appearance: .dark))
    }

    /// SPEC F27: every text role ≥ 4.5:1 against every background color behind text (pill text band and list).
    @Test(arguments: allSpecs)
    func textContrastIsAtLeastAA(_ spec: ThemeSpec) {
        #expect(!spec.textBackdrops.isEmpty)
        for (role, color) in spec.textRoles {
            let worst = spec.textBackdrops.map { Contrast.ratio(color, $0) }.min() ?? 0
            #expect(worst >= 4.5, "\(spec.id) \(spec.appearance) \(role): \(worst)")
        }
    }

    @Test func gradientSamplingCoversTextBand() {
        let fire = ThemeRegistry.spec(.fire, appearance: .dark)
        // The bright amber stop sits below the text band, so it must not appear among the backdrops.
        #expect(!fire.textBackdrops.contains(RGBA(hex: "#FFC24A")))
        #expect(fire.textBackdrops.count >= 10)
    }
}

@Suite("EffectsPolicy")
struct EffectsPolicyTests {
    let ice = ThemeRegistry.spec(.ice, appearance: .dark)
    let calm = EffectsEnvironment(reduceMotion: false, onBattery: false, lowPowerMode: false, occluded: false)

    func reasons(_ spec: ThemeSpec? = nil, pauseOnBattery: Bool = true,
                 _ change: (inout EffectsEnvironment) -> Void = { _ in }) -> Set<EffectsPauseReason> {
        var env = calm
        change(&env)
        return EffectsPolicy.pauseReasons(theme: spec ?? ice, pauseOnBattery: pauseOnBattery, environment: env)
    }

    @Test func runsWhenNothingStopsIt() {
        #expect(reasons().isEmpty)
        #expect(EffectsPolicy.shouldRun(theme: ice, pauseOnBattery: true, environment: calm))
    }

    @Test func reduceMotionAlwaysPauses() {
        #expect(reasons { $0.reduceMotion = true } == [.reduceMotion])
        #expect(reasons(pauseOnBattery: false) { $0.reduceMotion = true } == [.reduceMotion])
    }

    @Test func batteryPausesOnlyWhenSettingIsOn() {
        #expect(reasons(pauseOnBattery: true) { $0.onBattery = true } == [.battery])
        #expect(reasons(pauseOnBattery: false) { $0.onBattery = true }.isEmpty)
    }

    @Test func lowPowerModePausesOnlyWhenSettingIsOn() {
        #expect(reasons(pauseOnBattery: true) { $0.lowPowerMode = true } == [.lowPowerMode])
        #expect(reasons(pauseOnBattery: false) { $0.lowPowerMode = true }.isEmpty)
    }

    @Test func occludedPauses() {
        #expect(reasons { $0.occluded = true } == [.occluded])
        #expect(reasons(pauseOnBattery: false) { $0.occluded = true } == [.occluded])
    }

    @Test func themesWithoutEffectsNeverRun() {
        for id in [ThemeID.classicNotch, .frostedGlass] {
            let spec = ThemeRegistry.spec(id, appearance: .light)
            #expect(reasons(spec) == [.noEffects])
            #expect(!EffectsPolicy.shouldRun(theme: spec, pauseOnBattery: false, environment: calm))
        }
    }

    @Test func multipleReasonsAndResume() {
        var env = calm
        env.onBattery = true
        env.occluded = true
        #expect(EffectsPolicy.pauseReasons(theme: ice, pauseOnBattery: true, environment: env) == [.battery, .occluded])
        env.onBattery = false
        #expect(EffectsPolicy.pauseReasons(theme: ice, pauseOnBattery: true, environment: env) == [.occluded])
        env.occluded = false
        #expect(EffectsPolicy.shouldRun(theme: ice, pauseOnBattery: true, environment: env))
    }
}
