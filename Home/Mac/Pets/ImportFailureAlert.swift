#if os(macOS)
import SwiftUI

extension View {
    /// Shared with `MacPetDetailView` (file picker) and `MacPetFilesView` (drag and drop) so
    /// both file-import paths show the exact same alert title and dismissal behavior instead of
    /// each carrying its own copy.
    func importFailureAlert(_ message: Binding<String?>) -> some View {
        alert("Some Files Weren't Added", isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
#endif
