#if os(macOS)
import Foundation

enum PetFileImporter {
    struct Failure: Equatable {
        let name: String
        let reason: String
    }

    static func importFiles(_ urls: [URL], petID: UUID, into store: SupabaseStore) async -> [Failure] {
        var failures: [Failure] = []
        for url in urls {
            do {
                let payload = try PetFileImport.payload(for: url)
                try await store.uploadFile(data: payload.data, ext: payload.ext, petId: petID,
                                           linkedToType: "standalone", linkedToId: nil)
            } catch {
                failures.append(Failure(name: url.lastPathComponent, reason: error.localizedDescription))
            }
        }
        return failures
    }

    static func message(for failures: [Failure]) -> String? {
        guard !failures.isEmpty else { return nil }
        return failures
            .map { $0.reason.hasPrefix($0.name) ? $0.reason : "\($0.name): \($0.reason)" }
            .joined(separator: "\n")
    }
}
#endif
