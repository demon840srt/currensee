import CurrencyCore
import SwiftUI

/// Root of the pill window: the pill (collapsed board or expanded detail) plus, when open, the dropdown.
/// The window is resized by `PillPanelController`; this view animates the content inside it.
struct PillRootView: View {
    let model: AppModel

    var body: some View {
        let open = model.mode == .dropdown
        VStack(spacing: PillLayout.gap) {
            if open && model.dropdownDirection == .above { DropdownView(model: model).transition(listTransition) }
            pillSlot
            if open && model.dropdownDirection == .below { DropdownView(model: model).transition(listTransition) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: model.dropdownDirection == .below ? .top : .bottom)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: model.mode)
        // Codes and numbers read left-to-right even in Hebrew (SPEC F31); full RTL work is Phase 10.
        .environment(\.layoutDirection, .leftToRight)
    }

    private var listTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.9, anchor: model.dropdownDirection == .below ? .top : .bottom))
    }

    private var pillSlot: some View {
        let expanded = model.mode != .collapsed
        let size = expanded ? PillLayout.expandedSize : PillLayout.collapsedSize
        return ZStack {
            Capsule()
                .fill(Color.black)
                .frame(width: size.width, height: size.height)
            if expanded {
                ExpandedPillView(model: model).transition(.opacity)
            } else {
                CollapsedBoardView(model: model).transition(.opacity)
            }
        }
        .frame(width: model.slotSize.width, height: model.slotSize.height)
    }
}

/// Collapsed content: `CODE rate symbol` as a split-flap board, plus the stale dot (SPEC F10).
struct CollapsedBoardView: View {
    let model: AppModel

    var body: some View {
        let widths = model.boardWidths
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
            StaleDot(isStale: model.isStale)
        }
        .font(PillFont.swiftUI)
        .foregroundStyle(Color.white)
        .lineLimit(1)
    }
}

struct StaleDot: View {
    let isStale: Bool

    var body: some View {
        // Space is always reserved so content doesn't shift when the dot appears.
        Circle()
            .fill(Color.orange)
            .frame(width: 6, height: 6)
            .opacity(isStale ? 1 : 0)
            .accessibilityHidden(!isStale)
            .accessibilityLabel(Text("Rates are out of date"))
    }
}
