import SwiftUI
import PhotosUI

struct AccountView: View {
    @Environment(AuthenticationViewModel.self) private var authentication
    @State var viewModel: AccountViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        Form {
            Section {
                VStack(spacing: 12) {
                    Group {
                        if let data = viewModel.photoData, let image = UIImage(data: data) {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundStyle(AuthenticationStyle.purple)
                        }
                    }
                    .frame(width: 100, height: 100).clipShape(Circle())
                    .accessibilityLabel("User photo")
                    PhotosPicker(selection: $viewModel.selectedPhoto, matching: .images) {
                        Text("Change photo").fontWeight(.semibold)
                    }
                    .disabled(viewModel.isBusy)
                    Text("Your photo is saved on this device.").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            Section("Personal information") {
                TextField("First name", text: $viewModel.firstName).textContentType(.givenName)
                TextField("Last name", text: $viewModel.lastName).textContentType(.familyName)
            }
            .disabled(viewModel.isBusy || !viewModel.hasLoaded)
            Section {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                if let pending = viewModel.pendingEmail {
                    Text("Awaiting confirmation: \(pending)").font(.footnote).foregroundStyle(.secondary)
                }
            } header: { Text("Email address") } footer: {
                Text("Changing your email may require confirmation from both your current and new email addresses.")
            }
            .disabled(viewModel.isBusy || !viewModel.hasLoaded)
            Section {
                Button("Save changes") { Task { await viewModel.save() } }
                    .disabled(viewModel.isBusy || !viewModel.hasLoaded)
                if !viewModel.hasLoaded && !viewModel.isLoading {
                    Button("Retry loading account") { Task { await viewModel.load() } }
                }
            }
            Section {
                Button("Log out", role: .destructive) { Task { await authentication.signOut() } }
                    .disabled(viewModel.isBusy || authentication.isBusy)
            }
        }
        .navigationTitle("Account")
        .refreshable { await viewModel.load() }
        .overlay { if viewModel.isBusy { ProgressView().padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) } }
        .task { if !viewModel.hasLoaded { await viewModel.load() } }
        .onChange(of: viewModel.selectedPhoto) { _, _ in Task { await viewModel.changePhoto() } }
        .alert("Account", isPresented: Binding(get: { viewModel.notice != nil }, set: { if !$0 { viewModel.notice = nil } })) {
            Button("OK", role: .cancel) { viewModel.notice = nil }
        } message: { Text(viewModel.notice ?? "") }
    }
}
