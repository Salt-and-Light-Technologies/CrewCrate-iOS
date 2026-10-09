import SwiftUI
struct AccountSalesHandoffSection: View {
    @Bindable var viewModel: SalesHandoffViewModel
    var body: some View {
        Section("Sales handoff emails") {
            Text(viewModel.partnerName).font(.caption).foregroundStyle(.secondary)
            ForEach(viewModel.emails, id: \.self) { Text($0) }
            TextField("Add sales handoff email", text: $viewModel.newEmail)
                .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Save email") { Task { await viewModel.add() } }.disabled(viewModel.isBusy)
            if let error = viewModel.errorMessage { Text(error).foregroundStyle(.red) }
            if viewModel.isBusy { ProgressView() }
        }.task { await viewModel.load() }
    }
}
