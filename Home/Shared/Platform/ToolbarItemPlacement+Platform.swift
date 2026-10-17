import SwiftUI

extension ToolbarItemPlacement {
    /// `.topBarTrailing` on iOS; the trailing edge of the window toolbar on macOS.
    static var trailingBar: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .primaryAction
        #endif
    }

    /// Placement for an add button on a screen using `iOSSearchable`. #110: on iOS 27 the
    /// `.minimize` search re-activates itself after close when another trailing item exists.
    static var addActionBesideSearch: ToolbarItemPlacement {
        #if os(iOS)
        if #available(iOS 27, *) { return .topBarLeading }
        return .topBarTrailing
        #else
        .primaryAction
        #endif
    }
}
