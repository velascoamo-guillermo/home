#if os(macOS)
import SwiftUI

struct MacSyncSettingsPane: View {
    @Environment(SupabaseStore.self) private var store
    @State private var pending = 0
    @State private var isRefreshing = false

    var body: some View {
        Form {
            LabeledContent("Status", value: store.reachability.isOnline ? "Online" : "Offline")
            LabeledContent("Last Sync") {
                if let date = store.lastSyncAt {
                    Text(date, format: .dateTime.day().month().hour().minute())
                } else {
                    Text("Not yet")
                }
            }
            LabeledContent("Waiting to Upload", value: Self.pendingDescription(pending))
            Button("Refresh") { Task { await refresh() } }
                .disabled(isRefreshing)
        }
        .formStyle(.grouped)
        .task { pending = await store.pendingChangeCount() }
    }

    nonisolated static func pendingDescription(_ count: Int) -> String {
        switch count {
        case 0:  "Nothing waiting"
        case 1:  "1 change"
        default: "\(count) changes"
        }
    }

    private func refresh() async {
        isRefreshing = true
        await store.refreshFromLocal()
        pending = await store.pendingChangeCount()
        isRefreshing = false
    }
}
#endif
