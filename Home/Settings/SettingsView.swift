// Home/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    SettingsRow(icon: "questionmark.circle", title: "Help & Support", subtitle: "Get assistance")
                    SettingsRow(icon: "info.circle", title: "About", subtitle: "App version & info")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
