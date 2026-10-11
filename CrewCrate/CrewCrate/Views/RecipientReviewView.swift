import SwiftUI

struct RecipientReviewView: View {
    @State var viewModel: RecipientReviewViewModel
    var onSaved: (CampaignSummary) -> Void
    var body: some View {
        @Bindable var viewModel = viewModel
        List {
            Section {
                Picker("Lead list", selection: $viewModel.listID) {
                    Text("Current campaign leads").tag("campaign")
                    Text("All business leads").tag("all")
                    ForEach(viewModel.batches) { Text("Import: \($0.file_name)").tag($0.id.uuidString) }
                }
                Picker("Show", selection: $viewModel.filter) {
                    Text("All").tag("all")
                    Text("Eligible for texts").tag("eligible")
                    Text("Not eligible").tag("excluded")
                }
                Text("\(viewModel.selected.count) selected · \(viewModel.visible.count) shown")
                Button("Select all eligible leads in this list") { Task { await viewModel.selectAllEligible() } }.disabled(!viewModel.hasLoaded)
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
                                    .foregroundStyle(viewModel.selected.contains(lead.id) ? Color.accentColor : Color.secondary)
                                    .font(.title2)
                            }.buttonStyle(.borderless).disabled(!lead.eligible_for_sms)
                                .accessibilityLabel(viewModel.selected.contains(lead.id) ? "Deselect lead" : "Select lead")
                            VStack(alignment: .leading) {
                                Text(lead.name.isEmpty ? lead.phone : lead.name).font(.headline)
                                Text(lead.phone).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Text(lead.eligible_for_sms ? (lead.permission_evidence.hasPrefix("[TEST ONLY]") ? "Eligible for practice only" : "Eligible for texts") : (lead.opted_out || lead.sms_permission == "revoked" ? "Do not text — opted out" : "Not eligible for texts"))
                            .font(.caption).foregroundStyle(lead.eligible_for_sms ? Color.green : Color.secondary)
                        Button("Contact status & permission") { viewModel.reviewingLead = lead }.buttonStyle(.borderless)
                    }.padding(.vertical, 4)
                }
                if viewModel.hasLoaded && viewModel.visible.isEmpty { Text("No leads match this list and filter.").foregroundStyle(.secondary) }
            }
            if viewModel.hasMore {
                Section { Button("Load more (250 leads)") { Task { await viewModel.loadMore() } } }
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
        .onChange(of: viewModel.filter) { _, _ in Task { await viewModel.load() } }
        .onChange(of: viewModel.listID) { _, _ in Task { await viewModel.load() } }
        .onSubmit(of: .search) { Task { await viewModel.load() } }
        .onChange(of: viewModel.search) { _, newValue in
            if newValue.isEmpty { Task { await viewModel.load() } }
        }
        .sheet(item: $viewModel.reviewingLead) { lead in
            NavigationStack {
                LeadPermissionView(viewModel: LeadPermissionViewModel(lead: lead, partnerID: viewModel.campaign.partnerID, service: viewModel.service), onSaved: { viewModel.reviewed($0); Task { await viewModel.load() } })
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
            Section("Texting status") {
                Label(viewModel.statusTitle, systemImage: viewModel.lead.eligible_for_sms ? "checkmark.circle.fill" : "nosign")
                    .foregroundStyle(viewModel.lead.eligible_for_sms ? Color.green : Color.secondary)
                Text(viewModel.statusExplanation).font(.footnote).foregroundStyle(.secondary)
                Button(viewModel.showsPermissionEditor ? "Cancel permission changes" : "Change contact permission") {
                    viewModel.showsPermissionEditor.toggle()
                }
            }
            if viewModel.showsPermissionEditor {
            Section("Can this contact receive texts?") {
                Picker("Decision", selection: $viewModel.action) {
                    if !viewModel.lead.opted_out && viewModel.lead.sms_permission != "revoked" { Text("Allow texts").tag("record_permission") }
                    Text("Exclude").tag("exclude")
                    Text("Opt out").tag("opt_out")
                }
                .pickerStyle(.segmented)
                TextField(viewModel.action == "record_permission" ? "Where is their permission recorded?" : "Reason for stopping texts", text: $viewModel.evidence, axis: .vertical).lineLimit(3...8)
            }
            if viewModel.action == "record_permission" {
                Section("Permission record") {
                    TextField("Source (e.g. signup form / CRM record)", text: $viewModel.source)
                    TextField("Consent date (YYYY-MM-DD)", text: $viewModel.consentDate)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Recipient country code (US, CA, etc.)", text: $viewModel.country)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    Toggle("I verified permission for this business to text this contact", isOn: $viewModel.attested)
                    Text("Being in a CSV or a customer list does not establish marketing SMS permission. Record the actual evidence supporting this contact.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            }
            if let error = viewModel.error { Section { Text(error).foregroundStyle(.red) } }
        }
        .disabled(viewModel.isBusy)
        .navigationTitle("Contact status")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(viewModel.isBusy) }
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.showsPermissionEditor {
                    Button("Save") { Task { if let lead = await viewModel.save() { onSaved(lead); dismiss() } } }.disabled(!viewModel.canSave)
                } else {
                    Button("Done") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isBusy)
    }
}
