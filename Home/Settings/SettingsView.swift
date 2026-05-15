import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SettingsRow(icon: "person.circle", title: "Profile", subtitle: "Manage your account")
                    SettingsRow(icon: "bell", title: "Notifications", subtitle: "Pet reminders & alerts")
                    SettingsRow(icon: "shield", title: "Privacy", subtitle: "Data & security settings")
                }

                Section {
                    SettingsRow(icon: "questionmark.circle", title: "Help & Support", subtitle: "Get assistance")
                    SettingsRow(icon: "info.circle", title: "About", subtitle: "App version & info")
                }

                Section {
                    Button {
                        authManager.signOut()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(.red)
                            Text("Sign Out")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthManager())
}
