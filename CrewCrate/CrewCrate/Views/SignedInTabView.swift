import SwiftUI

struct SignedInTabView: View {
    let service: SupabaseSession
    let userID: UUID
    @State private var business: BusinessViewModel
    @State private var showsSetup = false
    @State private var campaignRefresh = UUID()
    init(service: SupabaseSession, userID: UUID) {
        self.service = service; self.userID = userID
        _business = State(initialValue: BusinessViewModel(service: service))
    }
    var body: some View {
        TabView {
            NavigationStack { CampaignsView(viewModel: CampaignsViewModel(service: service)) }
                .id(campaignRefresh)
                .tabItem { Label("Campaigns", systemImage: "megaphone") }
            NavigationStack {
                AccountView(viewModel: AccountViewModel(service: service, userID: userID), business: business,
                            onBusinessSaved: { campaignRefresh = UUID() })
            }
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .tint(AuthenticationStyle.purple)
        .task {
            await business.load()
            if business.hasLoaded && business.workspaces.isEmpty { showsSetup = true }
        }
        .sheet(isPresented: $showsSetup) {
            NavigationStack {
                BusinessProfileView(viewModel: business, onSaved: {
                    campaignRefresh = UUID(); showsSetup = false
                })
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button("Set up later") { showsSetup = false }.disabled(business.isBusy)
                } }
            }
            .interactiveDismissDisabled(business.isBusy)
        }
    }
}
