import SwiftUI

/// Selects the app-level screen; feature layouts live in their own views.
struct ContentView: View {
    @Bindable var session: SessionViewModel
    var body: some View {
        Group {
            if session.isRestoring { ProgressView("Restoring your session…") }
            else if let experience = session.experience, session.identity != nil {
                PartnerExperienceView(viewModel: experience, session: session)
            } else { AuthenticationView(viewModel: session) }
        }.tint(.indigo).task { await session.restore() }
    }
}
