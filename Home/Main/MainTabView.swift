import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: AppTab
    @Binding var hubPath: NavigationPath

    @State private var showAdd = false

    // Clears the iOS 26 floating tab bar; measured on iPhone 17 Pro Max.
    private static let fabBottomPadding: CGFloat = 76

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

            if selectedTab == .home {
                FloatingActionButton { showAdd = true }
                    .padding(.trailing, 20)
                    .padding(.bottom, Self.fabBottomPadding)
            }
        }
        .sheet(isPresented: $showAdd) { HouseholdTaskSheet() }
    }
}

#Preview {
    MainTabView(selectedTab: .constant(.home), hubPath: .constant(NavigationPath()))
        .environment(SupabaseStore())
}
