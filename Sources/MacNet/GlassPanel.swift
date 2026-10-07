import AppKit

/// The panel's window: borderless and fully clear, so the SwiftUI Liquid
/// Glass inside it refracts the real desktop.
///
/// Not `NSPopover`: its private frame view paints its own material beneath
/// the hosted content, so glass layered on top refracts that grey frame
/// instead of what is behind the window (AgentMenu ran into exactly this).
final class GlassPanel: NSPanel {
    /// Key so controls respond to the first click; non-activating so opening
    /// the panel never steals focus from the app the user is working in.
    override var canBecomeKey: Bool { true }

    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isFloatingPanel = true
        isMovable = false
        // Above ordinary windows, like a real menu.
        level = .popUpMenu
        // Follows the user across Spaces and over full-screen apps.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
    }
}
