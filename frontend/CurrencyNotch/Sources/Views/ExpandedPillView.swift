import CurrencyCore
import SwiftUI

/// Hover state (≈ 280×64): icon, code, rate, change % for the selected range and a sparkline (SPEC F11).
struct ExpandedPillView: View {
    let model: AppModel
    @Environment(\.pillTheme) private var theme

    var body: some View {
        if let row = model.currentRow {
            HStack(spacing: 10) {
                CurrencyIconView(icon: row.icon, size: 26)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(verbatim: row.code)
                        Text(verbatim: "\(row.valueText) \(row.symbol)")
                        StaleDot(isStale: model.isStale)
                    }
                    .font(PillFont.swiftUI)
                    .foregroundStyle(Color(theme.text))
                    secondLine(row)
                        .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                }
                Spacer(minLength: 4)
                SparklineView(points: row.change.sparkline, color: theme.changeColor(row.change.direction))
                    .frame(width: 64, height: 26)
            }
            .lineLimit(1)
            .padding(.horizontal, 18)
            .shadow(color: theme.textShadow.map { Color($0) } ?? .clear, radius: 1.5, y: 0.5)
        } else {
            Text(verbatim: RateFormatter.missingValue).font(PillFont.swiftUI).foregroundStyle(Color(theme.text))
        }
    }

    @ViewBuilder
    private func secondLine(_ row: RateRow) -> some View {
        if let freshness = model.freshnessText {
            Text(freshness).foregroundStyle(Color(theme.warning))
        } else if let change = row.change.text {
            Text(verbatim: "\(row.change.arrow) \(change)").foregroundStyle(theme.changeColor(row.change.direction))
        } else {
            Text("Collecting…").foregroundStyle(Color(theme.secondaryText))
        }
    }
}

struct CurrencyIconView: View {
    let icon: CurrencyIcon
    let size: CGFloat

    var body: some View {
        Group {
            switch icon {
            case .flag(let emoji):
                Text(verbatim: emoji).font(.system(size: size * 0.8))
            case .systemSymbol(let name):
                Image(systemName: name)
                    .font(.system(size: size * 0.55, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color.orange))
            case .monogram(let letter, let hue):
                Text(verbatim: letter)
                    .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color(hue: hue, saturation: 0.55, brightness: 0.75)))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Mini line chart of normalized points (0…1, oldest → newest).
struct SparklineView: View {
    let points: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            if points.count >= 2 {
                Path { path in
                    for (index, value) in points.enumerated() {
                        let x = geo.size.width * CGFloat(index) / CGFloat(points.count - 1)
                        let y = geo.size.height * (1 - CGFloat(value))
                        index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}
