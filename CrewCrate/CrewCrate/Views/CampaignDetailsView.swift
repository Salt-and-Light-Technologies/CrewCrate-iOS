import SwiftUI
import UniformTypeIdentifiers

struct CampaignDetailsView: View {
    @State private var step = 0
    @State private var showsColumns = false
    @State private var showsSendingSettings = false
    @State private var confirmsDiscard = false
    @State private var confirmsRemoveLeads = false
    @State var viewModel: CampaignDetailsViewModel
    var onSaved: ((CampaignSummary) -> Void)?
    @Environment(\.dismiss) private var dismiss
    private var stepTitle: String { ["What is your campaign about?", "Meet your assistant", "Who would you like to contact?", "Review and save"][step] }
    private var stepExplanation: String { ["Give it a name and describe your offer.", "Tell your assistant how to help and when to involve your team.", "Upload your contacts now, or add them later.", "You can change these details any time."][step] }
    private func hideKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Form {
                Section {
                    CrewStepHeader(step: step, title: stepTitle, explanation: stepExplanation)
                }
                if step == 0 {
                if viewModel.isEditing {
                    Section { Text("Changes are saved only when you tap Save campaign.").foregroundStyle(.secondary) }
                } else if viewModel.workspaces.isEmpty {
                    Section { Text("Set up your business in Account before creating a campaign.").foregroundStyle(.secondary) }
                } else {
                    Section("Your business") {
                        Picker("Business", selection: $viewModel.workspaceID) {
                            Text("Choose your business").tag(nil as UUID?)
                            ForEach(viewModel.workspaces.filter { $0.status != "paused" }) { space in
                                Text(space.name).tag(Optional(space.id))
                            }
                        }
                    }
                }
                Section("Campaign details") {
                    TextField("Campaign name", text: $viewModel.details.name)
                    TextField("What are you offering?", text: $viewModel.details.offer, axis: .vertical).lineLimit(3...6)
                }
                }
                if step == 1 {
                Section("Your assistant") {
                    TextField("Assistant’s name", text: Binding(get: { viewModel.details.aiName ?? "" }, set: { viewModel.details.aiName = $0 }))
                    TextField("What should your assistant help with?", text: Binding(get: { viewModel.details.aiBrief ?? "" }, set: { viewModel.details.aiBrief = $0 }), axis: .vertical).lineLimit(4...8)
                }
                Section("When someone is interested") {
                    TextField("When should your team take over?", text: $viewModel.details.qualification, axis: .vertical).lineLimit(3...6)
                    TextField("Your team’s email address", text: $viewModel.details.handoffEmail)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section("Test your assistant") {
                    Button("Try a practice conversation", systemImage: "bubble.left.and.bubble.right") { viewModel.showsAITest = true }
                        .disabled(viewModel.workspaceID == nil || viewModel.details.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text("Try the current details without saving a campaign or contacting real leads.").font(.footnote).foregroundStyle(.secondary)
                }
                }
                if step == 2 {
                Section("Add contacts") {
                    if !viewModel.details.leadIDs.isEmpty {
                        Text("\(viewModel.details.leadIDs.count) leads already selected")
                        Button("Remove lead list", role: .destructive) { confirmsRemoveLeads = true }
                    }
                    Button(viewModel.contactFile == nil ? "Upload contact file" : "Choose another file", systemImage: "doc.badge.plus") {
                        viewModel.showsFilePicker = true
                    }.disabled(viewModel.workspaceID == nil || viewModel.isImporting)
                    if let file = viewModel.contactFile, let info = viewModel.columns {
                        Label(file.name, systemImage: "doc.text").font(.headline)
                        Text("We matched the columns for you. Check them only if something looks wrong.").font(.subheadline).foregroundStyle(.secondary)
                        if info.sheets.count > 1 {
                            Picker("Worksheet", selection: Binding(get: { viewModel.mapping.sheet }, set: { sheet in
                                Task { await viewModel.changeSheet(sheet) }
                            })) {
                                ForEach(info.sheets, id: \.self) { Text($0).tag($0) }
                            }
                        }
                        DisclosureGroup("Check file columns", isExpanded: $showsColumns) {
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
                        Picker("SMS permission column", selection: $viewModel.mapping.permission) {
                            Text("Skip").tag("")
                            ForEach(info.columns, id: \.self) { Text($0).tag($0) }
                        }
                        Picker("Permission evidence column", selection: $viewModel.mapping.evidence) {
                            Text("Skip").tag("")
                            ForEach(info.columns, id: \.self) { Text($0).tag($0) }
                        }
                        Picker("Opt-out column", selection: $viewModel.mapping.optout) {
                            Text("Skip").tag("")
                            ForEach(info.columns, id: \.self) { Text($0).tag($0) }
                        }
                        Picker("Test data column", selection: $viewModel.mapping.test) {
                            Text("Skip").tag("")
                            ForEach(info.columns, id: \.self) { Text($0).tag($0) }
                        }
                        }
                        if !viewModel.mapping.permission.isEmpty {
                            Toggle("I verified these permission records for this business’s texts", isOn: $viewModel.mapping.permissionAttested)
                            Text("Recorded/yes requires evidence. Unknown stays excluded; revoked/no and opt-outs are blocked. Test rows can be selected for practice but cannot receive real SMS.").font(.footnote).foregroundStyle(.secondary)
                        }
                        Button("Check this file") { Task { await viewModel.previewFile() } }
                            .disabled(viewModel.mapping.phone.isEmpty || viewModel.isImporting)
                        if let preview = viewModel.preview {
                            Text("\(preview.total_rows) rows · \(preview.imported) new · \(preview.duplicates) duplicates · \(preview.invalid) invalid")
                            if !preview.issues.isEmpty {
                                DisclosureGroup("See skipped rows and duplicates") {
                            ForEach(Array(preview.issues.prefix(10).enumerated()), id: \.offset) { _, issue in
                                Text("Row \(issue.row_number): \(issue.detail)").font(.caption).foregroundStyle(.secondary)
                            }
                            if preview.issues.count > 10 || preview.issues_truncated { Text("Additional row issues are not shown.").font(.caption) }
                                }
                            }
                            Text("Saving adds valid leads to this campaign. Existing contacts are reused; invalid rows are skipped.").font(.footnote)
                        } else { Text("Preview this file before saving.").font(.footnote).foregroundStyle(.secondary) }
                        Button("Remove selected file", role: .destructive) { viewModel.clearImport() }
                    }
                    Text("Add a CSV or Excel file, up to 10,000 contacts. For Numbers or Google Sheets, export as CSV first.").font(.footnote).foregroundStyle(.secondary)
                }
                }
                if step == 3 {
                Section("Ready to save") {
                    LabeledContent("Campaign", value: viewModel.details.name)
                    LabeledContent("Contacts", value: viewModel.contactFile?.name ?? (viewModel.details.leadIDs.isEmpty ? "You can add contacts later" : "\(viewModel.details.leadIDs.count) selected contacts"))
                    Text("Saving keeps your campaign as a draft. No texts will be sent.").foregroundStyle(.secondary)
                    if let blocker = viewModel.saveBlocker { Label(blocker, systemImage: "exclamationmark.circle").foregroundStyle(.red) }
                }
                Section {
                    DisclosureGroup("Sending hours and daily limit", isExpanded: $showsSendingSettings) {
                    Text("Your AI assistant creates the opening message from your business information, offer and instructions before campaign outreach begins.").font(.footnote).foregroundStyle(.secondary)
                    Picker("Time zone", selection: $viewModel.details.timeZone) {
                        ForEach(viewModel.timeZones, id: \.self) { zone in
                            Text(zone.replacingOccurrences(of: "_", with: " ")).tag(zone)
                        }
                    }.pickerStyle(.navigationLink)
                    Picker("Start time", selection: $viewModel.startTime) {
                        ForEach(viewModel.sendingTimes, id: \.self) { time in
                            Text(viewModel.timeLabel(time)).tag(time)
                        }
                    }.pickerStyle(.menu)
                    Picker("End time", selection: $viewModel.endTime) {
                        ForEach(viewModel.sendingTimes, id: \.self) { time in
                            Text(viewModel.timeLabel(time)).tag(time)
                        }
                    }.pickerStyle(.menu)
                    HStack {
                        Text("Daily message limit")
                        Spacer()
                        TextField("Limit", text: $viewModel.dailyLimitText)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            .frame(width: 90).accessibilityLabel("Daily message limit")
                    }
                    if let settingsError = viewModel.settingsError {
                        Text(settingsError).font(.footnote).foregroundStyle(.red)
                    }
                    Text("After saving, review each lead’s permission and select eligible recipients in campaign details. These settings take effect after the SMS provider is connected.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                }
            }
            .disabled(viewModel.isSaving || viewModel.isImporting)
            .navigationTitle(viewModel.isEditing ? "Edit campaign" : "New campaign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if viewModel.hasEdits { confirmsDiscard = true } else { dismiss() } }.disabled(viewModel.isSaving || viewModel.isImporting) }
            }
            .confirmationDialog("Remove the lead list?", isPresented: $confirmsRemoveLeads, titleVisibility: .visible) {
                Button("Remove lead list", role: .destructive) { viewModel.details.leadIDs = []; viewModel.clearImport() }
            } message: { Text("Save changes to apply. Business contacts and permissions are kept.") }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 16) {
                    if step > 0 { Button("Back") { step -= 1 }.frame(minHeight: 48) }
                    Button(step == 3 ? "Save campaign" : "Continue") {
                        if step < 3 {
                            if step == 0 && (viewModel.workspaceID == nil || viewModel.details.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                                viewModel.notice = "Choose your business and enter a campaign name to continue."
                            } else if step == 2 && viewModel.contactFile != nil {
                                Task {
                                    if viewModel.mapping.phone.isEmpty {
                                        showsColumns = true
                                        viewModel.notice = "Choose the column containing phone numbers before continuing."
                                    } else {
                                        await viewModel.previewFile()
                                        if viewModel.preview != nil { step += 1 }
                                    }
                                }
                            } else { step += 1 }
                        } else {
                            Task { if await viewModel.save() { if let saved = viewModel.savedCampaign { onSaved?(saved) }; dismiss() } }
                        }
                    }.buttonStyle(CrewPrimaryButtonStyle())
                }.padding().background(.regularMaterial).disabled(viewModel.isSaving || viewModel.isImporting)
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { hideKeyboard() } } }
            .fileImporter(isPresented: $viewModel.showsFilePicker, allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, UTType(filenameExtension: "xlsx") ?? .data]) { result in
                Task { await viewModel.chooseFile(result) }
            }
            .onChange(of: step) { _, value in
                hideKeyboard()
                if value == 3 && viewModel.settingsError != nil { showsSendingSettings = true }
            }
            .onChange(of: viewModel.columns?.columns) { _, _ in
                showsColumns = viewModel.mapping.phone.isEmpty
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
            .overlay { if viewModel.isSaving || viewModel.isImporting { ProgressView(viewModel.isSaving ? "Saving campaign…" : "Checking contacts…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)) } }
            .alert("Campaign", isPresented: Binding(get: { viewModel.notice != nil }, set: { if !$0 { viewModel.notice = nil } })) {
                Button("OK", role: .cancel) { viewModel.notice = nil }
                if viewModel.isEditing {
                    Button("Reload and discard edits", role: .destructive) { Task { await viewModel.reloadSaved() } }
                }
            } message: { Text(viewModel.notice ?? "") }
        }
    }
}
