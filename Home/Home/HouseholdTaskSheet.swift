import SwiftUI

struct HouseholdTaskSheet: View {
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let existing: HouseholdTask?

    @State private var title = ""
    @State private var icon = "wrench"
    @State private var sectionId: UUID? = nil
    @State private var intervalValue = 1
    @State private var intervalUnit  = IntervalUnit.months
    @State private var nextDueDate   = Date.now
    @State private var notes = ""
    @State private var showSectionPicker = false

    private var isEditing: Bool { existing != nil }

    init(existing: HouseholdTask? = nil) {
        self.existing = existing
        if let t = existing {
            _title         = State(initialValue: t.title)
            _icon          = State(initialValue: t.icon)
            _sectionId     = State(initialValue: t.sectionId)
            _nextDueDate   = State(initialValue: t.nextDueDate)
            _notes         = State(initialValue: t.notes)
            let (val, unit) = IntervalUnit.decompose(days: t.intervalDays)
            _intervalValue = State(initialValue: val)
            _intervalUnit  = State(initialValue: unit)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Name", text: $title)

                    Button {
                        showSectionPicker = true
                    } label: {
                        HStack {
                            Text("Section")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: icon)
                                .foregroundStyle(.accent)
                            Text(sectionLabel)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Schedule") {
                    DatePicker("Due date", selection: $nextDueDate, displayedComponents: .date)
                    HStack {
                        Text("Repeat every")
                        Spacer()
                        Stepper("\(intervalValue)", value: $intervalValue, in: 1...99)
                        Picker("", selection: $intervalUnit) {
                            ForEach(IntervalUnit.allCases) { unit in
                                Text(unit.label).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showSectionPicker) {
                TaskSectionPicker(selectedIcon: $icon, selectedSectionId: $sectionId)
            }
        }
    }

    private var sectionLabel: String {
        if let id = sectionId,
           let custom = store.customSections.first(where: { $0.id == id }) {
            return custom.name
        }
        return TaskSection.Predefined.allCases
            .first(where: { $0.icon == icon })?.name ?? icon
    }

    private func save() {
        var task = existing ?? HouseholdTask(title: "", icon: icon, intervalDays: 1, nextDueDate: nextDueDate)
        task.title        = title.trimmingCharacters(in: .whitespaces)
        task.icon         = icon
        task.sectionId    = sectionId
        task.intervalDays = intervalUnit.toDays(intervalValue)
        task.nextDueDate  = nextDueDate
        task.notes        = notes.trimmingCharacters(in: .whitespaces)

        Task {
            if isEditing {
                try? await store.updateTask(task)
            } else {
                try? await store.addTask(task)
            }
            dismiss()
        }
    }
}

// MARK: - IntervalUnit

private enum IntervalUnit: String, CaseIterable, Identifiable {
    case days, weeks, months

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    func toDays(_ value: Int) -> Int {
        switch self {
        case .days:   return value
        case .weeks:  return value * 7
        case .months: return value * 30
        }
    }

    static func decompose(days: Int) -> (Int, IntervalUnit) {
        if days % 30 == 0 { return (days / 30, .months) }
        if days % 7  == 0 { return (days / 7,  .weeks)  }
        return (days, .days)
    }
}
