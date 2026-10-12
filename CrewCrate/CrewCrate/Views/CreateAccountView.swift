import SwiftUI

struct CreateAccountView: View {
    @Environment(AuthenticationViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingBusinessQuestions = false

    var body: some View {
        @Bindable var viewModel = viewModel
        AuthenticationLayout(title: "Create your account", subtitle: "Step 1 of 2 · Your login details") {
            VStack(spacing: 20) {
                AuthenticationField(label: "Email") {
                    TextField("you@company.com", text: $viewModel.email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                AuthenticationField(label: "Password") {
                    SecureField("At least 8 characters", text: $viewModel.password)
                        .textContentType(.newPassword)
                }
                AuthenticationField(label: "Confirm password") {
                    SecureField("Re-enter your password", text: $viewModel.confirmPassword)
                        .textContentType(.newPassword)
                        .submitLabel(.next)
                        .onSubmit { continueSignup() }
                }
                Text("Next, tell us about your business. Your account won’t be created yet.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Continue") { continueSignup() }
                    .buttonStyle(AuthenticationButtonStyle())
                Button("Already have an account? Log in") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 8)
            }
        }
        .navigationTitle("Create account")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(viewModel.isBusy)
        .navigationDestination(isPresented: $showingBusinessQuestions) {
            SignupBusinessView()
        }
        .onAppear { viewModel.signupComplete = false }
    }

    private func continueSignup() {
        guard viewModel.validateAccountDetails() else { return }
        viewModel.signupBusiness.email = viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines)
        showingBusinessQuestions = true
    }
}
