import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView()
            }
            Tab("Pets", systemImage: "pawprint.fill", value: AppTab.pets) {
                PetsView()
            }
            Tab("Stock", systemImage: "shippingbox.fill", value: AppTab.stock) {
                StockView()
            }
            Tab("Menu", systemImage: "fork.knife", value: AppTab.menu) {
                MenuView()
            }
            Tab("Shopping", systemImage: "cart.fill", value: AppTab.shopping) {
                ShoppingView()
            }
        }
        .tint(Color(red: 1.0, green: 0.45, blue: 0.2))
    }
}

#Preview {
    MainTabView(selectedTab: .constant(.home))
        .environment(SupabaseStore())
}
