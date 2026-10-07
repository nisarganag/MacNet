import SwiftUI

extension View {
    /// The panel surface: Liquid Glass refracting the desktop through the
    /// clear window behind it.
    func panelSurface(_ style: GlassStyle, dark: Bool) -> some View {
        let glass: Glass = style == .clear ? .clear : .regular
        return glassEffect(glass.tint(Theme.veil(style, dark: dark)),
                           in: .rect(cornerRadius: Theme.cornerRadius))
    }

    /// A raised glass card on the panel. Place sibling cards inside one
    /// `GlassEffectContainer` so the system renders them as one optical
    /// layer instead of separately frosted rectangles.
    func glassCard() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: Theme.cardRadius))
    }
}
