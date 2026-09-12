import SwiftUI

struct SettingsView: View {
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        @Bindable var theme = theme
        List {
            Section("Appearance") {
                ChipGroup(
                    items: AppAppearance.allCases,
                    selection: $theme.appearance,
                    fill: Palette.surface,
                    title: \.label
                )
            }
        }
        .scrollContentBackground(.hidden)
        .gradientCanvas()
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(ThemeStore())
    }
}
