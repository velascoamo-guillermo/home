import SwiftUI

struct MenuHubView: View {
    @Binding var path: NavigationPath
    /// Whether the Menu tab is selected; entering it replays the tile entrance.
    let isActive: Bool

    @State private var tilesRevealed = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                TileGrid {
                    ForEach(Array(HubTile.all.enumerated()), id: \.element.id) { index, tile in
                        switch tile {
                        case .destination(let dest):
                            NavigationLink(value: dest) {
                                tileLabel(tile, index: index)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tile.title)
                        case .settings:
                            NavigationLink {
                                SettingsView()
                            } label: {
                                tileLabel(tile, index: index)
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
        // Reveal from a task, not onChange: tab selection runs in a transaction with animations disabled.
        .task(id: isActive) {
            if isActive { tilesRevealed = true }
        }
        .onChange(of: isActive) { _, active in
            guard !active else { return }
            // Reset off-screen without animating so the next tab entry pops in again.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { tilesRevealed = false }
        }
    }

    private func tileLabel(_ tile: HubTile, index: Int) -> some View {
        Tile(
            title: tile.title,
            systemImage: tile.systemImage,
            fill: tile.fill,
            isRevealed: tilesRevealed,
            entranceIndex: index
        )
    }
}

#Preview {
    MenuHubView(path: .constant(NavigationPath()), isActive: true)
        .environment(SupabaseStore())
}
