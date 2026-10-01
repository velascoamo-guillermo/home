#if os(macOS)
import SwiftUI

/// Trailing group: the one prominent + for the current feature, then the inspector toggle.
/// Search is contributed by `.searchable(placement: .toolbar)`; leading holds the system
/// sidebar toggle and title; features add centre controls with `.principal`.
struct MacToolbar: ToolbarContent {
    @Bindable var model: MacWindowModel

    var body: some ToolbarContent {
        if let action = CommandRouter.primaryAction(on: model.selection) {
            ToolbarItem(placement: .primaryAction) {
                Button { model.perform(action) } label: {
                    Label(action.title, systemImage: "plus")
                }
                .buttonStyle(.glassProminent)
                .help(action.title)
            }
        }
        if CommandRouter.hasInspector(on: model.selection) {
            ToolbarItem(placement: .primaryAction) {
                Button { model.toggleInspector() } label: {
                    Label(model.isInspectorPresented ? "Hide Inspector" : "Show Inspector",
                          systemImage: "sidebar.trailing")
                }
                .help(model.isInspectorPresented ? "Hide Inspector" : "Show Inspector")
            }
        }
    }
}
#endif
