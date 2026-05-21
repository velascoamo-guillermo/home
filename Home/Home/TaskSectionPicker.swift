import SwiftUI

struct TaskSectionPicker: View {
    @Environment(SupabaseStore.self) private var store
    @Binding var selectedIcon: String
    @Binding var selectedSectionId: UUID?
    @Environment(\.dismiss) private var dismiss

    @State private var showAddCustom = false

    var body: some View {
        NavigationStack {
            List {
                Section("Predefined") {
                    ForEach(TaskSection.Predefined.allCases, id: \.self) { section in
                        sectionRow(
                            icon: section.icon,
                            name: section.name,
                            isSelected: selectedSectionId == nil && selectedIcon == section.icon
                        ) {
                            selectedIcon = section.icon
                            selectedSectionId = nil
                            dismiss()
                        }
                    }
                }

                Section("Custom") {
                    ForEach(store.customSections) { section in
                        sectionRow(
                            icon: section.icon,
                            name: section.name,
                            isSelected: selectedSectionId == section.id
                        ) {
                            selectedIcon = section.icon
                            selectedSectionId = section.id
                            dismiss()
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
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
                    selectedIcon = newSection.icon
                    selectedSectionId = newSection.id
                    dismiss()
                }
            }
        }
    }

    private func sectionRow(icon: String, name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 28)
                    .foregroundStyle(.accent)
                Text(name)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.accent)
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
    @State private var icon = "star"
    @State private var showSymbolPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Section") {
                    TextField("Name", text: $name)

                    Button {
                        showSymbolPicker = true
                    } label: {
                        HStack {
                            Text("Icon")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: icon)
                                .foregroundStyle(.accent)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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
            .sheet(isPresented: $showSymbolPicker) {
                SFSymbolPicker(selection: $icon)
            }
        }
    }

    private func save() {
        let section = TaskSection(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            icon: icon
        )
        Task {
            try? await store.addCustomSection(section)
            onCreated(section)
            dismiss()
        }
    }
}
