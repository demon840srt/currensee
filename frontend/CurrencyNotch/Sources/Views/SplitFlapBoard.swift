import AppKit
import CurrencyCore
import SwiftUI

/// Airport-board text (SPEC F8) drawn with Core Animation: each character is a pair of `CATextLayer`s in a
/// fixed-width cell. On change, the old character folds away and the new one falls in, staggered over ≈ 0.4 s.
/// The animation runs in the render server, so the app does no per-frame work (ADR-0019).
/// With Reduce Motion on, the text crossfades in 0.25 s instead (SPEC F26).
struct SplitFlapBoard: NSViewRepresentable {
    let text: String
    var alignment: SplitFlapPlan.Alignment = .leading
    var minimumLength = 0
    let cellWidth: CGFloat
    var color: Color = .white
    /// Soft text shadow (Fire theme).
    var shadow: Color?

    func makeNSView(context: Context) -> SplitFlapBoardView {
        SplitFlapBoardView()
    }

    func updateNSView(_ view: SplitFlapBoardView, context: Context) {
        view.configure(cellWidth: cellWidth, alignment: alignment, minimumLength: minimumLength,
                       color: NSColor(color).cgColor)
        view.setShadow(shadow.map { NSColor($0).cgColor })
        view.show(text, style: TextTransitionStyle.style(reduceMotion: context.environment.accessibilityReduceMotion))
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: SplitFlapBoardView, context: Context) -> CGSize? {
        nsView.intrinsicContentSize
    }
}

final class SplitFlapBoardView: NSView {
    private struct Cell {
        let front: CATextLayer   // shows the current character
        let back: CATextLayer    // shows the previous character while it folds away
    }

    private var cells: [Cell] = []
    private var current = ""
    private var cellWidth: CGFloat = 8
    private var alignment: SplitFlapPlan.Alignment = .leading
    private var minimumLength = 0
    private var color = NSColor.white.cgColor
    private let font = PillFont.nsFont

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
        // Perspective for the flip.
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / 120
        layer?.sublayerTransform = perspective
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: CGFloat(max(cells.count, 1)) * cellWidth, height: ceil(font.ascender - font.descender))
    }

    func configure(cellWidth: CGFloat, alignment: SplitFlapPlan.Alignment, minimumLength: Int, color: CGColor) {
        let layoutChanged = cellWidth != self.cellWidth || alignment != self.alignment || minimumLength != self.minimumLength
        self.cellWidth = cellWidth
        self.alignment = alignment
        self.minimumLength = minimumLength
        if self.color != color {
            self.color = color
            cells.forEach { $0.front.foregroundColor = color; $0.back.foregroundColor = color }
        }
        if layoutChanged { rebuild(showing: current) }
    }

    func setShadow(_ color: CGColor?) {
        layer?.shadowColor = color
        layer?.shadowOpacity = color == nil ? 0 : 1
        layer?.shadowRadius = 1.5
        layer?.shadowOffset = CGSize(width: 0, height: -0.5)
    }

    func show(_ text: String, style: TextTransitionStyle) {
        setAccessibilityLabel(text)
        guard text != current else { return }
        let plan = SplitFlapPlan(from: current, to: text, alignment: alignment, minimumLength: minimumLength)
        let animate = !current.isEmpty && window != nil
        current = text
        guard plan.cellCount == cells.count, animate else {
            rebuild(showing: text)
            return
        }
        switch style {
        case .splitFlap: flip(plan)
        case .crossfade: crossfade(plan, duration: style.duration)
        }
    }

    // MARK: - Layers

    private func rebuild(showing text: String) {
        cells.forEach { $0.front.removeFromSuperlayer(); $0.back.removeFromSuperlayer() }
        let plan = SplitFlapPlan(from: text, to: text, alignment: alignment, minimumLength: minimumLength)
        cells = (0..<plan.cellCount).map { index in
            let front = makeTextLayer(index: index, character: plan.to[index])
            let back = makeTextLayer(index: index, character: plan.to[index])
            back.isHidden = true
            layer?.addSublayer(back)
            layer?.addSublayer(front)
            return Cell(front: front, back: back)
        }
        invalidateIntrinsicContentSize()
    }

    private func makeTextLayer(index: Int, character: Character) -> CATextLayer {
        let text = CATextLayer()
        text.font = font
        text.fontSize = font.pointSize
        text.foregroundColor = color
        text.alignmentMode = .center
        text.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        text.string = String(character)
        text.frame = CGRect(x: CGFloat(index) * cellWidth, y: 0, width: cellWidth, height: intrinsicContentSize.height)
        text.isDoubleSided = false
        text.actions = ["contents": NSNull(), "string": NSNull(), "transform": NSNull(), "hidden": NSNull()]
        return text
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        cells.forEach { $0.front.contentsScale = scale; $0.back.contentsScale = scale }
    }

    override func layout() {
        super.layout()
        let height = intrinsicContentSize.height
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, cell) in cells.enumerated() {
            let frame = CGRect(x: CGFloat(index) * cellWidth, y: (bounds.height - height) / 2, width: cellWidth, height: height)
            cell.front.frame = frame
            cell.back.frame = frame
        }
        CATransaction.commit()
    }

    // MARK: - Transitions

    /// Old face folds back (0 → 90°) in the first half, new face falls in (−90° → 0) in the second.
    private func flip(_ plan: SplitFlapPlan) {
        let half = SplitFlapPlan.flipDuration / 2
        let now = CACurrentMediaTime()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for index in plan.changedCells {
            let cell = cells[index]
            let delay = plan.delay(forCell: index)
            cell.back.string = String(plan.from[index])
            cell.back.isHidden = false
            cell.back.transform = CATransform3DMakeRotation(.pi / 2, 1, 0, 0)   // final: edge-on
            cell.front.string = String(plan.to[index])
            cell.front.transform = CATransform3DIdentity                        // final: facing

            let foldAway = CABasicAnimation(keyPath: "transform.rotation.x")
            foldAway.fromValue = 0
            foldAway.toValue = Double.pi / 2
            foldAway.beginTime = now + delay
            foldAway.duration = half
            foldAway.timingFunction = CAMediaTimingFunction(name: .easeIn)
            foldAway.fillMode = .backwards
            cell.back.add(foldAway, forKey: "flip")

            let fallIn = CABasicAnimation(keyPath: "transform.rotation.x")
            fallIn.fromValue = -Double.pi / 2
            fallIn.toValue = 0
            fallIn.beginTime = now + delay + half
            fallIn.duration = half
            fallIn.timingFunction = CAMediaTimingFunction(name: .easeOut)
            fallIn.fillMode = .backwards
            cell.front.add(fallIn, forKey: "flip")
        }
        CATransaction.commit()
    }

    private func crossfade(_ plan: SplitFlapPlan, duration: TimeInterval) {
        let fade = CATransition()
        fade.type = .fade
        fade.duration = duration
        layer?.add(fade, forKey: "crossfade")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for index in plan.changedCells {
            cells[index].front.string = String(plan.to[index])
            cells[index].front.transform = CATransform3DIdentity
            cells[index].back.isHidden = true
        }
        CATransaction.commit()
    }
}
