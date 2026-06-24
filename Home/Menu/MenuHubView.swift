import SwiftUI

struct MenuHubView: View {
    @Binding var path: [HubDestination]

    var body: some View {
        NavigationStack(path: $path) {
            List(HubDestination.allCases) { dest in
                NavigationLink(value: dest) {
                    Label(dest.title, systemImage: dest.systemImage)
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
    MenuHubView(path: .constant([]))
        .environment(SupabaseStore())
}
