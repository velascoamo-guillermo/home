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
            Tab("Shop", systemImage: "cart.fill") {
                ShopView()
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
        .environmentObject(AuthManager())
}
