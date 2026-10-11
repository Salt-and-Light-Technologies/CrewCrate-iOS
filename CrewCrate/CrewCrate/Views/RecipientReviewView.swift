import SwiftUI

struct RecipientReviewView: View {
    @State var viewModel: RecipientReviewViewModel
    var onSaved: (CampaignSummary) -> Void
    var body: some View {
        @Bindable var viewModel = viewModel
        List {
            Section {
                Picker("Lead list (original import source)", selection: $viewModel.listID) {
                    Text("Current campaign leads").tag("campaign")
                    Text("All business leads").tag("all")
                    ForEach(viewModel.batches) { Text("Import: \($0.file_name)").tag($0.id.uuidString) }
                }
                Picker("Show", selection: $viewModel.filter) {
                    Text("All").tag("all")
                    Text("Permission recorded").tag("eligible")
                    Text("Excluded / unknown").tag("excluded")
                }
                Text("\(viewModel.selected.count) selected · \(viewModel.visible.count) shown")
                Button("Select eligible leads shown") { viewModel.selectVisible() }.disabled(!viewModel.hasLoaded)
                Button("Clear selection") { viewModel.selected.removeAll() }
                Text("Only reviewed contacts with recorded SMS permission and no opt-out can be selected. CrewCrate checks your records; it does not verify external consent or DNC databases.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Leads") {
                ForEach(viewModel.visible) { lead in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button { viewModel.toggle(lead) } label: {
                                Image(systemName: viewModel.selected.contains(lead.id) ? "checkmark.circle.fill" : "circle")
                            }.buttonStyle(.borderless).disabled(!lead.eligible_for_sms)
                                .accessibilityLabel(viewModel.selected.contains(lead.id) ? "Deselect lead" : "Select lead")
                            VStack(alignment: .leading) {
                                Text(lead.name.isEmpty ? lead.phone : lead.name).font(.headline)
                                Text(lead.phone).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Text(lead.eligible_for_sms ? "Permission recorded" : lead.exclusion_reasons.joined(separator: "; "))
                            .font(.caption).foregroundStyle(lead.eligible_for_sms ? Color.green : Color.secondary)
                        Button("Review contact permission") { viewModel.reviewingLead = lead }.buttonStyle(.borderless)
                    }.padding(.vertical, 4)
                }
                if viewModel.hasLoaded && viewModel.visible.isEmpty { Text("No leads match this list and filter.").foregroundStyle(.secondary) }
            }
            if let notice = viewModel.notice {
                Section { Text(notice).foregroundStyle(.red) }
            }
            Section {
                Button("Save eligible recipients") {
                    Task { if let saved = await viewModel.saveSelection() { onSaved(saved) } }
                }.disabled(!viewModel.canSave)
                Button("Reload permission checks") { Task { await viewModel.load() } }
            }
        }
        .disabled(viewModel.isBusy)
        .searchable(text: $viewModel.search, prompt: "Name, phone or email")
        .navigationTitle("Review campaign leads")
        .overlay { if viewModel.isBusy { ProgressView() } }
        .task { if !viewModel.hasLoaded { await viewModel.load() } }
        .sheet(item: $viewModel.reviewingLead) { lead in
            NavigationStack {
                LeadPermissionView(viewModel: LeadPermissionViewModel(lead: lead, partnerID: viewModel.campaign.partnerID, service: viewModel.service), onSaved: { viewModel.reviewed($0) })
            }
        }
    }
}

struct LeadPermissionView: View {
    @State var viewModel: LeadPermissionViewModel
    var onSaved: (CampaignLead) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        @Bindable var viewModel = viewModel
        Form {
            Section("Contact") {
                Text(viewModel.lead.name)
                Text(viewModel.lead.phone)
                if !viewModel.lead.permission_evidence.isEmpty {
                    Text(viewModel.lead.permission_evidence).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Review decision") {
                Picker("Decision", selection: $viewModel.action) {
                    if !viewModel.lead.opted_out && viewModel.lead.sms_permission != "revoked" { Text("Record SMS permission").tag("record_permission") }
                    Text("Exclude from outreach").tag("exclude")
                    Text("Record opt-out").tag("opt_out")
                }
                TextField("Evidence reference or exclusion reason", text: $viewModel.evidence, axis: .vertical).lineLimit(3...8)
            }
            if viewModel.action == "record_permission" {
                Section("Permission evidence") {
                    TextField("Source (e.g. signup form / CRM record)", text: $viewModel.source)
                    TextField("Consent date (YYYY-MM-DD)", text: $viewModel.consentDate)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Recipient country code (US, CA, etc.)", text: $viewModel.country)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    Toggle("I reviewed permission for this business’s marketing texts and applicable contact restrictions", isOn: $viewModel.attested)
                    Text("Being in a CSV or a customer list does not establish marketing SMS permission. Record the actual evidence supporting this contact.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            if let error = viewModel.error { Section { Text(error).foregroundStyle(.red) } }
        }
        .disabled(viewModel.isBusy)
        .navigationTitle("Contact permission")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(viewModel.isBusy) }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save review") { Task { if let lead = await viewModel.save() { onSaved(lead); dismiss() } } }.disabled(!viewModel.canSave)
            }
        }
        .interactiveDismissDisabled(viewModel.isBusy)
    }
}
