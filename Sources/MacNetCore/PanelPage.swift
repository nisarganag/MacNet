/// The panel's two pages.
public enum PanelPage: Sendable {
    case monitor, settings

    /// Where Escape leads: out of Settings back to the monitor first, like
    /// leaving a submenu; from the monitor, nowhere — the panel closes.
    public var afterEscape: PanelPage? {
        self == .settings ? .monitor : nil
    }
}
