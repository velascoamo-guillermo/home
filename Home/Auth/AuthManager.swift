import SwiftUI

@MainActor
@Observable
final class AuthManager {
    var isAuthenticated = false
    var isLoading = false

    func signIn(email: String, password: String) async {
        isLoading = true
        try? await Task.sleep(for: .seconds(1))
        if !email.isEmpty && !password.isEmpty {
            isAuthenticated = true
        }
        isLoading = false
    }

    func signOut() {
        isAuthenticated = false
    }
}
