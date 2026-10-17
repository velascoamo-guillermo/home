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
}
