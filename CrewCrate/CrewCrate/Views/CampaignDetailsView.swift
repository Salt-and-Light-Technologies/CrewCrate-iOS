import SwiftUI

struct CampaignDetailsView: View {
    @State private var confirmsDiscard = false
    @State var viewModel: CampaignDetailsViewModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Form {
                if viewModel.workspaces.isEmpty {
                    Section { Text("Your account needs an assigned workspace before you can save a campaign.").foregroundStyle(.secondary) }
                } else {
                    Section("Workspace") {
                        Picker("Workspace", selection: $viewModel.workspaceID) {
                            Text("Select a workspace").tag(nil as UUID?)
                            ForEach(viewModel.workspaces.filter { $0.status != "paused" }) { space in
                                Text(space.name).tag(Optional(space.id))
                            }
                        }
                    }
                }
                Section("Campaign details") {
                    TextField("Campaign name", text: $viewModel.details.name)
                    TextField("Promotion or offer", text: $viewModel.details.offer, axis: .vertical).lineLimit(3...6)
                }
                Section("Test your assistant") {
                    Button("Test AI", systemImage: "bubble.left.and.bubble.right") { viewModel.showsAITest = true }
                        .disabled(viewModel.workspaceID == nil || viewModel.details.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text("Try the current details without saving a campaign or contacting real leads.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("AI assistant") {
                    TextField("AI name", text: Binding(get: { viewModel.details.aiName ?? "" }, set: { viewModel.details.aiName = $0 }))
                    TextField("Instructions and goals", text: Binding(get: { viewModel.details.aiBrief ?? "" }, set: { viewModel.details.aiBrief = $0 }), axis: .vertical).lineLimit(4...8)
                }
                Section("Sales handoff") {
                    TextField("Qualification and handoff rules", text: $viewModel.details.qualification, axis: .vertical).lineLimit(3...6)
                    TextField("Sales email", text: $viewModel.details.handoffEmail)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section {
                    Text("Save these details as a draft. Recipients and campaign preparation will be added next.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .disabled(viewModel.isSaving)
            .navigationTitle("Campaign details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if viewModel.hasEdits { confirmsDiscard = true } else { dismiss() } }.disabled(viewModel.isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save draft") { Task { if await viewModel.save() { dismiss() } } }
                        .disabled(!viewModel.canSave)
                }
            }
            .sheet(isPresented: $viewModel.showsAITest) {
                if let partnerID = viewModel.workspaceID {
                    AITestView(viewModel: AITestViewModel(service: viewModel.service, partnerID: partnerID, config: viewModel.details))
                }
            }
            .confirmationDialog("Discard campaign details?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .overlay { if viewModel.isSaving { ProgressView() } }
            .alert("Campaign", isPresented: Binding(get: { viewModel.notice != nil }, set: { if !$0 { viewModel.notice = nil } })) {
                Button("OK", role: .cancel) { viewModel.notice = nil }
            } message: { Text(viewModel.notice ?? "") }
        }
    }
}
