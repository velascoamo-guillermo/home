import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: AppTab
    @Binding var hubPath: NavigationPath

    @State private var showAdd = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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

            if selectedTab != .search {
                FloatingActionButton { showAdd = true }
                    .padding(.trailing, 20)
                    .padding(.bottom, 76)
            }
        }
        .sheet(isPresented: $showAdd) { HouseholdTaskSheet() }
    }
}

#Preview {
    MainTabView(selectedTab: .constant(.home), hubPath: .constant(NavigationPath()))
        .environment(SupabaseStore())
}
