import SwiftUI

struct DashboardEditView: View {
    @Binding var config: DashboardConfig
    let onChange: (DashboardConfig) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Active") {
                    ForEach(config.cards) { card in
                        row(card, enabled: true)
                    }
                    .onMove { from, to in
                        config.move(fromOffsets: from, toOffset: to)
                        onChange(config)
                    }
                }
                if !config.disabledCards.isEmpty {
                    Section("Available") {
                        ForEach(config.disabledCards) { card in
                            row(card, enabled: false)
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Edit Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ card: DashboardCard, enabled: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: card.systemImage)
                .foregroundStyle(.tint)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(card.title)
            Spacer()
            Button {
                config.setEnabled(card, !enabled)
                onChange(config)
            } label: {
                Image(systemName: enabled ? "minus.circle.fill" : "plus.circle.fill")
                    .foregroundStyle(enabled ? .red : .green)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(enabled ? "Remove \(card.title)" : "Add \(card.title)")
        }
    }
}
