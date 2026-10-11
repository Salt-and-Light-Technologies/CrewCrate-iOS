import SwiftUI

struct CreateAccountView: View {
    @Environment(AuthenticationViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var viewModel = viewModel
        AuthenticationLayout(title: "Create your account", subtitle: "Create your login, then set up your business.") {
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
                        .submitLabel(.go)
                        .onSubmit { Task { await viewModel.createAccount() } }
                }
                Text("After confirming your email and signing in, you’ll enter your business information to create your workspace.").font(.footnote).foregroundStyle(.secondary)
                Button("Create account") { Task { await viewModel.createAccount() } }
                    .buttonStyle(AuthenticationButtonStyle())
                Button("Already have an account? Log in") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 8)
            }
        }
        .navigationTitle("Create account")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(viewModel.isBusy)
    }
}
