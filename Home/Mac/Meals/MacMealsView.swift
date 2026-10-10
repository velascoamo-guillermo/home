#if os(macOS)
import SwiftUI

struct MacMealsView: View {
    @Bindable var model: MacWindowModel
    @Environment(SupabaseStore.self) private var store
    @State private var editTarget: SlotTarget?
    @State private var isSuggesting = false
    @State private var errorMessage: String?

    private struct SlotTarget: Identifiable {
        let id = UUID()
        let day: Int
        let slot: MealSlot
    }

    static func canSuggest(emptySlotCount: Int, meals: [Meal]) -> Bool {
        emptySlotCount > 0 && meals.contains { !$0.title.isEmpty }
    }

    private var suggestAvailable: Bool {
        !isSuggesting && Self.canSuggest(emptySlotCount: store.emptyMealSlots.count, meals: store.meals)
    }

    var body: some View {
        let today = Weekday(date: .now, calendar: .current)
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Color.clear.frame(width: 72, height: 1)
                    ForEach(Weekday.allCases) { day in
                        Text(day == today ? "\(day.displayName) · Hoy" : day.displayName)
                            .font(.headline)
                            .foregroundStyle(Palette.ink)
                    }
                }
                ForEach(MealSlot.allCases, id: \.self) { slot in
                    GridRow {
                        Text(slot.displayName)
                            .font(.headline)
                            .foregroundStyle(Palette.inkSecondary)
                        ForEach(Weekday.allCases) { day in
                            cell(day: day.rawValue, slot: slot)
                        }
                    }
                }
            }
            .padding(20)
        }
        .gradientCanvas()
        .overlay {
            if isSuggesting {
                ProgressView("Planificando la semana…")
                    .padding()
                    .background(Palette.surface, in: .rect(cornerRadius: 12))
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button { Task { await suggestWeek() } } label: {
                    Label("Suggest Week", systemImage: "sparkles")
                }
                .disabled(!suggestAvailable)
                .help("Suggest Week")
            }
        }
        .inspector(isPresented: $model.isInspectorPresented) {
            MacMealCatalogView()
                .inspectorColumnWidth(min: 280, ideal: 320, max: 420)
        }
        .sheet(item: $editTarget) { target in MealPickerSheet(day: target.day, slot: target.slot) }
        .alert("No se pudo sugerir", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: suggestAvailable, initial: true) { _, available in
            model.availableCommands = available ? [.suggestWeek] : []
        }
        .onChange(of: model.requestedCommand) { _, command in
            guard let command else { return }
            model.requestedCommand = nil
            if command == .suggestWeek { Task { await suggestWeek() } }
        }
    }

    private func cell(day: Int, slot: MealSlot) -> some View {
        let entry = store.mealEntry(day: day, slot: slot)
        return Button { editTarget = SlotTarget(day: day, slot: slot) } label: {
            MealSlotCard(
                slot: slot,
                entry: entry,
                onCook: { if let entry { Task { await cook(entry) } } },
                onAddMissing: { if let entry { Task { await store.markMissingNeeded(for: entry) } } })
                .frame(width: 180, alignment: .topLeading)
                .padding(12)
                .background(entry == nil ? Palette.surface : Palette.meals, in: .rect(cornerRadius: 16))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mealSlot-\(day)-\(slot.rawValue)")
        .contextMenu {
            if let entry {
                Button("Cook") { Task { await cook(entry) } }
                Button("Add Missing to Shopping") { Task { await store.markMissingNeeded(for: entry) } }
                Divider()
                Button("Remove from Menu", role: .destructive) {
                    Task { try? await store.unassign(day: day, slot: slot) }
                }
            } else {
                Button("Choose Meal…") { editTarget = SlotTarget(day: day, slot: slot) }
            }
        }
    }

    private func suggestWeek() async {
        isSuggesting = true
        defer { isSuggesting = false }
        do {
            try await store.suggestWeek()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func cook(_ entry: MealEntry) async {
        do { try await store.cookMeal(entry) } catch { errorMessage = error.localizedDescription }
    }
}
#endif
