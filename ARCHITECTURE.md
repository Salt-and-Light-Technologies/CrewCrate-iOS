# CrewCrate starter architecture

App/CrewCrateApp.swift opens Views/ContentView.swift, which owns the authentication NavigationStack. LoginView is the first screen, with navigation to CreateAccountView and ForgotPasswordView. AuthenticationStyle.swift provides shared form layout and styling using the existing CrateMark asset.

AuthenticationViewModel uses Observation and owns form state, validation and action feedback. ContentView owns and injects one shared authentication view-model. SupabaseSession is an actor implementing AuthenticationServicing; it owns signup, login, refresh, recovery, password updates, logout and backend identity verification. KeychainSessionStore persists tokens securely; passwords are not persisted. AuthInfo.plist registers the recovery/confirmation callback scheme outside the synchronized source group. SignedInTabView opens Campaigns and Account with separate navigation stacks. CampaignsViewModel loads workspace-scoped records through CampaignServicing; CampaignDetailsViewModel validates and saves server drafts. AccountViewModel loads and updates Supabase profile metadata/email through AccountServicing and saves per-user photos through ProfilePhotoStore. PhotosPicker transfer and processing live outside the view. ContentView composes one shared SupabaseSession for auth, account and campaigns.

All previous feature source is retained outside the Xcode filesystem-synchronized source group in LegacyReference/BeforeFreshStart-20261011. The existing Views/LaunchScreen.storyboard and asset catalog remain unchanged.

Networking and persistence stay in injected services; views contain presentation and async action dispatch only. The user builds and tests the iOS app manually.


AITestView presents a persisted practice transcript using AITestViewModel and injected
TestAIServicing. SavedCampaignDetailsView passes the saved campaign ID; the draft
editor passes its validated current config. SupabaseSession handles all HTTP/JWT and
DTO work. AITestViewModel retains pending request UUID/text/revision for safe turn
retries. Backend state controls whether the composer is available.

BusinessProfileView uses an Observation BusinessViewModel and injected BusinessServicing.
SignedInTabView owns the model, presents missing-workspace setup after authentication,
and refreshes Campaigns after saving. Account reuses this model for business editing.
SupabaseSession sends authenticated requests to /v1/me/business and partner business
updates; business data is stored in existing partner onboarding records, separate from
personal Supabase profile metadata. Email confirmation can precede business onboarding.

SavedCampaignViewModel loads saved details and manages editor presentation. The shared
CampaignDetailsViewModel supports create and update modes with independent original
snapshots and optimistic revisions. CampaignServicing exposes detail and update requests.
CampaignDetails retains the full current backend config so editing visible fields cannot
reset hidden scheduling/recipient settings. Successful updates replace the list record.
