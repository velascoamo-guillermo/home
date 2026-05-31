// Home/Pets/Claude/ExtractionResultSheet.swift
import SwiftUI

struct ExtractionResultSheet: View {
    let file: PetFile
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var result: ExtractionResult? = nil
    @State private var error: String? = nil
    @State private var isLoading = false
    @State private var editedDiagnosis = ""
    @State private var editedRecommendations = ""

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Analyzing document with Claude…")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error {
                    ContentUnavailableView(
                        "Extraction Failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    ).padding()
                } else if let result {
                    extractionForm(result: result)
                }
            }
            .navigationTitle("Extracted Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if result != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save to History") { saveToHistory() }
                    }
                }
            }
        }
        .task { await extract() }
    }

    @ViewBuilder
    private func extractionForm(result: ExtractionResult) -> some View {
        Form {
            if let date = result.visitDate {
                Section("Visit Date") {
                    Text(date.formatted(date: .long, time: .omitted))
                }
            }
            Section("Diagnosis / Findings") {
                TextField("Diagnosis", text: $editedDiagnosis, axis: .vertical).lineLimit(2...5)
            }
            if !result.testResults.isEmpty {
                Section("Test Results") {
                    ForEach(Array(result.testResults.keys.sorted()), id: \.self) { key in
                        LabeledContent(key, value: result.testResults[key] ?? "")
                    }
                }
            }
            if !result.medications.isEmpty {
                Section("Medications") {
                    ForEach(result.medications, id: \.self) { med in Text(med) }
                }
            }
            Section("Recommendations") {
                TextField("Recommendations", text: $editedRecommendations, axis: .vertical).lineLimit(2...5)
            }
        }
        .onAppear {
            editedDiagnosis = result.diagnosis
            editedRecommendations = result.recommendations
        }
    }

    private func extract() async {
        isLoading = true
        do {
            let fileURL = store.fileUrl(for: file)
            result = try await store.analyzeFile(fileURL: fileURL, file: file, petName: pet.name)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func saveToHistory() {
        guard let result else { return }
        let entry = ClinicalEntry(
            petId: pet.id,
            date: result.visitDate ?? .now,
            title: editedDiagnosis.isEmpty ? "Vet Report" : String(editedDiagnosis.prefix(50)),
            description: [editedDiagnosis,
                          result.medications.isEmpty ? "" : "Medications: \(result.medications.joined(separator: ", "))",
                          editedRecommendations].filter { !$0.isEmpty }.joined(separator: "\n\n")
        )
        Task {
            try? await store.addClinicalEntry(entry)
            if let i = store.files.firstIndex(where: { $0.id == file.id }) {
                var updated = store.files[i]
                updated.linkedToType = "clinicalEntry"
                updated.linkedToId = entry.id
                try? await store.updateFileLink(updated)
            }
            dismiss()
        }
    }
}
