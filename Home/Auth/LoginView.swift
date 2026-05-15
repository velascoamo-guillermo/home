import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var email = ""
    @State private var password = ""

    private let gradientStart = Color(red: 1.0, green: 0.45, blue: 0.2)
    private let gradientEnd = Color(red: 0.65, green: 0.25, blue: 0.75)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [gradientStart, gradientEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "pawprint.circle.fill")
                        .font(.system(size: 90))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
                        .accessibilityHidden(true)

                    Text("Pet Home")
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(.white)

                    Text("Welcome back!")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.plain)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(.white)
                        .tint(.white)
                        .padding()
                        .glassEffect(in: RoundedRectangle(cornerRadius: 14))

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .foregroundStyle(.white)
                        .tint(.white)
                        .padding()
                        .glassEffect(in: RoundedRectangle(cornerRadius: 14))

                    Button(action: signIn) {
                        HStack(spacing: 10) {
                            if authManager.isLoading {
                                ProgressView()
                                    .tint(gradientStart)
                                    .scaleEffect(0.85)
                            }
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(gradientStart)
                        .padding()
                        .background(.white)
                        .clipShape(Capsule())
                    }
                    .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                }
                .padding(.horizontal, 28)

                Spacer()

                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .foregroundStyle(.white.opacity(0.8))
                    Button("Sign Up") {}
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 36)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func signIn() {
        Task {
            await authManager.signIn(email: email, password: password)
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthManager())
}
