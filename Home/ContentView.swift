import SwiftUI

struct ContentView: View {
    @State private var store = SupabaseStore()
    @State private var selectedTab: AppTab = .home
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
                MainTabView(selectedTab: $selectedTab)
            }
        }
        .environment(store)
        .task { await store.loadAll() }
        .onOpenURL { url in
            selectedTab = AppTab(host: url.host) ?? .home
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
