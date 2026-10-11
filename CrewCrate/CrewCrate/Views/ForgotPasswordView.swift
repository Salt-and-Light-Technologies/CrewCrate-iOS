import SwiftUI

struct ForgotPasswordView: View {
    @State private var viewModel = AuthenticationViewModel()

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
                        .onSubmit { viewModel.resetPassword() }
                }
                Button("Send reset link") { viewModel.resetPassword() }
                    .buttonStyle(AuthenticationButtonStyle())
            }
        }
        .navigationTitle("Forgot password")
        .navigationBarTitleDisplayMode(.inline)
        .alert("CrewCrate", isPresented: Binding(get: { viewModel.notice != nil }, set: { if !$0 { viewModel.notice = nil } })) {
            Button("OK", role: .cancel) { viewModel.notice = nil }
        } message: {
            Text(viewModel.notice ?? "")
        }
    }
}
