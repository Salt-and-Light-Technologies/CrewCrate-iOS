import SwiftUI

struct CreateAccountView: View {
    @Environment(AuthenticationViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingBusinessQuestions = false
    @State private var isWorker = false

    var body: some View {
        @Bindable var viewModel = viewModel
        AuthenticationLayout(title: "Create your account", subtitle: isWorker ? "Join your business team" : "Step 1 of 2 · Your login details") {
            VStack(spacing: 20) {
                Toggle("I have a worker invitation", isOn: $isWorker)
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
                Text(isWorker ? "Create your own login, verify your email, then sign in and enter your invitation code. Use the email your business invited." : "Next, tell us about your business. Your account won’t be created yet.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button(isWorker ? "Create worker account" : "Continue") {
                    if isWorker { Task { await viewModel.createWorkerAccount() } }
                    else { continueSignup() }
                }
                .buttonStyle(AuthenticationButtonStyle())
                if isWorker && viewModel.signupComplete {
                    Text("Account request completed. Check your email for verification, then log in to accept your invitation.").foregroundStyle(.secondary)
                }
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
