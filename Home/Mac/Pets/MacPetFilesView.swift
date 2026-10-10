#if os(macOS)
import SwiftUI

struct MacPetFilesView: View {
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var isTargeted = false
    @State private var isImporting = false
    @State private var failureMessage: String?

    var body: some View {
        FilesTabView(pet: pet)
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.tint, lineWidth: 3)
                        .padding(8)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if isImporting {
                    ProgressView("Adding Files…")
                        .padding()
                        .background(Palette.surface, in: .rect(cornerRadius: 12))
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard !urls.isEmpty else { return false }
                Task { await importFiles(urls) }
                return true
            } isTargeted: { isTargeted = $0 }
            .importFailureAlert($failureMessage)
    }

    private func importFiles(_ urls: [URL]) async {
        isImporting = true
        let failures = await PetFileImporter.importFiles(urls, petID: pet.id, into: store)
        isImporting = false
        failureMessage = PetFileImporter.message(for: failures)
    }
}
#endif
