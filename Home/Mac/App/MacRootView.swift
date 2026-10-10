#if os(macOS)
import AppKit
import SwiftUI

struct MacRootView: View {
    @Binding var seed: MacWindowSeed
    @Environment(SupabaseStore.self) private var store
    @Environment(MacBootstrap.self) private var bootstrap
    @State private var model: MacWindowModel

    init(seed: Binding<MacWindowSeed>) {
        _seed = seed
        _model = State(initialValue: MacWindowModel(selection: seed.wrappedValue.item))
    }

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = store.loadError {
                ContentUnavailableView {
                    Label("Connection Error", systemImage: "wifi.slash")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await store.loadAll() } }
                }
            } else {
                MacShellView(model: model)
            }
        }
        .frame(minWidth: 760, minHeight: 480)
        .focusedSceneValue(\.macWindow, model)
        .task { await bootstrap.start() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await bootstrap.appDidBecomeActive() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            bootstrap.appDidResignActive()
        }
        .onChange(of: model.selection) { _, new in seed.item = new }
        .onChange(of: bootstrap.didFinishLoading) { _, _ in resolveSelection() }
        .onChange(of: store.pets) { _, _ in resolveSelection() }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { store.actionError != nil },
            set: { if !$0 { store.actionError = nil } }
        )) {
            Button("OK") { store.actionError = nil }
        } message: {
            if let message = store.actionError { Text(message) }
        }
        .environment(\.openURL, OpenURLAction { url in route(url) })
        .onOpenURL { url in _ = route(url) }
        .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
    }

    private func resolveSelection() {
        guard bootstrap.didFinishLoading else { return }
        model.selection = SidebarModel.resolve(model.selection, pets: store.pets)
    }

    /// `home://` links from the widget and in-app buttons (e.g. "View Shopping") select a
    /// sidebar row in this window instead of spawning a new one.
    private func route(_ url: URL) -> OpenURLAction.Result {
        guard url.scheme == "home" else { return .systemAction }
        model.searchText = ""
        model.selection = SidebarModel.item(for: AppRouter.route(host: url.host), pets: store.pets)
        return .handled
    }
}
#endif
