import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: AppTab
    @Binding var hubPath: [HubDestination]

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                DashboardView()
            }
            Tab("Menu", systemImage: "square.grid.2x2.fill", value: AppTab.menu) {
                MenuHubView(path: $hubPath)
            }
            Tab(value: AppTab.search, role: .search) {
                SearchView()
            }
        }
    }
}

#Preview {
    MainTabView(selectedTab: .constant(.home), hubPath: .constant([]))
        .environment(SupabaseStore())
}
