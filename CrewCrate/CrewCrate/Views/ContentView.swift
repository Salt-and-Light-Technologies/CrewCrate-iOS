import SwiftUI

struct ContentView: View {
    @State private var viewModel = AuthenticationViewModel()

    var body: some View {
        Group {
            if viewModel.isRestoring {
                ProgressView("Restoring your session…")
            } else if viewModel.needsPasswordUpdate {
                NavigationStack { UpdatePasswordView() }
            } else if viewModel.identity != nil {
                NavigationStack {
                    VStack(spacing: 24) {
                        Image("CrateMark")
                            .resizable().scaledToFit().frame(width: 96, height: 96)
                            .padding(20)
                            .background(AuthenticationStyle.purple, in: RoundedRectangle(cornerRadius: 24))
                        Text("You’re logged in").font(.title.bold())
                        Text("Your CrewCrate account is connected. Your workspace experience is coming next.")
                            .multilineTextAlignment(.center).foregroundStyle(.secondary)
                        Button("Log out") { Task { await viewModel.signOut() } }
                            .buttonStyle(AuthenticationButtonStyle())
                            .disabled(viewModel.isBusy)
                    }
                    .padding(28)
                    .frame(maxWidth: 420)
                    .navigationTitle("CrewCrate")
                }
            } else {
                NavigationStack { LoginView() }
            }
        }
        .environment(viewModel)
        .task { await viewModel.restore() }
        .onOpenURL { url in Task { await viewModel.handleCallback(url) } }
        .alert("CrewCrate", isPresented: Binding(get: { viewModel.notice != nil }, set: { if !$0 { viewModel.notice = nil } })) {
            Button("OK", role: .cancel) { viewModel.notice = nil }
        } message: {
            Text(viewModel.notice ?? "")
        }
        .overlay {
            if viewModel.isBusy && !viewModel.isRestoring {
                ProgressView().padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

#Preview { ContentView() }
