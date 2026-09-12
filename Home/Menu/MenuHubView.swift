import SwiftUI

struct MenuHubView: View {
    @Binding var path: NavigationPath

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(HubDestination.allCases) { dest in
                        NavigationLink(value: dest) { Text(dest.title) }
                            .pastelRow(dest.fill)
                    }
                }
                Section {
                    NavigationLink { SettingsView() } label: { Text("Settings") }
                        .pastelRow(Palette.surface)
                }
            }
            .flatListStyle()
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
