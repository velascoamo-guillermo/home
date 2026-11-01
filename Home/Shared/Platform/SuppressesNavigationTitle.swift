import SwiftUI

extension EnvironmentValues {
    /// Set by the Mac `.inspector` hosts: a `.navigationTitle` inside an inspector reaches the
    /// window and overrides the sidebar-driven title (see MacShellView).
    @Entry var suppressesNavigationTitle = false
}

private struct ConditionalNavigationTitle: ViewModifier {
    let title: String
    @Environment(\.suppressesNavigationTitle) private var suppresses

    func body(content: Content) -> some View {
        if suppresses {
            content
        } else {
            content.navigationTitle(title)
        }
    }
}

extension View {
    /// Sets the navigation title unless an enclosing inspector suppresses it.
    func inspectorAwareNavigationTitle(_ title: String) -> some View {
        modifier(ConditionalNavigationTitle(title: title))
    }
}
