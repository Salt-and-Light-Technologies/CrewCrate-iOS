import SwiftUI

struct BusinessProfileView: View {
    @State var viewModel: BusinessViewModel
    var onSaved: (() -> Void)?
    var body: some View {
        @Bindable var viewModel = viewModel
        Form {
            if viewModel.workspaces.count > 1 {
                Section("Business") {
                    Picker("Select business", selection: Binding(get: { viewModel.selectedID }, set: { viewModel.select($0) })) {
                        ForEach(viewModel.workspaces) { business in
                            Text(business.onboarding.business_name).tag(Optional(business.id))
                        }
                    }
                }
            }
            Section {
                TextField("Business name (required)", text: $viewModel.details.business_name)
                TextField("Industry", text: $viewModel.details.industry)
                TextField("Website", text: $viewModel.details.website)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Services or products", text: $viewModel.details.services, axis: .vertical).lineLimit(2...6)
                TextField("Service area", text: $viewModel.details.service_area)
                TextField("Time zone (e.g. America/Chicago)", text: $viewModel.details.time_zone)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("What should the AI avoid or escalate?", text: $viewModel.details.ai_boundaries, axis: .vertical).lineLimit(2...6)
            } header: { Text("Business information") } footer: {
                Text("This information helps your campaign assistant describe your business accurately. Saving creates your workspace; it does not start outreach. Changes to a reviewed business require a new readiness review.")
            }
            .disabled(viewModel.isBusy || !viewModel.hasLoaded)
            Section {
                Button(viewModel.selectedID == nil ? "Create business" : "Save business changes") {
                    Task { if await viewModel.save() { onSaved?() } }
                }.disabled(!viewModel.canSave)
                if viewModel.saved { Text("Business information saved.").foregroundStyle(.green) }
                if let error = viewModel.error {
                    Text(error).foregroundStyle(.red)
                    Button("Reload business information") { Task { await viewModel.load() } }
                }
            }
        }
        .navigationTitle(viewModel.selectedID == nil ? "Set up your business" : "Business profile")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if viewModel.isBusy { ProgressView() } }
        .task { if !viewModel.hasLoaded { await viewModel.load() } }
    }
}
