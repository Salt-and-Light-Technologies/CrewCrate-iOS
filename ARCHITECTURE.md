# CrewCrate SwiftUI / MVVM audit and refactor

Audited October 9, 2026. Scope: all Swift source under the active iOS target, including preserved owner and former lead/campaign screens. No backend schema, deployment, credentials, bundle identity or brand assets changed.

## Apple guidance and project conventions

Apple explains observable model ownership, a single source of truth, and SwiftUI data flow. Its Observation guidance uses @State for an owned observable instance, @Bindable for editable bindings and plain references where bindings are unnecessary. This project applies those principles using strict MVVM, main-actor observable view-models, protocol-based async services and explicit composition. The Models / Views / ViewModels folder layout and one primary screen per file are project conventions, not an Apple-mandated folder specification.

Sources:
- https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app
- https://developer.apple.com/videos/play/wwdc2023/10149/

## Findings and changes

| Finding | Refactor |
| --- | --- |
| AuthenticationView.swift contained authentication, partner-list, app-root, routing and Account screens. | AuthenticationView, ContentView, PartnerExperienceView and ConnectedAccountView now have separate files in Views. Removed unused partner-list wrapper code. |
| Root ContentView.swift still contained obsolete setup/lead/campaign tabs despite no longer being the active root. | Replaced it with the actual app-level routing view in Views/ContentView.swift. No obsolete tabs remain in ContentView. |
| Onboarding UI already existed in Views/OnboardingView.swift, but its completion was interpreted by a parent view through onChange. | The dedicated onboarding view renders UI; OnboardingViewModel submits and invokes an injected completion action. PartnerExperienceViewModel reloads authoritative workspace status and controls routing. |
| SessionViewModel constructed concrete Supabase/API adapters and unused old tab models. | It now receives SessionServicing and injected identity/experience factories. Removed unused feature instances. App/AppDependencies.swift constructs live adapters and feature view-models. |
| PartnerExperienceViewModel depended on concrete APILeadRepository and constructed concrete onboarding stores. | It now receives PartnerSetupRepository, analytics state and an onboarding factory. |
| PartnerHomeViewModel performed nested network pagination. | CampaignAnalyticsService now loads/paginates campaign and conversation data behind CampaignAnalyticsRepository. The view-model owns display sorting, filtering, loading and errors. |
| CampaignSnapshot, AuthSession, LiveIdentity, LivePartner and CSVDocument lived in view-model/service files. | These data types now reside in Models. Demo fixture data moved into Models/DemoPartnerFixtures.swift. |
| Multiple primary view-models and feature screens were bundled under generic filenames. | Separated named files for campaign/lead/review view-models and campaign/lead screens, including preserved inactive features. Private presentation components remain alongside their parent view. |
| HTTP transport, token contract, error handling and repository implementation shared one file. | Named service files now separate transport, token contract, API error and API repository. Private wire DTO mapping remains internal to the repository adapter. |
| CSV inspection was a concrete dependency in view-models. | LeadFileInspecting abstracts inspection; the live composition injects the actor implementation. Compatibility defaults remain for existing standalone demo/check construction. |

## Current responsibility map

- App: app entry point and concrete dependency assembly.
- Configuration: public endpoint/publishable-key settings; no private keys.
- Models: domain data, validation and pure calculations; no UI or network access.
- ViewModels: main-actor Observation state, workflow actions, presentation and routing; no SwiftUI, Combine, UIKit, direct networking, Keychain or file persistence.
- Views: rendering, bindings and forwarding UI/lifecycle actions to view-models. Local sheet/file-picker presentation stays in @State.
- Services: async API, authentication, Keychain, persistence, CSV inspection and analytics loading; protocol boundaries allow independent tests.

The app still shows first-time onboarding then Analytics/Account. Owner overview source remains preserved and inaccessible through the live UI. Existing auth, server revisions, opt-out/campaign constraints and asset contents are preserved. No fake metrics added.

## Validation

- iOS simulator-target build succeeded after the refactor.
- Seven standalone check suites passed: MVVM, Auth, Onboarding, PartnerHome, LeadWorkspace, Campaign and OwnerReview.
- New MVVM tests use fake auth, identity and setup/submission services to verify sign-in, role-lookup failure, sign-out, successful submission navigation, failed submission gating and returning partner routing.
- Source placement checks confirm all View conformances are under Views and all primary ViewModel classes are under ViewModels; no UI imports or direct network/storage operations in view-models.
- All 10 original brand asset files retain their hashes.
- On-device presentation is not newly verified; use Xcode to check the existing flows. No Git commit/push or production deployment was performed.
