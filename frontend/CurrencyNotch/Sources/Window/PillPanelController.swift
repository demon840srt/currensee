import AppKit
import CurrencyCore

/// Owns the pill panel: restores its position, moves it on drag, saves it per display (SPEC F3–F6),
/// and resizes it for hover expand and the dropdown (SPEC F11–F15).
@MainActor
final class PillPanelController {
    /// Shrinking waits for the SwiftUI spring (0.35 s) so content never gets clipped.
    private static let shrinkDelay: Duration = .milliseconds(380)

    private let model: AppModel
    private let panel: PillPanel
    private let content: PillContentView
    /// The collapsed pill's frame: what drags move and what gets saved.
    private var homeFrame = CGRect(origin: .zero, size: PillLayout.collapsedSize)
    private var dragStartOrigin: CGPoint = .zero
    private var resizeGeneration = 0
    private var screenObserver: NSObjectProtocol?
    private var outsideClickMonitor: Any?

    init(model: AppModel, menuController: AppMenuController) {
        self.model = model
        content = PillContentView(rootView: PillRootView(model: model))
        panel = PillPanel(contentView: content)

        content.isLocked = { [weak model] in
            guard let model else { return false }
            return model.isPositionLocked || model.mode == .dropdown
        }
        content.contextMenu = { [weak menuController] in menuController?.makeMenu() }
        content.onClick = { [weak model] in model?.send(.click) }
        content.onPointerEntered = { [weak model] in model?.pointerEntered() }
        content.onPointerExited = { [weak model] in model?.pointerExited() }
        content.onDragBegan = { [weak self] in
            guard let self else { return }
            dragStartOrigin = panel.frame.origin
        }
        content.onDragMoved = { [weak self] offset in
            guard let self else { return }
            panel.setFrameOrigin(CGPoint(x: dragStartOrigin.x + offset.dx, y: dragStartOrigin.y + offset.dy))
        }
        content.onDragEnded = { [weak self] in self?.finishDrag() }
        panel.onEscape = { [weak model] in model?.send(.escape) }
        model.onModeChange = { [weak self] mode in self?.apply(mode) }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.restorePlacement() }
        }
    }

    func show() {
        restorePlacement()
        panel.orderFrontRegardless()
    }

    /// Launch and display changes. Does not overwrite the last-used display, so the pill returns
    /// to it when it's reconnected.
    func restorePlacement() {
        let resolved = PlacementResolver.resolve(
            placements: model.store.loadPlacements(),
            lastScreenID: model.store.loadLastScreenID(),
            screens: NSScreen.geometries,
            size: PillLayout.collapsedSize
        )
        homeFrame = CGRect(origin: resolved.origin, size: PillLayout.collapsedSize)
        apply(model.mode, immediately: true)
    }

    // MARK: - Resizing

    private var visibleFrame: CGRect {
        PlacementResolver.screen(containing: homeFrame, in: NSScreen.geometries)?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame ?? homeFrame
    }

    /// Grow the window at once (new area is transparent while SwiftUI animates in); shrink only after
    /// the content has animated out.
    private func apply(_ mode: PillMode, immediately: Bool = false) {
        resizeGeneration += 1
        let generation = resizeGeneration
        let target: CGRect
        switch mode {
        case .collapsed:
            target = homeFrame
        case .expanded:
            target = PillLayout.expandedFrame(collapsed: homeFrame, in: visibleFrame)
        case .dropdown:
            let expanded = PillLayout.expandedFrame(collapsed: homeFrame, in: visibleFrame)
            let layout = PillLayout.dropdownLayout(expanded: expanded, rows: model.watchList.orderedCodes.count,
                                                   in: visibleFrame)
            model.dropdownDirection = layout.direction
            model.listHeight = layout.listHeight
            target = layout.windowFrame
        }
        mode == .dropdown ? beginDropdownFocus() : endDropdownFocus()

        let current = panel.frame
        let shrinking = target.width < current.width || target.height < current.height
        if immediately || !shrinking {
            setWindow(target, mode: mode)
        } else {
            Task { [weak self] in
                try? await Task.sleep(for: Self.shrinkDelay)
                guard let self, generation == resizeGeneration else { return }
                setWindow(target, mode: mode)
            }
        }
    }

    private func setWindow(_ frame: CGRect, mode: PillMode) {
        panel.setFrame(frame, display: true)
        let slot = mode == .collapsed ? PillLayout.collapsedSize : PillLayout.expandedSize
        model.slotSize = slot
        if mode != .dropdown { model.dropdownDirection = .below }
        // Pill area inside the window (AppKit coordinates: origin bottom-left).
        let pillY = mode == .dropdown && model.dropdownDirection == .below ? frame.height - slot.height : 0
        content.pillRect = mode == .dropdown ? CGRect(x: 0, y: pillY, width: frame.width, height: slot.height) : nil
    }

    // MARK: - Dropdown focus and outside clicks

    private func beginDropdownFocus() {
        panel.allowsKey = true
        panel.makeKey()
        guard outsideClickMonitor == nil else { return }
        // Global monitors see clicks in other apps only (never our own window); mouse monitors need no permission.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.send(.clickOutside) }
        }
    }

    private func endDropdownFocus() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
        guard panel.allowsKey else { return }
        panel.allowsKey = false
        if panel.isKeyWindow {
            // Hand keyboard focus back to the user's app.
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
    }

    // MARK: - Drag

    /// Drags usually happen while expanded (hover comes first); the saved spot is the collapsed pill
    /// centered where the user dropped it.
    private func finishDrag() {
        let dropped = model.mode == .collapsed ? panel.frame : PillLayout.collapsedFrame(centeredIn: panel.frame)
        let resolved = PlacementResolver.finishDrag(frame: dropped, screens: NSScreen.geometries)
        homeFrame = CGRect(origin: resolved.origin, size: PillLayout.collapsedSize)
        apply(model.mode, immediately: true)
        guard let screenID = resolved.screenID else { return }
        model.store.savePlacement(WidgetPlacement(screenID: screenID, originX: resolved.origin.x,
                                                  originY: resolved.origin.y))
        model.store.saveLastScreenID(screenID)
    }
}
