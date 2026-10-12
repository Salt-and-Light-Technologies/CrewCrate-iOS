import SwiftUI

struct BusinessAccessView: View {
    @State private var model: BusinessAccessViewModel
    @Environment(\.scenePhase) private var scenePhase
    private let campaignService: any CampaignWorkspaceServicing & WorkspaceContactServicing
    private let profileService: any BusinessProfileServicing
    private let analyticsService: any OwnerAnalyticsServicing

    init(identity: AuthenticatedIdentity, service: any BusinessApplicationServicing & CampaignWorkspaceServicing & BusinessProfileServicing & WorkspaceContactServicing & OwnerAnalyticsServicing) {
        _model = State(initialValue: BusinessAccessViewModel(isOwner: identity.isOwner, service: service))
        campaignService = service
        profileService = service
        analyticsService = service
    }

    var body: some View {
        TabView {
            NavigationStack { home }
                .tabItem { Label(model.isOwner ? "Businesses" : "Home", systemImage: "house") }
            if model.isOwner {
                NavigationStack { requestInbox }
                    .tabItem { Label("Requests", systemImage: "tray") }
                    .badge(model.requests.count)
            }
            NavigationStack { account }
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .tint(AuthenticationStyle.purple)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            repeat {
                await model.load()
                do { try await Task.sleep(for: .seconds(30)) }
                catch { return }
            } while !Task.isCancelled
        }
    }

    @ViewBuilder private var home: some View {
        Group {
            if model.isLoading {
                ProgressView("Loading your workspace…")
            } else if !model.hasLoaded {
                ContentUnavailableView {
                    Label("Couldn’t load your workspace", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(model.error ?? "Please try again.")
                } actions: {
                    Button("Try again") { Task { await model.load() } }
                }
            } else if model.isOwner {
                businessList
            } else if model.businesses.count > 1 {
                businessList
            } else if let business = model.businesses.first {
                CampaignWorkspaceView(business: business, service: campaignService)
            } else if let application = model.application {
                applicationStatus(application)
            } else {
                BusinessApplicationForm(model: model)
            }
        }
        .navigationTitle(model.isOwner ? "Your businesses" : "CrewCrate")
        .toolbar { refreshButton }
    }

    private var businessList: some View {
        List {
            Section {
                Text("Help businesses turn missed opportunities into conversations.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if !model.requests.isEmpty {
                Section {
                    Label("\(model.requests.count) business requests waiting", systemImage: "tray.fill")
                        .foregroundStyle(AuthenticationStyle.purple)
                    Text("Open Requests to review their details.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Businesses") {
                if model.businesses.isEmpty {
                    Text("No businesses yet. Approved requests will appear here.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.businesses) { business in
                    NavigationLink {
                        if model.isOwner {
                            OwnerBusinessAnalyticsView(business: business, analyticsService: analyticsService,
                                campaignService: campaignService)
                        } else {
                            CampaignWorkspaceView(business: business, service: campaignService)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(business.name).font(.headline)
                            Text(model.isOwner ? "View business analytics" : "Business workspace")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.vertical, 6)
                    }
                }
            }
            if let error = model.error { Section { Text(error).foregroundStyle(.red) } }
        }
        .refreshable { await model.load() }
    }

    private var requestInbox: some View {
        List {
            if model.isLoading { ProgressView("Loading requests…") }
            if let error = model.requestsError {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button("Reload requests") { Task { await model.load() } }.disabled(model.isBusy)
                }
            }
            if model.hasLoadedRequests && model.requestsError == nil && model.requests.isEmpty {
                ContentUnavailableView("You’re all caught up", systemImage: "checkmark.circle",
                    description: Text("New business applications will appear here."))
            }
            ForEach(model.requests) { request in
                NavigationLink {
                    ApplicationReviewView(request: request, model: model)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(request.business_name).font(.headline)
                        Text(request.contact_name).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Requests")
        .toolbar { refreshButton }
        .refreshable { await model.load() }
    }

    private func applicationStatus(_ application: BusinessApplication) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: application.status == "denied" ? "bubble.left" : "clock")
                    .font(.largeTitle).foregroundStyle(AuthenticationStyle.purple)
                Text(application.status == "denied" ? "Your request wasn’t approved" :
                     application.status == "approved" ? "Approval received" : "Waiting for owner approval")
                    .font(.largeTitle.bold())
                Text(application.business_name).font(.title3.weight(.semibold))
                Text(application.status == "denied"
                    ? "Your request wasn’t approved. The CrewCrate team’s note is below."
                    : application.status == "approved"
                    ? "Your request is approved, but your workspace isn’t available yet. Refresh or contact the CrewCrate team."
                    : "Your request has been sent to the CrewCrate owner. You can access your business only after approval.")
                    .foregroundStyle(.secondary)
                if !application.review_note.isEmpty { Text(application.review_note) }
                Button("Check for an update") { Task { await model.load() } }
                    .buttonStyle(AuthenticationButtonStyle()).disabled(model.isBusy)
                if let error = model.error { Text(error).foregroundStyle(.red) }
            }.padding(24).frame(maxWidth: 560, alignment: .leading).frame(maxWidth: .infinity)
        }
    }

    private var account: some View {
        CrewCrateAccountView(isOwner: model.isOwner, businesses: model.businesses, service: profileService)
    }

    private var refreshButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { Task { await model.load() } } label: { Image(systemName: "arrow.clockwise") }
                .accessibilityLabel("Refresh workspace").disabled(model.isBusy)
        }
    }
}

private struct BusinessApplicationForm: View {
    @Bindable var model: BusinessAccessViewModel
    @Environment(AuthenticationViewModel.self) private var authentication

    var body: some View {
        Form {
            Section {
                Text("Let’s meet your business").font(.title2.bold())
                Text("Tell us a little about yourself. We’ll review your request and help you get started.")
                    .foregroundStyle(.secondary)
            }
            Section("Your business") {
                TextField("Business name", text: $model.draft.business_name).textContentType(.organizationName)
                TextField("Your full name", text: $model.draft.contact_name).textContentType(.name)
                TextField("Contact email", text: $model.draft.email).keyboardType(.emailAddress)
                    .textContentType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Contact phone", text: $model.draft.phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
            }
            Section("How did you hear about CrewCrate? (optional)") {
                TextField("Referral name or where you found us", text: $model.draft.referral, axis: .vertical)
            }
            Section {
                Text("The CrewCrate platform owner can review your application and, after approval, your business records in CrewCrate. Other businesses cannot access your workspace.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button {
                    Task { await model.submit() }
                } label: {
                    if model.isBusy { ProgressView("Sending request…").frame(maxWidth: .infinity) }
                    else { Text("Request access").frame(maxWidth: .infinity) }
                }
                .buttonStyle(AuthenticationButtonStyle()).disabled(model.isBusy || !model.draft.isComplete)
                if let error = model.error { Text(error).foregroundStyle(.red) }
            }
        }
        .disabled(model.isBusy)
        .onAppear { if model.draft.email.isEmpty { model.draft.email = authentication.email } }
    }
}

private struct ApplicationReviewView: View {
    let request: BusinessApplication
    @Bindable var model: BusinessAccessViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var confirmingApproval = false
    @State private var confirmingDenial = false

    var body: some View {
        Form {
            Section("Business") {
                Text(request.business_name).font(.headline)
                LabeledContent("Contact", value: request.contact_name)
                LabeledContent("Email", value: request.email).textSelection(.enabled)
                LabeledContent("Phone", value: request.phone).textSelection(.enabled)
            }
            Section("Referral") { Text(request.referral.isEmpty ? "No referral provided" : request.referral) }
            Section("Note to applicant") {
                TextField("Optional for approval; required for denial", text: $note, axis: .vertical)
                    .lineLimit(3...6)
            }
            Section {
                Text("Approval gives this applicant a business workspace. It does not enable SMS or approve a campaign for sending.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Approve business") { confirmingApproval = true }
                    .buttonStyle(AuthenticationButtonStyle())
                Button("Deny request", role: .destructive) { confirmingDenial = true }
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let error = model.error { Text(error).foregroundStyle(.red) }
            }
        }
        .disabled(model.isBusy)
        .navigationTitle("Review request")
        .alert("Approve this business?", isPresented: $confirmingApproval) {
            Button("Approve") { review(approve: true) }
            Button("Cancel", role: .cancel) { }
        } message: { Text("\(request.business_name) will be able to access its own workspace.") }
        .alert("Deny this request?", isPresented: $confirmingDenial) {
            Button("Deny request", role: .destructive) { review(approve: false) }
            Button("Cancel", role: .cancel) { }
        } message: { Text("The applicant will see your note. No business access will be granted.") }
    }

    private func review(approve: Bool) {
        Task { if await model.decide(request, approve: approve, note: note) { dismiss() } }
    }
}

private struct CrewCrateAccountView: View {
    let isOwner: Bool
    let businesses: [BusinessSummary]
    let service: any BusinessProfileServicing
    @Environment(AuthenticationViewModel.self) private var authentication
    @State private var confirmingLogout = false

    var body: some View {
        Form {
            Section("Your account") {
                Label(isOwner ? "Platform owner" : "Business account", systemImage: "person.crop.circle")
            }
            if !isOwner && !businesses.isEmpty {
                Section("Business information") {
                    ForEach(businesses) { business in
                        NavigationLink(business.name) {
                            BusinessProfileEditorView(business: business, service: service)
                        }
                    }
                }
                Section("Business integrations") {
                    Text("Calendar connections will be managed here for each business.")
                    Label("Google Calendar · not connected", systemImage: "calendar")
                    Label("Calendly · not connected", systemImage: "calendar.badge.clock")
                    Text("Calendar connection controls are not available yet. Worker handoff will remain an option without a calendar.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section {
                Button("Log out", role: .destructive) { confirmingLogout = true }
                    .disabled(authentication.isBusy)
            }
        }
        .navigationTitle("Account")
        .confirmationDialog("Log out of CrewCrate?", isPresented: $confirmingLogout, titleVisibility: .visible) {
            Button("Log out", role: .destructive) { Task { await authentication.signOut() } }
        }
    }
}
