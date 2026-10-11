import SwiftUI

struct UpdatePasswordView: View {
    @Environment(AuthenticationViewModel.self) private var viewModel
    var body: some View {
        @Bindable var viewModel = viewModel
        AuthenticationLayout(title: "Choose a new password", subtitle: "Use at least 8 characters.") {
            VStack(spacing: 20) {
                AuthenticationField(label: "New password") {
                    SecureField("New password", text: $viewModel.password).textContentType(.newPassword)
                }
                AuthenticationField(label: "Confirm password") {
                    SecureField("Re-enter your password", text: $viewModel.confirmPassword).textContentType(.newPassword)
                }
                Button("Save password") { Task { await viewModel.saveNewPassword() } }
                    .buttonStyle(AuthenticationButtonStyle())
                Button("Back to login") { Task { await viewModel.signOut() } }
            }
        }
        .disabled(viewModel.isBusy)
    }
}
