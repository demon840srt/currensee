import CurrencyCore
import SwiftUI

/// Airport-board text: each character sits in a fixed-width cell; on change, the cells that differ
/// flip (old half folds away, new character falls in), staggered over ≈ 0.4 s (SPEC F8).
/// With Reduce Motion on, the text crossfades in 0.25 s instead (SPEC F26).
struct SplitFlapText: View {
    let text: String
    var alignment: SplitFlapPlan.Alignment = .leading
    var minimumLength = 0
    let cellWidth: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var plan: SplitFlapPlan?
    @State private var generation = 0
    @State private var animateChanges = false

    var body: some View {
        let style = TextTransitionStyle.style(reduceMotion: reduceMotion)
        let current = plan ?? SplitFlapPlan(from: text, to: text, alignment: alignment, minimumLength: minimumLength)
        Group {
            switch style {
            case .splitFlap:
                HStack(spacing: 0) {
                    ForEach(0..<current.cellCount, id: \.self) { index in
                        let changed = animateChanges && current.changedCells.contains(index)
                        FlapCell(old: current.from[index], new: current.to[index],
                                 delay: current.delay(forCell: index), animate: changed)
                            .frame(width: cellWidth)
                            // A changed cell gets a new identity so it starts its flip from the old face.
                            .id(changed ? "\(generation)-\(index)" : "static-\(index)")
                    }
                }
            case .crossfade:
                ZStack {
                    cells(String(current.to))
                        .id(text)
                        .transition(.opacity)
                }
                .animation(.easeInOut(duration: style.duration), value: text)
            }
        }
        .onChange(of: text) { old, new in
            plan = SplitFlapPlan(from: old, to: new, alignment: alignment, minimumLength: minimumLength)
            animateChanges = true
            generation += 1
        }
        .onChange(of: minimumLength) {
            plan = SplitFlapPlan(from: text, to: text, alignment: alignment, minimumLength: minimumLength)
            animateChanges = false
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text))
    }

    private func cells(_ padded: String) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(padded.enumerated()), id: \.offset) { _, character in
                Text(String(character)).frame(width: cellWidth)
            }
        }
    }
}

/// One board cell. Starts showing `old` and, when `animate` is set, flips to `new` after `delay`.
private struct FlapCell: View {
    let old: Character
    let new: Character
    let delay: TimeInterval
    let animate: Bool

    @State private var progress: Double = 0

    var body: some View {
        FlapFace(old: old, new: new, progress: animate ? progress : 1)
            .onAppear {
                guard animate else { return }
                withAnimation(.easeInOut(duration: SplitFlapPlan.flipDuration).delay(delay)) {
                    progress = 1
                }
            }
    }
}

/// progress 0…0.5: old character folds back (0° → 90°); 0.5…1: new character falls in (−90° → 0°).
@Animatable
private struct FlapFace: View {
    @AnimatableIgnored var old: Character
    @AnimatableIgnored var new: Character
    var progress: Double

    var body: some View {
        let showingNew = progress >= 0.5
        let angle = showingNew ? (progress - 1) * 180 : progress * 180
        Text(String(showingNew ? new : old))
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
    }
}
