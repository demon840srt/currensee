import Foundation

/// The five themes (SPEC §5.7, references/themes.md). Colors adjusted where needed for 4.5:1 contrast (ADR-0019).
public enum ThemeRegistry {
    public static func spec(_ id: ThemeID, appearance: ThemeAppearance) -> ThemeSpec {
        switch id {
        case .ice: ice
        case .fire: fire
        case .israel: israel
        case .classicNotch: classic
        case .frostedGlass: appearance == .light ? glassLight : glassDark
        }
    }

    // MARK: - Ice

    static let ice = ThemeSpec(
        id: .ice, appearance: nil,
        // Deep blue only at the bottom edge, below the text.
        pillBackground: .linearGradient([GradientStop("#EAF7FF", 0), GradientStop("#C4E7FF", 0.55),
                                         GradientStop("#9FD8FF", 0.85), GradientStop("#5DB7F0", 1)]),
        listBackground: .solid(RGBA(hex: "#EAF7FF")),
        rim: RGBA(hex: "#FFFFFF", alpha: 0.7),
        text: RGBA(hex: "#0B2A44"), secondaryText: RGBA(hex: "#3A5870"),
        up: RGBA(hex: "#085C2D"), down: RGBA(hex: "#9E1F18"), flat: RGBA(hex: "#3A5870"),
        warning: RGBA(hex: "#7A3E00"), textShadow: nil,
        particles: ParticleSpec(kind: .snow, colors: [.white], size: 1.5...3, birthRate: 6, speed: 8...14,
                                direction: .down, lifetime: 5, spin: 1, fadesOut: false, glow: nil),
        effects: [.rimShimmer(period: 4)]
    )

    // MARK: - Fire

    static let fire = ThemeSpec(
        id: .fire, appearance: nil,
        // Deep red behind the text; the orange → amber glow is a thin band at the bottom edge.
        pillBackground: .linearGradient([GradientStop("#3A0603", 0), GradientStop("#7E150A", 0.45),
                                         GradientStop("#B3200E", 0.8), GradientStop("#FF7A1A", 0.92),
                                         GradientStop("#FFC24A", 1)]),
        listBackground: .linearGradient([GradientStop("#3A0603", 0), GradientStop("#4A0A05", 1)]),
        rim: nil,
        text: RGBA(hex: "#FFF6E5"), secondaryText: RGBA(hex: "#F5DCCB"),
        up: RGBA(hex: "#9CFF9C"), down: RGBA(hex: "#FFD1C9"), flat: RGBA(hex: "#F5DCCB"),
        warning: RGBA(hex: "#FFD27A"), textShadow: RGBA(hex: "#000000", alpha: 0.45),
        particles: ParticleSpec(kind: .sparks, colors: [RGBA(hex: "#FFB347"), RGBA(hex: "#FF6A00")], size: 1...2.5,
                                birthRate: 10, speed: 12...24, direction: .up, lifetime: 2.5, spin: 0,
                                fadesOut: true, glow: nil),
        effects: [.emberFlicker(amount: 0.06, minInterval: 0.1, maxInterval: 0.4)]
    )

    // MARK: - Israel

    static let flagBlue = RGBA(hex: "#0038B8")

    static let israel = ThemeSpec(
        id: .israel, appearance: nil,
        pillBackground: .stripes(body: .white, stripe: flagBlue, stripeFraction: 0.12, watermarkOpacity: 0.06),
        listBackground: .solid(.white),
        rim: nil,
        text: flagBlue, secondaryText: RGBA(hex: "#4C64A0"),
        up: RGBA(hex: "#0F7B3F"), down: RGBA(hex: "#B3261E"), flat: RGBA(hex: "#4C64A0"),
        warning: RGBA(hex: "#7A3E00"), textShadow: nil,
        particles: ParticleSpec(kind: .sparkles, colors: [flagBlue, .white], size: 1...2, birthRate: 5, speed: 2...6,
                                direction: .drift, lifetime: 4, spin: 0.5, fadesOut: true, glow: flagBlue),
        effects: [.stripeShimmer(period: 3)]
    )

    // MARK: - Classic Black Notch

    static let classic = ThemeSpec(
        id: .classicNotch, appearance: nil,
        pillBackground: .solid(.black), listBackground: .solid(.black), rim: nil,
        text: .white, secondaryText: RGBA(hex: "#B3B3B3"),
        up: RGBA(hex: "#30D158"), down: RGBA(hex: "#FF453A"), flat: RGBA(hex: "#999999"),
        warning: RGBA(hex: "#FF9F0A"), textShadow: nil, particles: nil, effects: []
    )

    // MARK: - Frosted Glass (follows light/dark appearance)

    static let glassLight = ThemeSpec(
        id: .frostedGlass, appearance: .light,
        pillBackground: .glass(tints: [RGBA(hex: "#E5E5EA"), RGBA(hex: "#F2F2F7")]),
        listBackground: .glass(tints: [RGBA(hex: "#E5E5EA"), RGBA(hex: "#F2F2F7")]),
        rim: nil,
        text: .black, secondaryText: RGBA(hex: "#3C3C43"),
        up: RGBA(hex: "#18692C"), down: RGBA(hex: "#A1241B"), flat: RGBA(hex: "#3C3C43"),
        warning: RGBA(hex: "#7A3E00"), textShadow: nil, particles: nil, effects: []
    )

    static let glassDark = ThemeSpec(
        id: .frostedGlass, appearance: .dark,
        pillBackground: .glass(tints: [RGBA(hex: "#2C2C2E"), RGBA(hex: "#3A3A3C")]),
        listBackground: .glass(tints: [RGBA(hex: "#2C2C2E"), RGBA(hex: "#3A3A3C")]),
        rim: nil,
        text: .white, secondaryText: RGBA(hex: "#AEAEB2"),
        up: RGBA(hex: "#30D158"), down: RGBA(hex: "#FF8A80"), flat: RGBA(hex: "#AEAEB2"),
        warning: RGBA(hex: "#FF9F0A"), textShadow: nil, particles: nil, effects: []
    )
}
