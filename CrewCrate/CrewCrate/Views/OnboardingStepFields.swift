import SwiftUI

struct OnboardingStepFields: View {
    @Bindable var viewModel: OnboardingViewModel
    @Binding var showImporter: Bool

    var body: some View {
        switch viewModel.step {
        case .account: account
        case .business: business
        case .recovery: recovery
        case .sales: sales
        case .leads: leads
        case .reporting: reporting
        case .review: review
        }
    }

    private var account: some View {
        Group {
            Section("Partnership contact") {
                TextField("Full name", text: $viewModel.draft.contactName).textContentType(.name)
                TextField("Business email", text: $viewModel.draft.email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            Section {
                TextField("Team emails (optional)", text: $viewModel.draft.teamEmails, axis: .vertical).lineLimit(2...5).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
            } header: { Text("Your team") } footer: {
                Text("Separate email addresses with commas or new lines. Invitations will become available when accounts are connected.")
            }
        }
    }
    private var business: some View {
        Group {
            Section("Business identity") {
                TextField("Business name", text: $viewModel.draft.businessName).textContentType(.organizationName)
                TextField("Website (optional, https://…)", text: $viewModel.draft.website).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Industry — any industry", text: $viewModel.draft.industry)
            }
            Section("What and where you sell") {
                TextField("Products or services", text: $viewModel.draft.services, axis: .vertical).lineLimit(2...6)
                TextField("Service areas, or Remote", text: $viewModel.draft.serviceArea, axis: .vertical).lineLimit(1...3)
                Picker("Time zone", selection: $viewModel.draft.timeZone) {
                    ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ")).tag($0) }
                }
            }
        }
    }
    private var recovery: some View {
        Group {
            Section {
                ForEach(RecoveryAudience.allCases) { audience in
                    Button { viewModel.toggleAudience(audience) } label: {
                        HStack {
                            Text(audience.rawValue).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: viewModel.draft.audience.contains(audience) ? "checkmark.circle.fill" : "circle").foregroundStyle(.indigo)
                        }
                    }
                    .accessibilityValue(viewModel.draft.audience.contains(audience) ? "Selected" : "Not selected")
                }
                Stepper("Inactive for at least \(viewModel.draft.dormantDays) days", value: $viewModel.draft.dormantDays, in: 1...3650)
            } header: { Text("Who should we recover?") } footer: {
                Text("Each audience will be tracked separately. Selecting an audience does not authorize outreach.")
            }
            Section("Success looks like") {
                Picker("Next step", selection: $viewModel.draft.goal) { ForEach(ConversionGoal.allCases) { Text($0.rawValue).tag($0) } }
                TextField("Offer or service to discuss", text: $viewModel.draft.offer, axis: .vertical).lineLimit(3...8)
                TextField("Who should be excluded? (optional)", text: $viewModel.draft.exclusions, axis: .vertical).lineLimit(2...6)
                Text("Tell us which people or groups should be left out of your recovery outreach. For example, a dental practice might exclude patients with upcoming appointments, a home-service business might exclude people outside its service area, and a consulting firm might exclude prospects already working with its sales team. Leave this blank if you have no additional exclusions.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
    private var sales: some View {
        Group {
            Section("Qualification") {
                TextField("What makes someone a qualified lead?", text: $viewModel.draft.qualification, axis: .vertical).lineLimit(3...8)
            }
            Section("Human handoff") {
                TextField("Salesperson or team", text: $viewModel.draft.salesContact)
                TextField("Handoff email", text: $viewModel.draft.handoffEmail).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                Stepper("Respond within \(viewModel.draft.responseHours) hours", value: $viewModel.draft.responseHours, in: 1...168)
                if viewModel.draft.goal == .appointment || viewModel.draft.goal == .estimate {
                    TextField("Booking link (optional)", text: $viewModel.draft.bookingURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
            }
            Section {
                TextField("What must the AI refer to a person?", text: $viewModel.draft.aiBoundaries, axis: .vertical).lineLimit(3...8)
            } header: { Text("AI boundaries") } footer: {
                Text("For example: price changes, guarantees, complaints, or questions outside approved business information. AI messaging is not active in this version.")
            }
        }
    }
    private var leads: some View {
        Group {
            Section {
                TextField("Where did this list come from?", text: $viewModel.draft.leadSource, axis: .vertical).lineLimit(2...6)
                TextField("Describe permission records and opt-out exclusions", text: $viewModel.draft.eligibilityNotes, axis: .vertical).lineLimit(3...8)
            } header: { Text("Source & eligibility") } footer: {
                Text("Old leads are not automatically eligible for messages. Contact eligibility requires review before activation.")
            }
            Section {
                Button { showImporter = true } label: { Label("Choose a CSV file", systemImage: "doc.badge.plus") }
                Text("Optional for initial setup. Up to 5 MB and 20,000 rows. Confirming the mapped contacts imports them into your workspace for campaign selection.").font(.caption).foregroundStyle(.secondary)
                if let document = viewModel.document {
                    Text(document.fileName).font(.subheadline.weight(.semibold))
                    Picker("Phone column", selection: $viewModel.phoneColumn) {
                        ForEach(Array(document.headers.enumerated()), id: \.offset) { index, header in Text(header).tag(index) }
                    }
                    Button(viewModel.isLive ? "Import mapped contacts" : "Inspect mapped contacts") { Task { await viewModel.confirmMapping() } }
                    Button("Cancel file selection", role: .cancel) { viewModel.cancelMapping() }
                }
                if let summary = viewModel.draft.importSummary {
                    LabeledContent("File", value: summary.fileName)
                    LabeledContent("Rows inspected", value: "\(summary.totalRows)")
                    LabeledContent("Unique plausible phone numbers", value: "\(summary.validContacts)")
                    LabeledContent("Duplicate phone numbers", value: "\(summary.duplicateContacts)")
                    LabeledContent("Missing or invalid numbers", value: "\(summary.invalidContacts)")
                    Text("This is a preliminary phone-format check, not a delivery or consent check. All contacts remain unapproved for outreach.").font(.caption).foregroundStyle(.secondary)
                    Button("Remove file summary", role: .destructive) { viewModel.draft.importSummary = nil }
                }
            } header: { Text("Inspect a lead list") }
        }
    }
    private var reporting: some View {
        Group {
            Section("Evidence sources") {
                Picker("Planned source", selection: $viewModel.draft.evidenceSource) {
                    if !EvidenceSource.onboardingChoices.contains(viewModel.draft.evidenceSource) {
                        Text("Choose a source").tag(viewModel.draft.evidenceSource).disabled(true)
                    }
                    ForEach(EvidenceSource.onboardingChoices) { Text($0.rawValue).tag($0) }
                }
                if viewModel.draft.evidenceSource == .crm {
                    Picker("Which CRM do you use?", selection: $viewModel.selectedCRM) {
                        ForEach(CRMProvider.allCases) { Text($0.title).tag($0) }
                    }
                    if viewModel.selectedCRM == .other {
                        TextField("CRM name", text: $viewModel.otherCRMName)
                    }
                    Text("Choose the CRM where your team records appointments, sales and outcomes. Selecting it does not connect or verify its data.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    TextField("Where are bookings, sales and payments recorded?", text: $viewModel.draft.reportingSystem, axis: .vertical).lineLimit(2...6)
                }
                Text("No reporting systems are connected yet. Manual reports will be labeled partner-reported until supporting evidence is reconciled.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Proposed commercial terms") {
                Picker("Compensation", selection: $viewModel.draft.compensation) { ForEach(CompensationModel.allCases) { Text($0.title).tag($0) } }
                Stepper(value: $viewModel.feeAmount, in: 0...1_000_000, step: 1) {
                    HStack {
                        Text("Fee amount")
                        Spacer()
                        TextField("0", value: $viewModel.feeAmount, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120).accessibilityLabel("Fee amount")
                    }
                }
                Stepper(value: $viewModel.feeRate, in: 0...100, step: 0.5) {
                    HStack {
                        Text("Rate")
                        Spacer()
                        TextField("0", value: $viewModel.feeRate, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90).accessibilityLabel("Percentage rate")
                        Text("%")
                    }
                }
                Text("Choose a fee amount, a percentage rate, or both. At least one must be greater than zero.").font(.footnote).foregroundStyle(.secondary)
                TextField("Qualifying outcomes, exclusions and refunds (optional)", text: $viewModel.draft.commercialTerms, axis: .vertical).lineLimit(3...8)
                Stepper("Report outcomes within \(viewModel.draft.reportingDays) days", value: $viewModel.draft.reportingDays, in: 1...90)
                Text("These are proposed terms, not an executed agreement. Owner review and agreement acceptance will follow.").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Toggle("I understand CrewCrate will have access to our partnership records and supporting evidence.", isOn: $viewModel.draft.acceptsVisibility)
            }
        }
    }
    private var review: some View {
        Group {
            Section("Setup readiness") {
                ForEach(viewModel.readiness, id: \.0) { step, ready in
                    Button { Task { await viewModel.edit(step) } } label: {
                        HStack {
                            Image(systemName: ready ? "checkmark.circle.fill" : "exclamationmark.circle").foregroundStyle(ready ? .green : .orange)
                            Text(step.title).foregroundStyle(.primary)
                            Spacer()
                            Text(ready ? "Complete" : "Needs details").font(.caption).foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Partnership summary") {
                LabeledContent("Business", value: viewModel.draft.businessName)
                LabeledContent("Industry", value: viewModel.draft.industry)
                LabeledContent("Goal", value: viewModel.draft.goal.rawValue)
                LabeledContent("Compensation", value: viewModel.draft.compensation.title)
                LabeledContent("Fee amount", value: (viewModel.draft.feeAmount ?? 0).formatted(.number.precision(.fractionLength(2))))
                LabeledContent("Rate", value: "\((viewModel.draft.feeRate ?? 0).formatted())%")
                Text(viewModel.draft.audience.map(\.rawValue).joined(separator: " · ")).font(.subheadline)
            }
            Section("Still required before launch") {
                Label(viewModel.draft.importSummary == nil ? "Lead database upload" : "Contact eligibility review", systemImage: "tray.and.arrow.down")
                Label("Messaging and reporting connections", systemImage: "link")
                Label("Final agreement and owner approval", systemImage: "signature")
            }
            Section {
                Toggle("I confirm these details are ready for review.", isOn: $viewModel.draft.confirmsAccuracy)
                Text("Prepare review saves this setup on your device. Online submission and owner approval are not available yet.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
