import Foundation

public enum ThemeAppearance: String, Sendable, CaseIterable {
    case light, dark
}

public struct GradientStop: Sendable, Hashable {
    public let color: RGBA
    /// 0 = top, 1 = bottom.
    public let location: Double

    public init(_ hex: String, _ location: Double) {
        color = RGBA(hex: hex)
        self.location = location
    }
}

public enum ThemeBackground: Sendable, Hashable {
    case solid(RGBA)
    /// Top → bottom.
    case linearGradient([GradientStop])
    /// Israel: body color, two horizontal stripes inset from top and bottom, Star of David watermark.
    case stripes(body: RGBA, stripe: RGBA, stripeFraction: Double, watermarkOpacity: Double)
    /// Liquid Glass (`glassEffect`); `tints` approximate the material for contrast checks.
    case glass(tints: [RGBA])

    /// Color at vertical position `t` (0 = top, 1 = bottom), ignoring stripes/watermark detail.
    func color(at t: Double) -> RGBA {
        switch self {
        case .solid(let color):
            return color
        case .linearGradient(let stops):
            guard let first = stops.first, let last = stops.last else { return .black }
            if t <= first.location { return first.color }
            for (a, b) in zip(stops, stops.dropFirst()) where t <= b.location {
                let span = b.location - a.location
                return a.color.mixed(with: b.color, span > 0 ? (t - a.location) / span : 0)
            }
            return last.color
        case .stripes(let body, _, _, _):
            return body
        case .glass(let tints):
            return tints.first ?? .white
        }
    }

    /// Every color that can sit behind text in the band `range` (for contrast checks).
    func backdrops(in range: ClosedRange<Double>, samples: Int = 13) -> [RGBA] {
        switch self {
        case .solid(let color):
            return [color]
        case .linearGradient:
            return (0..<samples).map { color(at: range.lowerBound + (range.upperBound - range.lowerBound) * Double($0) / Double(samples - 1)) }
        case .stripes(let body, let stripe, _, let watermark):
            // Text sits between the stripes, over the body and the faint watermark.
            return [body, stripe.withAlpha(watermark).composited(over: body)]
        case .glass(let tints):
            return tints
        }
    }
}

public enum ParticleKind: String, Sendable, Hashable {
    case snow, sparks, sparkles
}

public enum ParticleDirection: String, Sendable, Hashable {
    case down, up, drift
}

/// `CAEmitterLayer` settings (ADR-0006, references/themes.md). Sizes in points, speeds in points/second.
public struct ParticleSpec: Sendable, Hashable {
    public let kind: ParticleKind
    public let colors: [RGBA]
    public let size: ClosedRange<Double>
    public let birthRate: Double
    public let speed: ClosedRange<Double>
    public let direction: ParticleDirection
    public let lifetime: Double
    /// Radians per second.
    public let spin: Double
    /// Particles fade out over their lifetime.
    public let fadesOut: Bool
    public let glow: RGBA?
}

public enum ThemeEffect: Sendable, Hashable {
    /// Slow highlight sweeping along the rim.
    case rimShimmer(period: Double)
    /// Background brightness flicker ± `amount` at irregular intervals.
    case emberFlicker(amount: Double, minInterval: Double, maxInterval: Double)
    /// Waving highlight across the stripes.
    case stripeShimmer(period: Double)
}

/// Everything needed to draw one theme. Colors meet WCAG AA against every backdrop (ADR-0019).
public struct ThemeSpec: Sendable, Hashable {
    public let id: ThemeID
    /// Only Frosted Glass varies with light/dark appearance; nil for the others.
    public let appearance: ThemeAppearance?
    public let pillBackground: ThemeBackground
    public let listBackground: ThemeBackground
    public let rim: RGBA?
    public let text: RGBA
    public let secondaryText: RGBA
    public let up: RGBA
    public let down: RGBA
    public let flat: RGBA
    /// "Updated … ago" / offline text.
    public let warning: RGBA
    public let textShadow: RGBA?
    public let particles: ParticleSpec?
    public let effects: [ThemeEffect]

    public var hasEffects: Bool { particles != nil || !effects.isEmpty }

    /// Vertical band of the pill where text sits (both lines of the expanded pill).
    public static let textBand: ClosedRange<Double> = 0.2...0.8

    /// Colors behind text: the pill's text band plus the whole dropdown list.
    public var textBackdrops: [RGBA] {
        pillBackground.backdrops(in: Self.textBand) + listBackground.backdrops(in: 0...1)
    }

    public var textRoles: [(String, RGBA)] {
        [("primary", text), ("secondary", secondaryText), ("up", up), ("down", down), ("flat", flat), ("warning", warning)]
    }
}

extension ThemeSpec: CustomStringConvertible {
    public var description: String { appearance.map { "\(id.rawValue)-\($0.rawValue)" } ?? id.rawValue }
}
