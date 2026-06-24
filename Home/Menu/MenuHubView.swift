import SwiftUI

struct MenuHubView: View {
    @Binding var path: NavigationPath

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(HubDestination.allCases) { dest in
                        NavigationLink(value: dest) {
                            Label(dest.title, systemImage: dest.systemImage)
                        }
                    }
                }
                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Menu")
            .navigationDestination(for: HubDestination.self) { dest in
                switch dest {
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
