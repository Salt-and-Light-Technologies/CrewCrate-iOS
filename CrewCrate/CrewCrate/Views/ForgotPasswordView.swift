import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AuthenticationViewModel.self) private var viewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        AuthenticationLayout(title: "Reset your password", subtitle: "Enter the email address associated with your account.") {
            VStack(spacing: 20) {
                AuthenticationField(label: "Email") {
                    TextField("you@company.com", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.send)
                        .onSubmit { Task { await viewModel.resetPassword() } }
                }
                Button("Send reset link") { Task { await viewModel.resetPassword() } }
                    .buttonStyle(AuthenticationButtonStyle())
            }
        }
        .navigationTitle("Forgot password")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(viewModel.isBusy)
    }
}
