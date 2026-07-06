import SwiftUI

struct MenuHubView: View {
    @Binding var path: NavigationPath

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(HubDestination.allCases) { dest in
                        NavigationLink(value: dest) {
                            HStack(spacing: 12) {
                                IconChip(systemImage: dest.systemImage, tint: dest.tint)
                                Text(dest.title)
                            }
                        }
                        .glassRow()
                    }
                }
                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        HStack(spacing: 12) {
                            IconChip(systemImage: "gearshape.fill", tint: .gray)
                            Text("Settings")
                        }
                    }
                    .glassRow()
                }
            }
            .glassListStyle()
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
