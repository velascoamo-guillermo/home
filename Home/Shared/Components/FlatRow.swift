import SwiftUI

extension View {
    /// Inset-grouped list over the app canvas; each section is the rounded
    /// container and rows are separated by system separators.
    func flatListStyle() -> some View {
        #if os(macOS)
        self
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .gradientCanvas()
        #else
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .gradientCanvas()
        #endif
    }

    /// Native list row on the pastel canvas: `surface` cell inside an
    /// inset-grouped section on iOS; transparent system row on macOS.
    func surfaceRow() -> some View {
        #if os(macOS)
        self
        #else
        self.listRowBackground(Palette.surface)
        #endif
    }
}
