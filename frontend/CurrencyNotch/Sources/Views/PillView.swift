import CurrencyCore
import SwiftUI

/// Collapsed pill: `CODE rate symbol` as a split-flap board, plus the stale dot (SPEC F10).
struct PillView: View {
    let model: AppModel

    var body: some View {
        let widths = model.boardWidths
        ZStack {
            Capsule().fill(Color.black)
            HStack(spacing: 5) {
                if let rate = model.collapsed {
                    SplitFlapText(text: rate.code, alignment: .leading, minimumLength: widths.code,
                                  cellWidth: PillFont.letterCell)
                    SplitFlapText(text: rate.value, alignment: .trailing, minimumLength: widths.value,
                                  cellWidth: PillFont.digitCell)
                    SplitFlapText(text: rate.symbol, minimumLength: widths.symbol, cellWidth: PillFont.symbolCell)
                } else {
                    Text(verbatim: RateFormatter.missingValue)
                }
                // Space is always reserved so the board doesn't shift when the dot appears.
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                    .opacity(model.isStale ? 1 : 0)
                    .accessibilityHidden(!model.isStale)
                    .accessibilityLabel(Text("Rates are out of date"))
            }
            .font(PillFont.swiftUI)
            .foregroundStyle(Color.white)
            .lineLimit(1)
            // Codes and numbers read left-to-right even in Hebrew (SPEC F31).
            .environment(\.layoutDirection, .leftToRight)
        }
        .frame(width: PillGeometry.collapsedSize.width, height: PillGeometry.collapsedSize.height)
    }
}
