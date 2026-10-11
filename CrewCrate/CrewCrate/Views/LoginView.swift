import SwiftUI

struct LoginView: View {
    @State private var viewModel = AuthenticationViewModel()
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
                        .onSubmit { focusedField = nil; viewModel.login() }
                }
                NavigationLink("Forgot password?") {
                    ForgotPasswordView()
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.vertical, 4)

                Button("Log in") {
                    focusedField = nil
                    viewModel.login()
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
        .alert("CrewCrate", isPresented: Binding(get: { viewModel.notice != nil }, set: { if !$0 { viewModel.notice = nil } })) {
            Button("OK", role: .cancel) { viewModel.notice = nil }
        } message: {
            Text(viewModel.notice ?? "")
        }
    }
}
