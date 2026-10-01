#if os(macOS)
import SwiftUI

struct MacCalendarsSettingsPane: View {
    @Environment(CalendarFeed.self) private var feed
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                switch feed.accessState {
                case .fullAccess:
                    Label("Calendar events show in Today", systemImage: "checkmark.circle.fill")
                case .notDetermined:
                    Button("Allow Calendar Access") { Task { await feed.requestAccess() } }
                case .denied:
                    Text("Calendar access is off")
                    Button(SystemSettingsURL.openButtonTitle) {
                        if let url = SystemSettingsURL.calendarPrivacy { openURL(url) }
                    }
                case .restricted:
                    Text("Calendar access is restricted on this Mac")
                }
            }
            if feed.accessState == .fullAccess {
                Section("Show in Today") {
                    ForEach(feed.calendars) { calendar in
                        Toggle(isOn: Binding(
                            get: { !feed.excludedIDs.contains(calendar.id) },
                            set: { feed.setCalendar(calendar.id, included: $0) }
                        )) {
                            Label {
                                Text(calendar.title)
                            } icon: {
                                Circle()
                                    .fill(Color(red: calendar.color.red, green: calendar.color.green, blue: calendar.color.blue))
                                    .frame(width: 10, height: 10)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task {
            await feed.reload()
            await feed.loadCalendars()
        }
    }
}
#endif
