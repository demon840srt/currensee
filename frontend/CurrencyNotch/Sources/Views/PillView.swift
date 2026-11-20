import CurrencyCore
import SwiftUI

/// Root of the pill window: the pill (collapsed board or expanded detail) plus, when open, the dropdown.
/// The window is resized by `PillPanelController`; this view animates the content inside it.
struct PillRootView: View {
    let model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = model.theme(for: colorScheme == .dark ? .dark : .light)
        let open = model.mode == .dropdown
        VStack(spacing: PillLayout.gap) {
            if open && model.dropdownDirection == .above { DropdownView(model: model).transition(listTransition) }
            pillSlot
            if open && model.dropdownDirection == .below { DropdownView(model: model).transition(listTransition) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: model.dropdownDirection == .below ? .top : .bottom)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: model.mode)
        .environment(\.pillTheme, theme)
        .environment(\.pillEffectsRunning, model.effectsRunning(for: theme))
        // Layout mirrors in RTL (SPEC F31); codes and numbers are isolated LTR where they're drawn.
    }

    private var listTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.9, anchor: model.dropdownDirection == .below ? .top : .bottom))
    }

    private var pillSlot: some View {
        let expanded = model.mode != .collapsed
        let size = expanded ? PillLayout.expandedSize : PillLayout.collapsedSize
        return ZStack {
            PillSurface(size: size)
            if expanded {
                ExpandedPillView(model: model).transition(.opacity)
            } else {
                CollapsedBoardView(model: model).transition(.opacity)
            }
        }
        .frame(width: model.slotSize.width, height: model.slotSize.height)
    }
}

/// The themed capsule behind the pill content.
struct PillSurface: View {
    let size: CGSize
    @Environment(\.pillTheme) private var theme

    var body: some View {
        ThemedSurface(background: theme.pillBackground, cornerRadius: size.height / 2)
            .frame(width: size.width, height: size.height)
    }
}

/// Collapsed content: `CODE rate symbol` as a split-flap board, plus the stale dot (SPEC F10).
struct CollapsedBoardView: View {
    let model: AppModel
    @Environment(\.pillTheme) private var theme

    var body: some View {
        let widths = model.boardWidths
        let textColor = Color(theme.text)
        let shadow = theme.textShadow.map { Color($0) }
        HStack(spacing: 5) {
            if let rate = model.collapsed {
                // RTL mirrors the container: [•] [3.3429 ₪] [USD]; each piece still reads left-to-right.
                SplitFlapBoard(text: rate.code, alignment: .leading, minimumLength: widths.code,
                               cellWidth: PillFont.letterCell, color: textColor, shadow: shadow)
                HStack(spacing: 5) {
                    SplitFlapBoard(text: rate.value, alignment: .trailing, minimumLength: widths.value,
                                   cellWidth: PillFont.digitCell, color: textColor, shadow: shadow)
                    SplitFlapBoard(text: rate.symbol, minimumLength: widths.symbol, cellWidth: PillFont.symbolCell,
                                   color: textColor, shadow: shadow)
                }
                .environment(\.layoutDirection, .leftToRight)
            } else {
                Text(verbatim: RateFormatter.missingValue).foregroundStyle(textColor)
            }
            StaleDot(isStale: model.isStale)
        }
        .font(PillFont.swiftUI)
        .lineLimit(1)
    }
}

struct StaleDot: View {
    let isStale: Bool
    @Environment(\.pillTheme) private var theme

    var body: some View {
        // Space is always reserved so content doesn't shift when the dot appears.
        Circle()
            .fill(Color(theme.warning))
            .frame(width: 6, height: 6)
            .opacity(isStale ? 1 : 0)
            .accessibilityHidden(!isStale)
            .accessibilityLabel(Text("Rates are out of date"))
    }
}
