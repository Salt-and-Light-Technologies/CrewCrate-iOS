import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onOpenAccount: (() -> Void)? = nil
    @State private var showImporter = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Restoring your setup…")
                } else if viewModel.loadFailed {
                    ContentUnavailableView {
                        Label("Your draft is protected", systemImage: "exclamationmark.shield")
                    } description: {
                        Text(viewModel.errorMessage ?? "The saved draft could not be read.")
                    } actions: {
                        Button("Try again") { Task { await viewModel.load() } }
                    }
                } else if viewModel.isPrepared {
                    completion
                } else {
                    setup
                }
            }
            .navigationTitle("Partner setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onOpenAccount { ToolbarItem(placement: .topBarLeading) { Button("Account", action: onOpenAccount) } }
                if !viewModel.isLoading && !viewModel.loadFailed && !viewModel.isPrepared {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { Task { await viewModel.save() } } label: {
                            if viewModel.isBusy { ProgressView() } else { Text("Save") }
                        }
                        .disabled(viewModel.isBusy)
                        .accessibilityLabel("Save onboarding draft")
                    }
                }
            }
            .tint(.indigo)
            .task { await viewModel.load() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { Task { await viewModel.save() } }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.commaSeparatedText], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first { Task { await viewModel.inspectFile(url) } }
                case .failure(let error): viewModel.reportImportError(error)
                }
            }
        }
    }

    private var setup: some View {
        VStack(spacing: 0) {
            header
            Form {
                OnboardingStepFields(viewModel: viewModel, showImporter: $showImporter)
                if let message = viewModel.errorMessage {
                    Section { Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                }
                if !viewModel.validationMessages.isEmpty {
                    Section("Before you continue") {
                        ForEach(viewModel.validationMessages, id: \.self) { Text($0).foregroundStyle(.red).font(.subheadline) }
                    }
                }
                Section {
                    Text(viewModel.hasUnsavedChanges ? "Unsaved changes — tap Save or Continue." : "Draft saved on this device.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .disabled(viewModel.isBusy)
            footer
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image("CrateMark").resizable().scaledToFit().frame(width: 40, height: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("CREWCRATE").font(.caption.weight(.bold)).tracking(2).foregroundStyle(.indigo)
                    Text("Step \(viewModel.step.rawValue + 1) of 7").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: viewModel.step.symbol).font(.title2).foregroundStyle(.indigo)
            }
            ProgressView(value: viewModel.progress).accessibilityLabel("Onboarding progress")
            Text(viewModel.step.title).font(.title2.bold())
            Text(viewModel.step.subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [.indigo.opacity(0.08), .cyan.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private var footer: some View {
        HStack(spacing: 16) {
            if viewModel.step != .account {
                Button("Back") { Task { await viewModel.back() } }.buttonStyle(.bordered)
            }
            Spacer()
            Button {
                Task {
                    if viewModel.step == .review { await viewModel.prepareReview() }
                    else { await viewModel.next() }
                }
            } label: {
                Text(viewModel.step == .review ? (viewModel.isLive ? "Finish setup" : "Prepare review") : "Continue")
                    .fontWeight(.semibold).padding(.horizontal, 12).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .disabled(viewModel.isBusy)
        .background(.bar)
    }

    private var completion: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image("CrateMark").resizable().scaledToFit().frame(width: 72, height: 72).accessibilityHidden(true)
                Label(viewModel.isLive ? "Setup saved" : "Setup prepared", systemImage: "checkmark.circle.fill").font(.title.bold()).foregroundStyle(.indigo)
                Text(viewModel.draft.businessName).font(.title2.weight(.semibold))
                Text(viewModel.isLive ? "Your setup is stored in CrewCrate. Changes are currently unavailable. Contact your administrator if you need to update it. Messaging remains disabled." : "Your setup is saved locally and ready for a future owner review. It has not been submitted to CrewCrate’s owner.")
                    .foregroundStyle(.secondary)
                GroupBox("Before a campaign can launch") {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Connect the partner account and reporting systems", systemImage: "link")
                        Label("Review contact eligibility and messaging setup", systemImage: "checkmark.shield")
                        Label("Finalize the agreement and get owner approval", systemImage: "signature")
                    }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                }
                Text(viewModel.isLive ? "Messaging remains disabled. Import contacts separately in the Leads tab before submitting setup." : "No messages have been sent. No contacts have been uploaded.")
                    .font(.caption).foregroundStyle(.secondary)
                if !viewModel.isLive { Button("Edit setup") { viewModel.resumeEditing() }.buttonStyle(.borderedProminent) }
            }.padding(24).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
        }
    }
}
