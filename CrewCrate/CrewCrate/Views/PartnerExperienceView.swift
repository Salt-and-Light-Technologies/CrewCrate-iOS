import SwiftUI

struct PartnerExperienceView: View {
    @Bindable var viewModel: PartnerExperienceViewModel
    let session: SessionViewModel
    @State private var showAccount = false
    var body: some View {
        Group {
            if viewModel.isLoading { ProgressView("Loading your workspace…") }
            else if let error = viewModel.errorMessage {
                ContentUnavailableView {
                    Label("Workspace unavailable", systemImage: "building.2")
                } description: { Text(error) } actions: {
                    Button("Try again") { Task { await viewModel.load() } }
                    Button("Account") { showAccount = true }
                }
            } else if let onboarding = viewModel.onboarding {
                OnboardingView(viewModel: onboarding, onOpenAccount: { showAccount = true })
                    .id(ObjectIdentifier(onboarding))
            } else {
                TabView {
                    PartnerAnalyticsView(viewModel: viewModel.analytics).tabItem { Label("Analytics", systemImage: "chart.bar.xaxis") }
                    NavigationStack {
                        if viewModel.campaigns.count == 1, let campaigns = viewModel.campaigns.first {
                            CampaignListView(viewModel: campaigns)
                        } else {
                            List {
                                ForEach(Array(viewModel.campaigns.enumerated()), id: \.offset) { _, campaigns in
                                    NavigationLink(campaigns.name) { CampaignListView(viewModel: campaigns) }
                                }
                            }.navigationTitle("Campaigns")
                        }
                    }.tabItem { Label("Campaigns", systemImage: "megaphone") }
                    ConnectedAccountView(session: session).tabItem { Label("Account", systemImage: "person.crop.circle") }
                }
            }
        }.task { await viewModel.load() }
            .sheet(isPresented: $showAccount) { ConnectedAccountView(session: session) }
    }
}
