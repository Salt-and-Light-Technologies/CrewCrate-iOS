# CrewCrate starter architecture

App/CrewCrateApp.swift opens Views/ContentView.swift, which owns the authentication NavigationStack. LoginView is the first screen, with navigation to CreateAccountView and ForgotPasswordView. AuthenticationStyle.swift provides shared form layout and styling using the existing CrateMark asset.

AuthenticationViewModel uses Observation and owns form state, validation and action feedback. Each screen owns its own form instance. Authentication is not connected yet; valid submissions explicitly report that no information or reset email was sent. No credentials are persisted.

All previous feature source is retained outside the Xcode filesystem-synchronized source group in LegacyReference/BeforeFreshStart-20261011. The existing Views/LaunchScreen.storyboard and asset catalog remain unchanged.

Future authentication integration should use injected async services under Services, keeping networking and persistence out of views. The user builds and tests the iOS app manually.
