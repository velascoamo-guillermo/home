import SwiftUI

struct BudgetView: View {
    @Environment(SupabaseStore.self) private var store
    @State private var month = BudgetMonth(date: .now, calendar: .current)

    var body: some View {
        let summary = store.budgetSummary(for: month)
        let hero = BudgetHeroModel(summary: summary, locale: .current)
        List {
            Section {
                monthSwitcher
                BudgetHeroCard(model: hero)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))

            Section {
                Text(hero.remainingLine)
                    .font(.headline)
                    .foregroundStyle(summary.remainingCents < 0 ? Color.red : Palette.ink)
                    .pastelRow(Palette.budget)
            }

            categorySection("Categories", lines: summary.categories.filter { !$0.isArchived })
            categorySection("Archived", lines: summary.categories.filter(\.isArchived))

            ForEach(BudgetDayGroup.groups(store.budgetExpenses, in: month, calendar: .current)) { group in
                Section {
                    ForEach(group.expenses) { expense in
                        BudgetExpenseRow(expense: expense,
                                         categoryName: categoryName(expense.categoryId),
                                         payerName: summary.memberName(expense.payerId))
                            .pastelRow(Palette.surface)
                    }
                } header: {
                    Text(group.day, format: .dateTime.weekday(.wide).day().month(.wide))
                }
            }
        }
        .flatListStyle()
        .navigationTitle("Budget")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var monthSwitcher: some View {
        HStack {
            Button { month = month.previous } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous month")
            Spacer()
            Text(month.title(locale: .current, calendar: .current))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.ink)
            Spacer()
            Button { month = month.next } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Next month")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func categorySection(_ title: String, lines: [CategoryLine]) -> some View {
        if !lines.isEmpty {
            Section(title) {
                ForEach(lines) { line in
                    BudgetCategoryRow(line: line)
                        .pastelRow(Palette.surface)
                }
            }
        }
    }

    private func categoryName(_ id: UUID) -> String {
        store.budgetCategories.first { $0.id == id }?.name ?? "Uncategorised"
    }
}

#Preview {
    NavigationStack { BudgetView() }
        .environment(SupabaseStore())
}
