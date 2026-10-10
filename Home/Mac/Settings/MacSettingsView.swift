#if os(macOS)
import SwiftUI

/// The system Settings window: noncustomizable pane toolbar, title follows the pane,
/// last pane restored through AppStorage.
struct MacSettingsView: View {
    @AppStorage(UITestSupport.macSettingsPaneKey) private var pane = MacSettingsPane.calendars

    var body: some View {
        TabView(selection: $pane) {
            ForEach(MacSettingsPane.allCases, id: \.self) { pane in
                Tab(pane.title, systemImage: pane.systemImage, value: pane) {
                    content(for: pane)
                }
            }
        }
        .frame(width: 480, height: 380)
    }

    @ViewBuilder
    private func content(for pane: MacSettingsPane) -> some View {
        switch pane {
        case .calendars: MacCalendarsSettingsPane()
        case .sync:      MacSyncSettingsPane()
        }
    }
}
#endif
