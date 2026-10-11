import SwiftUI

struct SignedInTabView: View {
    let service: SupabaseSession
    let userID: UUID
    var body: some View {
        TabView {
            NavigationStack { CampaignsView(viewModel: CampaignsViewModel(service: service)) }
                .tabItem { Label("Campaigns", systemImage: "megaphone") }
            NavigationStack { AccountView(viewModel: AccountViewModel(service: service, userID: userID)) }
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .tint(AuthenticationStyle.purple)
    }
}
