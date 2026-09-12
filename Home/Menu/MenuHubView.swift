import SwiftUI

struct MenuHubView: View {
    @Binding var path: NavigationPath

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                TileGrid {
                    ForEach(HubDestination.allCases) { dest in
                        NavigationLink(value: dest) {
                            Tile(title: dest.title, systemImage: dest.systemImage, fill: dest.fill)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(dest.title)
                    }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Tile(title: HubTile.settings.title,
                             systemImage: HubTile.settings.systemImage,
                             fill: HubTile.settings.fill)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(HubTile.settings.title)
                }
                .padding(16)
            }
            .gradientCanvas()
            .navigationTitle("Menu")
            .navigationDestination(for: HubDestination.self) { dest in
                switch dest {
                case .tasks:    TasksView()
                case .pets:     PetsView()
                case .stock:    StockView()
                case .meals:    MenuView()
                case .shopping: ShoppingView()
                }
            }
        }
    }
}

#Preview {
    MenuHubView(path: .constant(NavigationPath()))
        .environment(SupabaseStore())
}
