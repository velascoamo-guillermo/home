import SwiftUI

struct TaskSectionPicker: View {
    @Environment(SupabaseStore.self) private var store
    @Binding var selectedSection: TaskSection.Predefined
    @Binding var selectedSectionId: UUID?
    @Environment(\.dismiss) private var dismiss

    @State private var showAddCustom = false

    var body: some View {
        NavigationStack {
            List {
                Section("Predefined") {
                    ForEach(TaskSection.Predefined.allCases, id: \.self) { section in
                        sectionRow(
                            name: section.name,
                            isSelected: selectedSectionId == nil && selectedSection == section
                        ) {
                            selectedSection = section
                            selectedSectionId = nil
                            dismiss()
                        }
                    }
                }

                Section("Custom") {
                    ForEach(store.customSections) { section in
                        sectionRow(
                            name: section.name,
                            isSelected: selectedSectionId == section.id
                        ) {
                            selectedSectionId = section.id
                            dismiss()
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                Task { try? await store.deleteCustomSection(section) }
                            } label: {
                                Label("Delete", systemImage: "trash")
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

    private func sectionRow(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(name)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
        }
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
