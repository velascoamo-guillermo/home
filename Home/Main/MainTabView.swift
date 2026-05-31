import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeView()
            }
            Tab("Pets", systemImage: "pawprint.fill") {
                PetsView()
            }
            Tab("Stock", systemImage: "shippingbox.fill") {
                StockView()
            }
            Tab("Menu", systemImage: "fork.knife") {
                MenuView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .tint(Color(red: 1.0, green: 0.45, blue: 0.2))
    }
}

#Preview {
    MainTabView()
        .environment(SupabaseStore())
}
