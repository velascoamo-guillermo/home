import SwiftUI

struct BudgetSettingsView: View {
    @Environment(SupabaseStore.self) private var store
    let month: BudgetMonth

    @State private var editingCategory: BudgetCategory?
    @State private var showAddMember = false
    @State private var newMemberName = ""
    @State private var errorMessage: String?
    @State private var editingBill: RecurringExpense?
    @State private var showNewBill = false
    @State private var memberPendingRemoval: BudgetMember?

    var body: some View {
        let summary = store.budgetSummary(for: month)
        let active = store.budgetCategories.filter { !$0.archived }
        let archived = store.budgetCategories.filter(\.archived)
        List {
            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section {
                ForEach(summary.members.filter { !$0.isFormer }) { line in
                    MemberIncomeRow(line: line, month: month)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                memberPendingRemoval = store.budgetMembers.first { $0.id == line.id }
                            } label: { Label("Remove", systemImage: "person.fill.xmark") }
                        }
                }
                Button("Add member", systemImage: "person.badge.plus") { showAddMember = true }
            } header: {
                Text("Members · \(month.title(locale: .current, calendar: .current))")
            } footer: {
                Text("Income is per month. Months without their own value reuse the latest earlier one.")
            }

            Section("Categories") {
                ForEach(active) { category in
                    Button { editingCategory = category } label: {
                        HStack {
                            Text(category.name).foregroundStyle(Palette.ink)
                            Spacer()
                            Text(Money.format(cents: category.estimateCents))
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button {
                            Task { await run { try await store.setBudgetCategoryArchived(category, archived: true) } }
                        } label: { Label("Archive", systemImage: "archivebox") }
                        .tint(.orange)
                    }
                }
                .onMove { from, to in
                    var reordered = active
                    reordered.move(fromOffsets: from, toOffset: to)
                    Task { await run { try await store.reorderBudgetCategories(reordered) } }
                }
                Button("Add category", systemImage: "plus") {
                    editingCategory = BudgetCategory(
                        name: "", sortOrder: (store.budgetCategories.map(\.sortOrder).max() ?? -1) + 1)
                }
            }

            Section("Recurring bills") {
                ForEach(store.recurringExpenses.sorted { ($0.dayOfMonth, $0.name) < ($1.dayOfMonth, $1.name) }) { bill in
                    Button { editingBill = bill } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bill.name).foregroundStyle(Palette.ink)
                                Text("Day \(bill.dayOfMonth)\(bill.active ? "" : " · paused")")
                                    .font(.caption)
                                    .foregroundStyle(Palette.inkSecondary)
                            }
                            Spacer()
                            Text(Money.format(cents: bill.amountCents))
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Button("Add bill", systemImage: "plus") { showNewBill = true }
            }

            if !archived.isEmpty {
                Section("Archived") {
                    ForEach(archived) { category in
                        Text(category.name)
                            .foregroundStyle(Palette.inkSecondary)
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task { await run { try await store.setBudgetCategoryArchived(category, archived: false) } }
                                } label: { Label("Restore", systemImage: "arrow.uturn.backward") }
                                .tint(.green)
                            }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .gradientCanvas()
        .navigationTitle("Budget settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(item: $editingCategory) { category in
            CategoryEditSheet(category: category,
                              isNew: !store.budgetCategories.contains { $0.id == category.id })
        }
        .sheet(item: $editingBill) { bill in RecurringBillSheet(existing: bill) }
        .sheet(isPresented: $showNewBill) { RecurringBillSheet(existing: nil) }
        .confirmationDialog(removalTitle, isPresented: removalDialogBinding, titleVisibility: .visible,
                            presenting: memberPendingRemoval) { member in
            Button("Remove \(member.name)", role: .destructive) {
                Task { await run { try await store.deleteBudgetMember(member) } }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("New member", isPresented: $showAddMember) {
            TextField("Name", text: $newMemberName)
            Button("Add") {
                let name = newMemberName
                newMemberName = ""
                Task { await run { try await store.addBudgetMember(name: name) } }
            }
            Button("Cancel", role: .cancel) { newMemberName = "" }
        }
    }

    private var removalTitle: String {
        guard let name = memberPendingRemoval?.name else { return "" }
        return "Remove \(name)? Their past payments will show as Former member and they'll no longer share costs."
    }

    private var removalDialogBinding: Binding<Bool> {
        Binding(
            get: { memberPendingRemoval != nil },
            set: { if !$0 { memberPendingRemoval = nil } }
        )
    }

    private func run(_ action: () async throws -> Void) async {
        do {
            try await action()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
