import SwiftUI

struct MenuView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case week, catalog

        var id: String { rawValue }
        var title: String {
            switch self {
            case .week:    "Semana"
            case .catalog: "Meals"
            }
        }
    }

    @State private var mode: Mode = .week

    var body: some View {
        Group {
            switch mode {
            case .week:    WeekMenuView()
            case .catalog: MealsListView()
            }
        }
        .safeAreaInset(edge: .top) {
            Picker("Vista", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Text(m.title).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .navigationTitle("Menu")
    }
}

#Preview {
    NavigationStack { MenuView() }
        .environment(SupabaseStore())
}
