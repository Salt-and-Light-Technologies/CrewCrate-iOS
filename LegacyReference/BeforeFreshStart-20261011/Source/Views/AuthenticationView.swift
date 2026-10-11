import SwiftUI

struct AuthenticationView: View {
    @Bindable var viewModel: SessionViewModel
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image("CrateMark").resizable().scaledToFit().frame(width: 72, height: 72)
                        Text("Welcome to CrewCrate").font(.title2.bold())
                        Text("Sign in to your partner workspace.").foregroundStyle(.secondary)
                    }.padding(.vertical)
                }
                Section("Your account") {
                    TextField("Email", text: $viewModel.email).textContentType(.username).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Password", text: $viewModel.password).textContentType(.password)
                    Button { Task { await viewModel.signIn() } } label: {
                        if viewModel.isBusy { ProgressView() } else { Text("Sign in").fontWeight(.semibold) }
                    }.disabled(viewModel.isBusy)
                }.disabled(viewModel.isBusy)
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                        Button("Retry workspace connection") { Task { await viewModel.reconnect() } }.disabled(viewModel.isBusy)
                    }
                }
                Section {
                    Text("New partner? Your CrewCrate administrator must create your account and assign your business workspace. Invitation acceptance is coming next.").font(.footnote).foregroundStyle(.secondary)
                }
            }.navigationTitle("Sign in")
        }
    }
}
