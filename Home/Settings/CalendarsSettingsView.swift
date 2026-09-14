import SwiftUI
import UIKit

struct CalendarsSettingsView: View {
    @Environment(CalendarFeed.self) private var feed
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                switch feed.accessState {
                case .fullAccess:
                    Label("Calendar events show in your agenda", systemImage: "checkmark.circle.fill")
                case .notDetermined:
                    Button("Allow calendar access") { Task { await feed.requestAccess() } }
                case .denied:
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                case .restricted:
                    Text("Calendar access is restricted on this device")
                }
            }

            if feed.accessState == .fullAccess {
                Section("Show in agenda") {
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
                                    .frame(width: 12, height: 12)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .gradientCanvas()
        .navigationTitle("Calendars")
        .task {
            await feed.reload()
            await feed.loadCalendars()
        }
    }
}

#Preview {
    NavigationStack {
        CalendarsSettingsView()
            .environment(CalendarFeed(source: FakeCalendarSource.uiTestFixture()))
    }
}
