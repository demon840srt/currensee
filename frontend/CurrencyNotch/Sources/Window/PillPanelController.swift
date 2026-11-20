import AppKit
import CurrencyCore

/// Owns the pill panel: restores its position, moves it on drag, saves it per display (SPEC F3–F6).
@MainActor
final class PillPanelController {
    private let model: AppModel
    private let panel: PillPanel
    private var dragStartOrigin: CGPoint = .zero
    private var screenObserver: NSObjectProtocol?

    init(model: AppModel, menuController: AppMenuController) {
        self.model = model
        let content = PillContentView(rootView: PillView(model: model))
        panel = PillPanel(contentView: content)

        content.isLocked = { [weak model] in model?.isPositionLocked ?? false }
        content.contextMenu = { [weak menuController] in menuController?.makeMenu() }
        content.onClick = {}   // Dropdown arrives in Phase 6.
        content.onDragBegan = { [weak self] in
            guard let self else { return }
            dragStartOrigin = panel.frame.origin
        }
        content.onDragMoved = { [weak self] offset in
            guard let self else { return }
            panel.setFrameOrigin(CGPoint(x: dragStartOrigin.x + offset.dx, y: dragStartOrigin.y + offset.dy))
        }
        content.onDragEnded = { [weak self] in self?.finishDrag() }

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
            size: panel.frame.size
        )
        panel.setFrameOrigin(resolved.origin)
    }

    private func finishDrag() {
        let resolved = PlacementResolver.finishDrag(frame: panel.frame, screens: NSScreen.geometries)
        panel.setFrameOrigin(resolved.origin)
        guard let screenID = resolved.screenID else { return }
        model.store.savePlacement(WidgetPlacement(screenID: screenID, originX: resolved.origin.x,
                                                  originY: resolved.origin.y))
        model.store.saveLastScreenID(screenID)
    }
}
