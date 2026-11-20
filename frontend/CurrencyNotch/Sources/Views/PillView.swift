import CurrencyCore
import SwiftUI

/// Collapsed pill content. Phase 4: the first watch-list rate, statically. Phase 5 adds rotation,
/// split-flap and proper locale formatting.
struct PillView: View {
    let model: AppModel

    var body: some View {
        ZStack {
            Capsule().fill(Color.black)
            HStack(spacing: 6) {
                if let code = model.displayedCode {
                    Text(verbatim: code)
                    Text(verbatim: valueText(for: code))
                } else {
                    Text(verbatim: "—")
                }
                if model.snapshot.status == .stale || model.snapshot.status == .offline {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                        .accessibilityLabel(Text("Rates are out of date"))
                }
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(Color.white)
            // Codes and numbers read left-to-right even in Hebrew (SPEC F31).
            .environment(\.layoutDirection, .leftToRight)
        }
        .frame(width: PillGeometry.collapsedSize.width, height: PillGeometry.collapsedSize.height)
    }

    private func valueText(for code: String) -> String {
        guard let quote = model.snapshot.quotes[code] else { return "—" }
        let decimals = model.catalog.currency(for: code)?.decimals ?? 4
        let number = quote.value.formatted(.number.precision(.fractionLength(decimals)).grouping(.never))
        let symbol = model.catalog.currency(for: model.snapshot.baseCode)?.symbol ?? model.snapshot.baseCode
        return "\(number) \(symbol)"
    }
}
