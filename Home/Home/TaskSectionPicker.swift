import SwiftUI

struct TaskSectionPicker: View {
    @Environment(SupabaseStore.self) private var store
    @Binding var selectedSection: TaskSection.Predefined
    @Binding var selectedSectionId: UUID?
    @Environment(\.dismiss) private var dismiss

    @State private var showAddCustom = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Predefined")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        ChipGroup(
                            items: TaskSection.Predefined.allCases,
                            selection: predefinedSelection,
                            fill: Palette.tasks,
                            title: \.name
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        FlowLayout(spacing: 8) {
                            ForEach(store.customSections) { section in
                                Chip(
                                    title: section.name,
                                    fill: Palette.surface,
                                    isSelected: selectedSectionId == section.id,
                                    action: { selectCustom(section) }
                                )
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task { try? await store.deleteCustomSection(section) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }

                        Button {
                            showAddCustom = true
                        } label: {
                            Label("New Section", systemImage: "plus.circle.fill")
                        }
                    }
                }
                .padding()
            }
            .gradientCanvas()
            .navigationTitle("Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddCustom) {
                AddCustomSectionSheet { newSection in
                    selectedSectionId = newSection.id
                    dismiss()
                }
            }
        }
    }

    /// Bridges the two-binding contract (`selectedSection` + `selectedSectionId`) to a single
    /// optional selection so the "Predefined" `ChipGroup` shows no highlight while a custom
    /// section is active, and any tap dismisses (matching the previous row-tap behavior).
    private var predefinedSelection: Binding<TaskSection.Predefined?> {
        Binding(
            get: { selectedSectionId == nil ? selectedSection : nil },
            set: { newValue in
                selectedSection = newValue ?? selectedSection
                selectedSectionId = nil
                dismiss()
            }
        )
    }

    private func selectCustom(_ section: TaskSection) {
        selectedSectionId = section.id
        dismiss()
    }
}

// MARK: - Add Custom Section Sheet

private struct AddCustomSectionSheet: View {
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let onCreated: (TaskSection) -> Void

    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Section") {
                    TextField("Name", text: $name)
                }
            }
            .scrollContentBackground(.hidden)
            .gradientCanvas()
            .navigationTitle("New Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let section = TaskSection(id: UUID(), name: name.trimmingCharacters(in: .whitespaces))
        Task {
            try? await store.addCustomSection(section)
            onCreated(section)
            dismiss()
        }
    }
}
