import CurrencyCore
import SwiftUI

extension Color {
    init(_ rgba: RGBA) {
        self.init(.sRGB, red: rgba.r, green: rgba.g, blue: rgba.b, opacity: rgba.a)
    }
}

extension EnvironmentValues {
    /// The active theme for the pill and dropdown.
    @Entry var pillTheme: ThemeSpec = ThemeRegistry.spec(.classicNotch, appearance: .dark)
    /// Whether particles and shimmer may run right now (`EffectsPolicy`).
    @Entry var pillEffectsRunning = false
}

extension ThemeSpec {
    func changeColor(_ direction: ChangeDirection) -> Color {
        switch direction {
        case .up: Color(up)
        case .down: Color(down)
        case .flat: Color(flat)
        }
    }
}

/// Theme background + rim + effects, clipped to `cornerRadius` (capsule when it's half the height).
struct ThemedSurface: View {
    let background: ThemeBackground
    let cornerRadius: CGFloat
    @Environment(\.pillTheme) private var theme
    @Environment(\.pillEffectsRunning) private var effectsRunning

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            fill(shape)
            if theme.hasEffects {
                ThemeEffectsLayer(spec: theme, background: background, cornerRadius: cornerRadius, running: effectsRunning)
            }
            if let rim = theme.rim {
                shape.strokeBorder(Color(rim), lineWidth: 1)
            }
        }
        .clipShape(shape)
    }

    @ViewBuilder
    private func fill(_ shape: RoundedRectangle) -> some View {
        switch background {
        case .solid(let color):
            shape.fill(Color(color))
        case .linearGradient(let stops):
            shape.fill(LinearGradient(stops: stops.map { .init(color: Color($0.color), location: $0.location) },
                                      startPoint: .top, endPoint: .bottom))
        case .stripes(let body, let stripe, let fraction, let watermark):
            ZStack {
                shape.fill(Color(body))
                StarOfDavid()
                    .stroke(Color(stripe).opacity(watermark), lineWidth: 2)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.vertical, 4)
                GeometryReader { geo in
                    let h = geo.size.height
                    let band = StripeGeometry.bands(height: h, fraction: fraction)
                    ForEach(band.indices, id: \.self) { index in
                        Rectangle()
                            .fill(Color(stripe))
                            .frame(height: band[index].height)
                            .offset(y: band[index].minY)
                    }
                }
            }
        case .glass:
            Color.clear.glassEffect(.regular, in: shape)
        }
    }
}

/// Israel stripes: two bands of `fraction` × height, inset from the edges and clear of the text band (20–80%).
enum StripeGeometry {
    static func bands(height: CGFloat, fraction: Double) -> [CGRect] {
        let h = height * fraction
        let inset = height * 0.04
        return [CGRect(x: 0, y: inset, width: 0, height: h),
                CGRect(x: 0, y: height - inset - h, width: 0, height: h)]
    }
}

/// Two overlapping equilateral triangles (watermark for the Israel theme).
struct StarOfDavid: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        func triangle(rotation: Double) -> Path {
            var path = Path()
            for i in 0..<3 {
                let angle = rotation + Double(i) * 2 * .pi / 3
                let point = CGPoint(x: c.x + r * cos(angle), y: c.y + r * sin(angle))
                i == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            path.closeSubpath()
            return path
        }
        var path = triangle(rotation: -.pi / 2)
        path.addPath(triangle(rotation: .pi / 2))
        return path
    }
}
