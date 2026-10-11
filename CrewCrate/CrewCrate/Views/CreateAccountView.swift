import SwiftUI

struct CreateAccountView: View {
    @Environment(AuthenticationViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var viewModel = viewModel
        AuthenticationLayout(title: "Create your account", subtitle: "Get started with CrewCrate.") {
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
