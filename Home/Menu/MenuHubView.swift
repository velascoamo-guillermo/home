import SwiftUI

struct MenuHubView: View {
    @Binding var path: NavigationPath

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                TileGrid {
                    ForEach(HubTile.all) { tile in
                        switch tile {
                        case .destination(let dest):
                            NavigationLink(value: dest) {
                                Tile(title: tile.title, systemImage: tile.systemImage, fill: tile.fill)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tile.title)
                        case .settings:
                            NavigationLink {
                                SettingsView()
                            } label: {
                                Tile(title: tile.title, systemImage: tile.systemImage, fill: tile.fill)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tile.title)
                        }
                    }
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
