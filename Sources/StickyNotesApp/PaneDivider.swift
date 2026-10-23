import AppKit

/// The grab line between today's page and the note below. Dragging reports how far the
/// pointer has moved down since the press, so the owner resizes from where the drag began.
final class PaneDivider: NSView {
    var onDragBegan: (() -> Void)?
    var onDrag: ((CGFloat) -> Void)?
    private var dragStartY: CGFloat?

    /// The panel moves when its background is dragged; the divider is the one strip of
    /// background whose drag means "resize", so it opts out.
    override var mouseDownCanMoveWindow: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.17, alpha: 1).setFill()
        NSRect(x: 16, y: bounds.midY - 0.5, width: bounds.width - 32, height: 1).fill()
        NSColor(calibratedWhite: 0.26, alpha: 1).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: bounds.midX - 14, y: bounds.midY - 2, width: 28, height: 4),
            xRadius: 2,
            yRadius: 2
        ).fill()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func mouseDown(with event: NSEvent) {
        dragStartY = event.locationInWindow.y
        onDragBegan?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStartY else { return }
        onDrag?(dragStartY - event.locationInWindow.y)
    }

    override func mouseUp(with event: NSEvent) {
        dragStartY = nil
    }
}
