import SwiftUI

extension View {
    /// Inset-grouped list over the app canvas with inter-row spacing so rows
    /// read as separate flat cards.
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
            .listRowSpacing(10)
            .gradientCanvas()
        #endif
    }

    /// Flat pastel backing for a list row, matching the dashboard card look.
    func pastelRow(_ fill: Color) -> some View {
        self
            .listRowSeparator(.hidden)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 16).fill(fill)
            )
    }
}
