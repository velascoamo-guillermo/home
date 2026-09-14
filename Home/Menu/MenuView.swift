import SwiftUI

struct MenuView: View {
    var body: some View {
        WeekMenuView()
            .navigationTitle("Meals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        MealsListView()
                            .navigationTitle("Catálogo")
                    } label: {
                        Label("Catálogo", systemImage: "book")
                    }
                }
            }
    }
}

#Preview {
    NavigationStack { MenuView() }
        .environment(SupabaseStore())
}
