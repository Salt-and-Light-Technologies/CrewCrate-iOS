import SwiftUI

struct LoginView: View {
    @Environment(AuthenticationViewModel.self) private var viewModel
    @FocusState private var focusedField: Field?
    private enum Field { case email, password }

    var body: some View {
        @Bindable var viewModel = viewModel
        AuthenticationLayout(title: "Welcome back", subtitle: "Log in to your CrewCrate account.") {
            VStack(spacing: 20) {
                AuthenticationField(label: "Email") {
                    TextField("you@company.com", text: $viewModel.email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }
                AuthenticationField(label: "Password") {
                    SecureField("Enter your password", text: $viewModel.password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { focusedField = nil; Task { await viewModel.login() } }
                }
                NavigationLink("Forgot password?") {
                    ForgotPasswordView()
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.vertical, 4)

                Button("Log in") {
                    focusedField = nil
                    Task { await viewModel.login() }
                }
                .buttonStyle(AuthenticationButtonStyle())

                VStack(spacing: 8) {
                    Text("New to CrewCrate?").foregroundStyle(.secondary)
                    NavigationLink("Create an account") {
                        CreateAccountView()
                    }
                    .fontWeight(.semibold)
                    .padding(.vertical, 8)
                }
                .font(.subheadline)
                .padding(.top, 8)
            }
        }
        .disabled(viewModel.isBusy)
    }
}
