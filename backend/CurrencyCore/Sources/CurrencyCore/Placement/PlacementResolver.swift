import CoreGraphics

/// A display described without AppKit. Coordinates are AppKit global points (origin bottom-left of main).
public struct ScreenGeometry: Sendable, Equatable {
    public let id: String
    public let frame: CGRect
    /// Frame minus menu bar and Dock.
    public let visibleFrame: CGRect
    public let isMain: Bool

    public init(id: String, frame: CGRect, visibleFrame: CGRect, isMain: Bool) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.isMain = isMain
    }
}

public struct ResolvedPlacement: Sendable, Equatable {
    /// nil only when no screens are connected.
    public let screenID: String?
    public let origin: CGPoint
}

/// Pure placement math for the single pill (SPEC F3–F4, ADR-0015).
public enum PlacementResolver {
    /// Where the pill goes at launch or after displays change:
    /// 1. its saved spot on the last-used display, if connected;
    /// 2. else its saved spot on the main display;
    /// 3. else the main display, top-center. Always clamped fully on screen.
    public static func resolve(placements: [String: WidgetPlacement], lastScreenID: String?,
                               screens: [ScreenGeometry], size: CGSize) -> ResolvedPlacement {
        guard let main = screens.first(where: \.isMain) ?? screens.first else {
            return ResolvedPlacement(screenID: nil, origin: .zero)
        }
        let target = screens.first { $0.id == lastScreenID } ?? main
        let origin: CGPoint
        if let saved = placements[target.id] {
            origin = CGPoint(x: saved.originX, y: saved.originY)
        } else {
            origin = topCenterOrigin(size: size, in: target.visibleFrame)
        }
        return ResolvedPlacement(screenID: target.id, origin: clamp(origin: origin, size: size, in: target.visibleFrame))
    }

    /// After a drag: the display under the pill's center, and the origin clamped onto it.
    public static func finishDrag(frame: CGRect, screens: [ScreenGeometry]) -> ResolvedPlacement {
        guard let screen = screen(containing: frame, in: screens) else {
            return ResolvedPlacement(screenID: nil, origin: frame.origin)
        }
        return ResolvedPlacement(screenID: screen.id,
                                 origin: clamp(origin: frame.origin, size: frame.size, in: screen.visibleFrame))
    }

    public static func topCenterOrigin(size: CGSize, in visibleFrame: CGRect) -> CGPoint {
        CGPoint(x: visibleFrame.midX - size.width / 2, y: visibleFrame.maxY - size.height)
    }

    /// Keeps a `size`-sized rect fully inside `visibleFrame`; if it can't fit, pins to the frame's origin.
    public static func clamp(origin: CGPoint, size: CGSize, in visibleFrame: CGRect) -> CGPoint {
        let maxX = max(visibleFrame.minX, visibleFrame.maxX - size.width)
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - size.height)
        return CGPoint(x: min(max(origin.x, visibleFrame.minX), maxX),
                       y: min(max(origin.y, visibleFrame.minY), maxY))
    }

    /// The screen whose frame contains the rect's center, else the nearest screen.
    public static func screen(containing rect: CGRect, in screens: [ScreenGeometry]) -> ScreenGeometry? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        if let hit = screens.first(where: { $0.frame.contains(center) }) { return hit }
        return screens.min { distance(from: center, to: $0.frame) < distance(from: center, to: $1.frame) }
    }

    private static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}
