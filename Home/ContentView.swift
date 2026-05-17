// Home/ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var store = SupabaseStore()

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = store.loadError {
                ContentUnavailableView(
                    "Connection Error",
                    systemImage: "wifi.slash",
                    description: Text(error)
                ) {
                    Button("Retry") {
                        Task { await store.loadAll() }
                    }
                }
            } else {
                MainTabView()
            }
        }
        .environment(store)
        .task { await store.loadAll() }
    }
}

#Preview {
    ContentView()
}
