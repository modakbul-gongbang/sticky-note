import CoreGraphics
import Foundation

public enum WindowPlacement {
    public static func frame(
        remembered: CGRect?,
        visibleFrame: CGRect,
        defaultSize: CGSize = CGSize(width: 420, height: 640),
        minimumSize: CGSize = CGSize(width: 340, height: 480)
    ) -> CGRect {
        let proposed = remembered ?? CGRect(
            x: visibleFrame.midX - defaultSize.width / 2,
            y: visibleFrame.midY - defaultSize.height / 2,
            width: defaultSize.width,
            height: defaultSize.height
        )
        let width = min(max(proposed.width, minimumSize.width), visibleFrame.width)
        let height = min(max(proposed.height, minimumSize.height), visibleFrame.height)
        let x = min(max(proposed.origin.x, visibleFrame.minX), visibleFrame.maxX - width)
        let y = min(max(proposed.origin.y, visibleFrame.minY), visibleFrame.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
