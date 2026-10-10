#if os(macOS)
import SwiftUI

extension FocusedValues {
    @Entry var macWindow: MacWindowModel?

    /// Published separately from `macWindow` so the menu bar's `.disabled(...)` checks react to
    /// a *value* change: `macWindow` holds the same `MacWindowModel` reference across a
    /// selection/feature change (only its properties mutate), and `FocusedValue` only triggers a
    /// `Commands` body re-evaluation when the focused *value* itself changes — not when a
    /// property on an unchanged reference does. Without this, `availableCommands` could read
    /// stale after switching features until some unrelated focus change forced a re-render.
    @Entry var macAvailableCommands: Set<MacFeatureCommand>?
}
#endif
