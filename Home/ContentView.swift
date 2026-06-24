import SwiftUI

struct ContentView: View {
    @State private var store = SupabaseStore()
    @State private var theme = ThemeStore()
    @State private var selectedTab: AppTab = .home
    @State private var hubPath = NavigationPath()
    @Environment(\.scenePhase) private var scenePhase

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
                    Button("Retry") {
                        Task { await store.loadAll() }
                    }
                }
            } else {
                MainTabView(selectedTab: $selectedTab, hubPath: $hubPath)
            }
        }
        .environment(store)
        .environment(theme)
        .tint(theme.tint)
        .preferredColorScheme(theme.colorScheme)
        .task { await store.loadAll() }
        .onOpenURL { url in
            let route = AppRouter.route(host: url.host)
            selectedTab = route.tab
            var path = NavigationPath()
            if let dest = route.hubDestination { path.append(dest) }
            hubPath = path
        }
        .onChange(of: scenePhase) { _, new in
            if new == .background && store.loadError == nil && !store.isLoading {
                WidgetSnapshotWriter.write(from: store)
            }
        }
    }
}

#Preview {
    ContentView()
}
