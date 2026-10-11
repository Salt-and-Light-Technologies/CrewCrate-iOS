# CrewCrate starter architecture

App/CrewCrateApp.swift opens Views/ContentView.swift, which owns the authentication NavigationStack. LoginView is the first screen, with navigation to CreateAccountView and ForgotPasswordView. AuthenticationStyle.swift provides shared form layout and styling using the existing CrateMark asset.

AuthenticationViewModel uses Observation and owns form state, validation and action feedback. ContentView owns and injects one shared authentication view-model. SupabaseSession is an actor implementing AuthenticationServicing; it owns signup, login, refresh, recovery, password updates, logout and backend identity verification. KeychainSessionStore persists tokens securely; passwords are not persisted. AuthInfo.plist registers the recovery/confirmation callback scheme outside the synchronized source group. Signed-in users currently see a minimal confirmation screen.

All previous feature source is retained outside the Xcode filesystem-synchronized source group in LegacyReference/BeforeFreshStart-20261011. The existing Views/LaunchScreen.storyboard and asset catalog remain unchanged.

Networking and persistence stay in injected services; views contain presentation and async action dispatch only. The user builds and tests the iOS app manually.
