# CrewCrate starter architecture

## Current business-access composition

Signup begins with CreateAccountView → SignupBusinessView. AuthenticationViewModel owns
the business draft and local step-one validation; only final submission invokes signup.
SupabaseSession sends draft metadata with the auth request. Its business-application
service recovers this metadata after authenticated email confirmation and submits it
through the protected API when there is no existing application. Metadata carries no
role/access claims and no password. Authentication state remains Observation/MainActor;
HTTP, encoding and recovery stay in the service actor.

ContentView shares one SupabaseSession with AuthenticationViewModel and the signed-in
BusinessAccessView. BusinessAccessViewModel owns the application form, request inbox,
server loading and review actions; BusinessApplicationServicing is the injected boundary.
SupabaseSession implements that boundary in a separate extension with JWT-authenticated
requests and pagination. Networking/DTO decoding runs in the service actor; observable
state stays on MainActor. Views render state and dispatch async actions. The business
application is separate from an approved business workspace and grants no membership.
Roles are determined by the verified identity, never by the login toggle.

## Campaign and contact workflow

CampaignWorkspaceViewModel owns the campaign list. CampaignEditorModel owns editor
steps, full typed configuration, staged files/mappings, revision-bound previews and
mutations. CampaignWorkspaceServicing is implemented by a SupabaseSession extension;
HTTP/multipart work stays in the service actor. ContactUploadReader reads bounded file
data with balanced security-scoped access off MainActor. Files stay in memory and are
released after saving/removing/dismissing the editor. Edits preserve the original full
configuration, including recipients and scheduling values that the user has not changed.

PracticeConversationModel owns transcript/turn state and stable UUID/text/revision retry
snapshots. Refresh recovers committed replies and avoids replaying stale turns. No fake
AI transcript is supplied. WorkspaceContactViewModel paginates campaign-scoped contacts;
ContactPermissionEditorModel manages evidence and opt-out review. BusinessProfileEditorModel
loads/saves shared business context with expected revisions. All use Observation,
async/await and injected Sendable protocols. UI state remains on MainActor.

The following older architecture notes contain removed features; consult active source
and README's current implementation section for present behavior.

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

CampaignDetailsView uses the system fileImporter for CSV/TSV/XLSX. ContactFileReader
loads bounded data off the main actor with balanced security-scoped access. The editor
view model owns file/mapping/preview state and invalidates previews when selections
change. CampaignImportServicing methods in SupabaseSession use authenticated multipart
requests for columns, preview and transactional campaign/import saving. Original server
recipient IDs remain in CampaignDetails, and additional imported leads are appended by
the backend. View code only renders state and triggers view-model operations.
