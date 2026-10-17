import SwiftUI

extension View {
    /// macOS has no navigation bar, so the inline title mode only exists on iOS.
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    func platformKeyboard(_ keyboard: PlatformKeyboard) -> some View {
        #if os(iOS)
        keyboardType(keyboard.uiKeyboardType)
        #else
        self
        #endif
    }

    /// iOS lets the pet hero run under a transparent bar; the Mac keeps the system toolbar.
    func hiddenNavigationBarBackground() -> some View {
        #if os(iOS)
        toolbarBackground(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    /// macOS lists reorder by dragging without an edit mode, so the Edit button is iOS-only.
    func editButtonToolbar() -> some View {
        #if os(iOS)
        toolbar { EditButton() }
        #else
        self
        #endif
    }

    /// The Mac shell owns one app-wide toolbar search; a second `.searchable` from a hosted view
    /// makes NSToolbar throw when the detail column switches to it, so hosted views skip theirs.
    @ViewBuilder
    func iOSSearchable(text: Binding<String>, prompt: String) -> some View {
        #if os(iOS)
        // #110: iOS 27 toolbar `.minimize` reopen breaks, and `.toolbar`/`.automatic` render nothing on screens pushed inside a tab's NavigationStack (root-of-tab and sheets are fine), so use the always-visible drawer.
        if #available(iOS 27, *) {
            searchable(text: text, placement: .navigationBarDrawer(displayMode: .always), prompt: prompt)
        } else {
            searchable(text: text, placement: .toolbar, prompt: prompt)
                .searchToolbarBehavior(.minimize)
        }
        #else
        self
        #endif
    }

    func zoomNavigationTransition(sourceID: some Hashable, in namespace: Namespace.ID) -> some View {
        #if os(iOS)
        navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        #else
        self
        #endif
    }

    /// Mac sheets and inspectors size to their content and default to a columns form; give the
    /// iPhone forms a usable minimum and the grouped style they were designed for.
    func platformSheet() -> some View {
        #if os(macOS)
        formStyle(.grouped)
            .frame(minWidth: 360, idealWidth: 480, minHeight: 420, idealHeight: 560)
        #else
        self
        #endif
    }
}
