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

            Section("Agenda") {
                NavigationLink {
                    CalendarsSettingsView()
                } label: {
                    Label("Calendars", systemImage: "calendar")
                }
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
            .environment(CalendarFeed(source: FakeCalendarSource.uiTestFixture()))
    }
}
