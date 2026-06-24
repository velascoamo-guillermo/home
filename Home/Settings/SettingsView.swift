import SwiftUI

struct SettingsView: View {
    @Environment(ThemeStore.self) private var theme

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 16)]

    var body: some View {
        @Bindable var theme = theme
        List {
            Section("Appearance") {
                Picker("Appearance", selection: $theme.appearance) {
                    ForEach(AppAppearance.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Primary Color") {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(ThemeStore.presets, id: \.self) { hex in
                        Button {
                            theme.tintHex = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex) ?? .clear)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if theme.tintHex == hex {
                                        Circle().strokeBorder(.primary, lineWidth: 3)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Color \(hex)")
                    }
                }
                .padding(.vertical, 8)

                ColorPicker(
                    "Custom",
                    selection: Binding(
                        get: { theme.tint },
                        set: { theme.tintHex = $0.toHex() }
                    ),
                    supportsOpacity: false
                )
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(ThemeStore())
    }
}
