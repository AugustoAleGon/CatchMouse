import Foundation
import CoreGraphics

public struct DisplayTarget: Equatable {
    public let id: String
    /// Core Graphics global coordinates, measured in points (not backing pixels).
    public let bounds: CGRect

    public init(id: String, bounds: CGRect) {
        self.id = id
        self.bounds = bounds
    }

    public var center: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }
}

public enum DisplayNavigation {
    /// A stable spatial order: left to right, then top to bottom.
    public static func ordered(_ displays: [DisplayTarget]) -> [DisplayTarget] {
        displays.sorted {
            if $0.bounds.minX != $1.bounds.minX { return $0.bounds.minX < $1.bounds.minX }
            if $0.bounds.minY != $1.bounds.minY { return $0.bounds.minY < $1.bounds.minY }
            return $0.id < $1.id
        }
    }

    public static func destination(in displays: [DisplayTarget], from point: CGPoint,
                                   forward: Bool) -> DisplayTarget? {
        let screens = ordered(displays)
        guard !screens.isEmpty else { return nil }
        guard let index = screens.firstIndex(where: { $0.bounds.contains(point) }) else {
            return forward ? screens.first : screens.last
        }
        let offset = forward ? 1 : screens.count - 1
        return screens[(index + offset) % screens.count]
    }
}
