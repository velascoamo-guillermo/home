#if os(macOS)
import SwiftUI

struct MacBudgetView: View {
    @Bindable var model: MacWindowModel
    @Environment(SupabaseStore.self) private var store
    @Environment(\.undoManager) private var undoManager
    @State private var selection: UUID?
    @State private var editor: ExpenseDraft?
    @State private var deleteErrorMessage: String?

    var body: some View {
        let month = model.budgetMonth
        let summary = store.budgetSummary(for: month)
        let hero = BudgetHeroModel(summary: summary, locale: .current)

        List(selection: $selection) {
            Section {
                BudgetHeroCard(model: hero)
            }
            .selectionDisabled()
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if !summary.pendingRecurring.isEmpty {
                Section("Pending Bills") {
                    ForEach(summary.pendingRecurring) { bill in
                        Button {
                            editor = ExpenseDraft(confirming: bill, month: month, calendar: .current)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bill.name).foregroundStyle(Palette.ink)
                                    Text("Day \(bill.dayOfMonth) · \(summary.memberName(bill.payerId))")
                                        .font(.caption)
                                        .foregroundStyle(Palette.inkSecondary)
                                }
                                Spacer()
                                Text(Money.format(cents: bill.amountCents))
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.ink)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the bill to confirm this month's amount")
                        .selectionDisabled()
                        .pastelRow(Palette.budget)
                    }
                }
            }

            Section {
                Text(hero.remainingLine)
                    .font(.headline)
                    .foregroundStyle(summary.remainingCents < 0 ? Color.red : Palette.ink)
            }
            .selectionDisabled()

            categorySection("Categories", lines: summary.categories.filter { !$0.isArchived })
            categorySection("Archived", lines: summary.categories.filter(\.isArchived))

            ForEach(BudgetDayGroup.groups(store.budgetExpenses, in: month, calendar: .current)) { group in
                Section {
                    ForEach(group.expenses) { expense in
                        BudgetExpenseRow(expense: expense,
                                         categoryName: categoryName(expense.categoryId),
                                         payerName: summary.memberName(expense.payerId))
                            .tag(expense.id)
                            .pastelRow(Palette.surface)
                    }
                } header: {
                    Text(group.day, format: .dateTime.weekday(.wide).day().month(.wide))
                }
            }
        }
        .flatListStyle()
        .contextMenu(forSelectionType: UUID.self) { ids in
            if let expense = expense(ids.first) {
                Button("Edit Expense…") { editor = ExpenseDraft(expense: expense) }
                Button("Delete", role: .destructive) { delete(expense) }
            }
        } primaryAction: { ids in
            if let expense = expense(ids.first) { editor = ExpenseDraft(expense: expense) }
        }
        .onDeleteCommand {
            if let expense = expense(selection) { delete(expense) }
        }
        .background(ListFocusView(selection: selection))
        .toolbar {
            ToolbarItem(placement: .principal) { monthSwitcher(month) }
        }
        .inspector(isPresented: $model.isInspectorPresented) {
            NavigationStack { BudgetSettingsView(month: month) }
                .inspectorColumnWidth(min: 360, ideal: 400, max: 520)
        }
        .sheet(item: $editor) { draft in AddExpenseSheet(draft: draft) }
        .alert("Couldn't Delete Expense", isPresented: Binding(
            get: { deleteErrorMessage != nil },
            set: { if !$0 { deleteErrorMessage = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(deleteErrorMessage ?? "")
        }
    }

    private func monthSwitcher(_ month: BudgetMonth) -> some View {
        HStack(spacing: 8) {
            Button { model.stepPeriod(by: -1) } label: {
                Label("Previous Month", systemImage: "chevron.left")
            }
            .labelStyle(.iconOnly)
            .help("Previous Month (⌘[)")
            Text(month.title(locale: .current, calendar: .current))
                .font(.headline)
                .frame(minWidth: 140)
            Button { model.stepPeriod(by: 1) } label: {
                Label("Next Month", systemImage: "chevron.right")
            }
            .labelStyle(.iconOnly)
            .help("Next Month (⌘])")
        }
    }

    @ViewBuilder
    private func categorySection(_ title: String, lines: [CategoryLine]) -> some View {
        if !lines.isEmpty {
            Section(title) {
                ForEach(lines) { line in
                    BudgetCategoryRow(line: line)
                        .selectionDisabled()
                        .pastelRow(Palette.surface)
                }
            }
        }
    }

    private func expense(_ id: UUID?) -> BudgetExpense? {
        id.flatMap { id in store.budgetExpenses.first { $0.id == id } }
    }

    private func categoryName(_ id: UUID) -> String {
        store.budgetCategories.first { $0.id == id }?.name ?? "Uncategorised"
    }

    private func delete(_ expense: BudgetExpense) {
        Task {
            do {
                try await store.deleteBudgetExpense(expense, undoManager: undoManager)
            } catch {
                deleteErrorMessage = error.localizedDescription
            }
        }
    }
}
#endif
