import SwiftUI
import UniformTypeIdentifiers

struct CampaignDetailsView: View {
    @State private var confirmsDiscard = false
    @State var viewModel: CampaignDetailsViewModel
    var onSaved: ((CampaignSummary) -> Void)?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Form {
                if viewModel.isEditing {
                    Section { Text("Editing this campaign in its existing business workspace.").foregroundStyle(.secondary) }
                } else if viewModel.workspaces.isEmpty {
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
                Section("Campaign leads") {
                    if !viewModel.details.leadIDs.isEmpty {
                        Text("\(viewModel.details.leadIDs.count) leads already selected")
                    }
                    Button(viewModel.contactFile == nil ? "Upload contact file" : "Choose another file", systemImage: "doc.badge.plus") {
                        viewModel.showsFilePicker = true
                    }.disabled(viewModel.workspaceID == nil || viewModel.isImporting)
                    if let file = viewModel.contactFile, let info = viewModel.columns {
                        Text(file.name).font(.subheadline)
                        if info.sheets.count > 1 {
                            Picker("Worksheet", selection: Binding(get: { viewModel.mapping.sheet }, set: { sheet in
                                Task { await viewModel.changeSheet(sheet) }
                            })) {
                                ForEach(info.sheets, id: \.self) { Text($0).tag($0) }
                            }
                        }
                        Picker("Phone column (required)", selection: $viewModel.mapping.phone) {
                            Text("Select column").tag("")
                            ForEach(info.columns, id: \.self) { Text($0).tag($0) }
                        }
                        Picker("Name column", selection: $viewModel.mapping.name) {
                            Text("Skip").tag("")
                            ForEach(info.columns, id: \.self) { Text($0).tag($0) }
                        }
                        Picker("Email column", selection: $viewModel.mapping.email) {
                            Text("Skip").tag("")
                            ForEach(info.columns, id: \.self) { Text($0).tag($0) }
                        }
                        Button("Preview leads") { Task { await viewModel.previewFile() } }
                            .disabled(viewModel.mapping.phone.isEmpty || viewModel.isImporting)
                        if let preview = viewModel.preview {
                            Text("\(preview.total_rows) rows · \(preview.imported) new · \(preview.duplicates) duplicates · \(preview.invalid) invalid")
                            ForEach(Array(preview.issues.prefix(10).enumerated()), id: \.offset) { _, issue in
                                Text("Row \(issue.row_number): \(issue.detail)").font(.caption).foregroundStyle(.secondary)
                            }
                            if preview.issues.count > 10 || preview.issues_truncated { Text("Additional row issues are not shown.").font(.caption) }
                            Text("Saving adds valid leads to this campaign. Existing contacts are reused; invalid rows are skipped.").font(.footnote)
                        } else { Text("Preview this file before saving.").font(.footnote).foregroundStyle(.secondary) }
                        Button("Remove selected file", role: .destructive) { viewModel.clearImport() }
                    }
                    Text("CSV, TSV or Excel .xlsx, up to 5 MB. For Google Sheets or Numbers, export to one of these formats. Use headers in row 1 and store phone numbers as text. Up to 500 distinct leads per campaign. Importing does not establish permission to text.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Opening SMS and sending settings") {
                    TextField("Opening message (include your business name and Reply STOP to opt out)", text: $viewModel.details.messageTemplate, axis: .vertical).lineLimit(3...8)
                    Text("\(viewModel.details.messageTemplate.count)/480 characters").font(.caption).foregroundStyle(.secondary)
                    TextField("Campaign time zone (e.g. America/Chicago)", text: $viewModel.details.timeZone)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Stepper("Start hour: \(viewModel.details.startHour):\(String(format: "%02d", viewModel.details.startMinute ?? 0))", value: $viewModel.details.startHour, in: 9...17)
                    Stepper("End hour: \(viewModel.details.endHour):\(String(format: "%02d", viewModel.details.endMinute ?? 0))", value: $viewModel.details.endHour, in: 9...17)
                    Stepper("Daily message limit: \(viewModel.details.dailyLimit)", value: $viewModel.details.dailyLimit, in: 1...500)
                    Text("After saving, review each lead’s permission and select eligible recipients in campaign details. These settings take effect after the SMS provider is connected.").font(.footnote).foregroundStyle(.secondary)
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
                    Text(viewModel.isEditing ? "Saving updates this campaign and returns it to draft for preparation to be checked again." : "Save these details and any uploaded leads as a draft.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .disabled(viewModel.isSaving || viewModel.isImporting)
            .navigationTitle("Campaign details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if viewModel.hasEdits { confirmsDiscard = true } else { dismiss() } }.disabled(viewModel.isSaving || viewModel.isImporting) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isEditing ? "Save changes" : "Save draft") {
                        Task {
                            if await viewModel.save() {
                                if let saved = viewModel.savedCampaign { onSaved?(saved) }
                                dismiss()
                            }
                        }
                    }
                        .disabled(!viewModel.canSave)
                }
            }
            .fileImporter(isPresented: $viewModel.showsFilePicker, allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, UTType(filenameExtension: "xlsx") ?? .data]) { result in
                Task { await viewModel.chooseFile(result) }
            }
            .onChange(of: viewModel.workspaceID) { _, _ in viewModel.clearImport() }
            .sheet(isPresented: $viewModel.showsAITest) {
                if let partnerID = viewModel.workspaceID {
                    AITestView(viewModel: AITestViewModel(service: viewModel.service, partnerID: partnerID, config: viewModel.details))
                }
            }
            .confirmationDialog("Discard campaign details?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .overlay { if viewModel.isSaving || viewModel.isImporting { ProgressView() } }
            .alert("Campaign", isPresented: Binding(get: { viewModel.notice != nil }, set: { if !$0 { viewModel.notice = nil } })) {
                Button("OK", role: .cancel) { viewModel.notice = nil }
                if viewModel.isEditing {
                    Button("Reload and discard edits", role: .destructive) { Task { await viewModel.reloadSaved() } }
                }
            } message: { Text(viewModel.notice ?? "") }
        }
    }
}
