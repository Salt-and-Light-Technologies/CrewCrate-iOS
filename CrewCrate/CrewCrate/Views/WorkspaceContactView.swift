import SwiftUI

struct WorkspaceContactView: View {
    @State private var model: WorkspaceContactViewModel
    let readOnly: Bool
    init(business: UUID, campaign: UUID, readOnly: Bool, service: any WorkspaceContactServicing) {
        _model = State(initialValue: WorkspaceContactViewModel(business: business, campaign: campaign, service: service))
        self.readOnly = readOnly
    }
    var body: some View {
        @Bindable var model = model
        List {
            Section {
                Text("Review permission before outreach").font(.headline)
                Text("Permission records are business assertions. National registry screening and real texting are not connected yet.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Campaign contacts") {
                if model.hasLoaded && model.contacts.isEmpty { Text("No contacts match this list.").foregroundStyle(.secondary) }
                ForEach(model.contacts) { contact in
                    NavigationLink {
                        ContactPermissionView(contact: contact, business: model.business, readOnly: readOnly,
                            service: model.service, onSave: model.replace)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(contact.name.isEmpty ? contact.phone : contact.name).font(.headline)
                            Text(contact.permissionTitle).font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.vertical, 6)
                    }
                }
                if model.isBusy { ProgressView("Loading contacts…") }
                if model.hasMore { Button("Load more contacts") { Task { await model.load(reset: false) } }.disabled(model.isBusy) }
                if let error = model.error {
                    Text(error).foregroundStyle(.red)
                    Button("Reload contacts") { Task { await model.load() } }.disabled(model.isBusy)
                }
            }
        }
        .navigationTitle("Contacts")
        .searchable(text: $model.search, prompt: "Name, phone or email")
        .onSubmit(of: .search) { Task { await model.load() } }
        .onChange(of: model.search) { _, search in if search.isEmpty { Task { await model.load() } } }
        .task { await model.load() }
        .refreshable { await model.load() }
    }
}

private struct ContactPermissionView: View {
    @State private var model: ContactPermissionEditorModel
    let readOnly: Bool
    let onSave: (WorkspaceContact) -> Void
    @State private var confirming = false
    @State private var closing = false
    @Environment(\.dismiss) private var dismiss
    init(contact: WorkspaceContact, business: UUID, readOnly: Bool,
         service: any WorkspaceContactServicing, onSave: @escaping (WorkspaceContact) -> Void) {
        _model = State(initialValue: ContactPermissionEditorModel(contact: contact, business: business, service: service))
        self.readOnly = readOnly; self.onSave = onSave
    }
    var body: some View {
        @Bindable var model = model
        Form {
            Section("Contact") {
                Text(model.contact.name.isEmpty ? "Unnamed contact" : model.contact.name).font(.headline)
                LabeledContent("Phone", value: model.contact.phone)
                if !model.contact.email.isEmpty { LabeledContent("Email", value: model.contact.email) }
                Text(model.contact.permissionTitle).foregroundStyle(.secondary)
            }
            if !model.contact.permission_evidence.isEmpty {
                Section("Saved evidence") { Text(model.contact.permission_evidence).textSelection(.enabled) }
            }
            Section("Registry screening") { Text("Not screened · connection required").foregroundStyle(.secondary) }
            if !readOnly {
                Section("Review decision") {
                    Picker("Action", selection: $model.fields.action) {
                        if !model.contact.opted_out && model.contact.sms_permission != "revoked" {
                            Text("Record permission").tag("record_permission")
                        }
                        Text("Exclude from outreach").tag("exclude")
                        Text("Record opt-out").tag("opt_out")
                    }
                    TextField("Evidence reference or reason", text: $model.fields.evidence, axis: .vertical).lineLimit(3...6)
                    if model.fields.action == "record_permission" {
                        TextField("Source, e.g. signed consent form", text: $model.fields.source)
                        DatePicker("Permission date", selection: $model.date, in: ...Date(), displayedComponents: .date)
                        TextField("Country code, e.g. US", text: $model.fields.country)
                            .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        Toggle("I reviewed permission for this business’s marketing texts", isOn: $model.fields.attested)
                        Text("An old inquiry or presence on a spreadsheet does not establish SMS permission.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button("Save review") { confirming = true }
                        .buttonStyle(AuthenticationButtonStyle()).disabled(!model.canSave)
                    if let error = model.error {
                        Text(error).foregroundStyle(.red)
                        Text("If this record changed, return to the contact list and refresh before reviewing again.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .disabled(model.isBusy)
        .navigationTitle("Contact review")
        .navigationBarBackButtonHidden(model.hasEdits || model.isBusy)
        .toolbar {
            if model.hasEdits {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { closing = true }.disabled(model.isBusy)
                }
            }
        }
        .confirmationDialog("Discard this unsaved review?", isPresented: $closing, titleVisibility: .visible) {
            Button("Discard and go back", role: .destructive) { dismiss() }
        }
        .confirmationDialog(model.fields.action == "opt_out" ? "Record an opt-out? This cannot be reversed here." : "Save this review?",
                            isPresented: $confirming, titleVisibility: .visible) {
            Button("Save review", role: model.fields.action == "opt_out" ? .destructive : nil) {
                Task { if let saved = await model.save() { onSave(saved); dismiss() } }
            }
        }
    }
}
