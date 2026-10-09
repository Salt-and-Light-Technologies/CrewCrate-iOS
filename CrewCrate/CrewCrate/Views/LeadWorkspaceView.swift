import SwiftUI
import UniformTypeIdentifiers

struct LeadWorkspaceView: View {
    @State private var viewModel: LeadWorkspaceViewModel
    @State private var showImporter = false
    @State private var confirmImport = false
    @State private var permissionLead: LeadRecord?
    @State private var permissionEvidence = ""
    init(viewModel: LeadWorkspaceViewModel) { _viewModel = State(initialValue: viewModel) }
    var body: some View {
        @Bindable var model = viewModel
        List {
            if viewModel.isDemo { Section { LeadDemoNotice() } }
            if let error = viewModel.errorMessage {
                Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
            }
            if let notice = viewModel.notice { Section { Text(notice).foregroundStyle(.indigo) } }
            if let workspace = viewModel.workspace {
                Section(workspace.name) {
                    PartnerStatusBadge(status: workspace.status)
                    LabeledContent("Stored leads", value: "\(workspace.totalLeads)")
                    ForEach(LeadStatus.allCases) { status in LabeledContent(status.title, value: "\(workspace.counts[status, default: 0])") }
                    LabeledContent("Imports", value: "\(workspace.importCount)")
                    Text("Eligibility is a review classification; it does not verify consent or launch a campaign.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Import a lead list") {
                    if workspace.canImport {
                        Button("Choose CSV file", systemImage: "doc.badge.plus") { showImporter = true }
                        if viewModel.isDemo { Button("Use sample CSV", systemImage: "flask") { viewModel.useSampleFile() } }
                        Text("UTF-8 CSV · up to 5 MB and 20,000 records. Review columns and issues before importing.").font(.caption).foregroundStyle(.secondary)
                    } else { Text("Uploads are unavailable while your workspace is paused.").font(.subheadline).foregroundStyle(.secondary) }
                }
                if let document = viewModel.document {
                    Section("Map columns — \(document.fileName)") {
                        LabeledContent("Records", value: "\(document.rows.count)")
                        Picker("Phone", selection: $model.mapping.phone) {
                            ForEach(document.headers.indices, id: \.self) { Text(document.headers[$0]).tag($0) }
                        }
                        Picker("Name (optional)", selection: $model.mapping.name) {
                            Text("Skip").tag(Int?.none)
                            ForEach(document.headers.indices, id: \.self) { Text(document.headers[$0]).tag(Optional($0)) }
                        }
                        Picker("Email (optional)", selection: $model.mapping.email) {
                            Text("Skip").tag(Int?.none)
                            ForEach(document.headers.indices, id: \.self) { Text(document.headers[$0]).tag(Optional($0)) }
                        }
                        Button("Preview import") { Task { await viewModel.previewImport() } }
                        Button("Discard selected file", role: .destructive) { viewModel.cancelImport() }
                    }
                }
                if let preview = viewModel.preview {
                    Section("Import preview") {
                        LabeledContent("Total records", value: "\(preview.totalRows)")
                        LabeledContent("New contacts", value: "\(preview.imported)")
                        LabeledContent("Duplicates skipped", value: "\(preview.duplicates)")
                        LabeledContent("Invalid records skipped", value: "\(preview.invalid)")
                        Text("Phones are compared as digits within this partner's workspace. Numbers are not checked for reachability or international dialing accuracy.").font(.caption).foregroundStyle(.secondary)
                        Button("Import reviewed list") { confirmImport = true }
                    }
                    if !preview.issues.isEmpty {
                        Section("Rows needing attention") {
                            Text("Record numbers count data rows, excluding the header and blank rows.").font(.caption).foregroundStyle(.secondary)
                            ForEach(preview.issues) { issue in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Record \(issue.rowNumber) · \(issue.kind.capitalized)").font(.subheadline.bold())
                                    Text(issue.detail).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            if preview.issuesTruncated { Text("Showing the first 100 issues. Totals include all records.").font(.caption) }
                        }
                    }
                }
                Section("Find leads") {
                    TextField("Name, phone or email", text: $model.search).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Picker("Status", selection: $model.statusFilter) {
                        Text("All").tag(LeadStatus?.none)
                        ForEach(LeadStatus.allCases) { Text($0.title).tag(Optional($0)) }
                    }
                    Button("Apply filters") { Task { await viewModel.load() } }
                }
                Section("Leads") {
                    if viewModel.leads.isEmpty { Text("No leads match the loaded filters. Import a list or change your filters.").foregroundStyle(.secondary) }
                    ForEach(viewModel.leads) { lead in
                        DisclosureGroup {
                            LabeledContent("Phone", value: lead.phone).textSelection(.enabled)
                            LabeledContent("SMS permission", value: lead.smsPermission.capitalized)
                            if lead.optedOut { Label("Opted out", systemImage: "hand.raised.fill").foregroundStyle(.red) }
                            if !lead.permissionEvidence.isEmpty { Text(lead.permissionEvidence).font(.caption).foregroundStyle(.secondary) }
                            Button("Record permission or opt-out") { permissionEvidence = ""; permissionLead = lead }.disabled(workspace.status == .paused)
                            if !lead.email.isEmpty { LabeledContent("Email", value: lead.email).textSelection(.enabled) }
                            Menu("Change review status") {
                                ForEach(LeadStatus.allCases) { status in
                                    Button(status.title) { Task { await viewModel.classify(lead, as: status) } }
                                }
                            }.disabled(workspace.status == .paused)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(lead.name.isEmpty ? lead.phone : lead.name).font(.headline)
                                Text(lead.status.title).font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                    }
                    if viewModel.hasMoreLeads { Button("Load more leads") { Task { await viewModel.loadMore("leads") } } }
                }
                Section("Import history") {
                    if viewModel.batches.isEmpty { Text("No imports recorded.").foregroundStyle(.secondary) }
                    ForEach(viewModel.batches) { batch in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(batch.fileName).font(.headline)
                            Text("\(batch.totalRows) rows · \(batch.imported) new · \(batch.duplicates) duplicate · \(batch.invalid) invalid").font(.caption)
                            Text(batch.timestamp.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }
                    if viewModel.hasMoreImports { Button("Load more imports") { Task { await viewModel.loadMore("imports") } } }
                }
                Section("Lead activity") {
                    if viewModel.events.isEmpty { Text("No lead activity recorded.").foregroundStyle(.secondary) }
                    ForEach(viewModel.events) { event in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(event.action).font(.headline)
                            Text(event.detail).font(.subheadline)
                            Text("\(event.actorName) · \(event.timestamp.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }
                    if viewModel.hasMoreActivity { Button("Load more activity") { Task { await viewModel.loadMore("activity") } } }
                }
            }
            if viewModel.isBusy { ProgressView("Updating workspace…") }
        }
        .disabled(viewModel.isBusy)
        .navigationTitle("Lead workspace")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .toolbar { Button("Refresh", systemImage: "arrow.clockwise") { Task { await viewModel.load() } }.disabled(viewModel.isBusy) }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.commaSeparatedText]) { result in
            switch result {
            case .success(let url): Task { await viewModel.inspect(url) }
            case .failure(let error): viewModel.reportError(error)
            }
        }
        .sheet(item: $permissionLead) { lead in
            NavigationStack {
                Form {
                    Section { Text("Record an evidence reference or opt-out reason. This is a team assertion, not automated verification of contact permission.").font(.subheadline) }
                    Section {
                        Text(lead.name.isEmpty ? lead.phone : lead.name).font(.headline)
                        TextField("Evidence reference or reason", text: $permissionEvidence, axis: .vertical).lineLimit(3...8)
                        Button("Record SMS permission") { Task { await viewModel.setPermission(lead, permission: "recorded", evidence: permissionEvidence); permissionLead = nil } }.disabled(lead.optedOut)
                        Button("Record opt-out", role: .destructive) { Task { await viewModel.setPermission(lead, permission: "revoked", evidence: permissionEvidence); permissionLead = nil } }
                        Text("Opted-out contacts cannot be re-enabled here. Add at least eight characters of evidence or reason.").font(.caption).foregroundStyle(.secondary)
                    }
                }.navigationTitle("Contact permission").toolbar { Button("Cancel") { permissionLead = nil } }
            }
        }
        .confirmationDialog("Import reviewed contacts?", isPresented: $confirmImport, titleVisibility: .visible) {
            Button("Import contacts") { Task { await viewModel.commitImport() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.isDemo ? "This stores contacts only in this local demo until the app closes. Duplicates and invalid records are skipped. No messages will be sent." : "Contacts will be stored in this partner's workspace. Duplicates and invalid records are skipped. No messages will be sent.")
        }
    }
}
