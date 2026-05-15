import SwiftUI

struct ContentView: View {
    @State private var authManager = AuthManager()
    @State private var dataStore = DataStore()

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .environment(authManager)
        .environment(dataStore)
    }
}

#Preview {
    ContentView()
}
