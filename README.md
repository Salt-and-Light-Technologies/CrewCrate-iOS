# Architecture refactor — October 9, 2026

Read ARCHITECTURE.md for the audit, Apple sources, folder responsibilities and validation. The app entry point and live dependency composition are now under App. ContentView is under Views and only selects app-level screens; onboarding, routing, analytics and Account have dedicated view files. Session and partner routing depend on injected service protocols/factories. Server submission completion is handled in view-models, not a view onChange. Models live under Models; campaign-data loading/pagination lives in Services. No feature behavior, brand assets or backend configuration changed.

Tests now compile Models, Services, ViewModels and Configuration source folders. Tests/MVVMChecks.swift verifies auth and submission-driven routing through fake dependencies. App sources are compiled by the Xcode target.

---

# Partner experience — October 9, 2026

The live app now routes unfinished partner workspaces (draft or changes_requested) directly into onboarding after sign-in, with no setup tab. Finishing setup submits through the existing server endpoint and reloads the workspace status; submitted and approved partners open Analytics. Returning partners use the server status, not a device-only completion flag. Owner accounts bypass partner onboarding. Missing workspace assignments and load errors remain visible and block onboarding/dashboard routing until resolved. Account remains accessible during onboarding and after completion.

The only home tabs are Analytics and Account. The old lead-management, campaign-management and setup-list screens remain in source but have no route from the live app. Analytics loads authorized campaigns and paginated manual conversation records through existing API adapters. Campaign and status filters drive summaries and campaign cards. Selected leads count campaign memberships; manual touches deduplicate lead IDs within each campaign. Current manual appointment/interested/handoff statuses are explicitly labeled. Provider messages, replies, verified conversions and revenue are unavailable rather than invented. No campaigns produces a clear empty state; no demo campaigns are injected. There is no campaign creation control in the new flow yet. No backend changes, migrations or delivery integrations were made in this step.

Tests/PartnerHomeChecks.swift covers onboarding status routing, unique touchpoint counts, filtering and empty-state loading. iOS simulator-target build and checks passed; on-device layout/navigation still needs user verification. Branding and authentication services remain unchanged.

---

# Live connection — October 8, 2026

The app now starts with email/password sign-in against the supplied CrewCrate Supabase project and uses https://crewcrate-api.onrender.com. Public connection settings are in LiveConfiguration. Secret keys and database credentials are never included. The composition root injects SupabaseSession into live API adapters; demo repositories remain available to previews and existing checks, but are not selected by the running app. Owner overview remains hidden.

Supabase access/refresh tokens are stored in a device-only, when-unlocked Keychain item. Passwords are not persisted. Expiring tokens refresh through a coalesced async task; sign-out removes the local session and requests local-scope server logout. The verified /v1/me response determines the role. All workspace routes rely on server authorization, not client claims. No owner dashboard or synthetic analytics are shown in live mode. Owners can access all authorized workspaces through the existing API; partners see memberships only.

Partner setup lists server-provisioned businesses, loads their server drafts, saves changes with expected revisions, and submits setup through the API. Existing device demo drafts are never uploaded into a real account. Server drafts currently resume at the first step because the backend has no saved-step field. CSV inspection inside onboarding remains a local inspection; import actual contacts through Leads. Setup submissions do not enable SMS delivery. Conflicts require reopening setup to reload the current revision; mutations are not automatically retried.

Invitation acceptance, password recovery screens, and in-app owner partner provisioning remain future work. Administrators currently create Supabase Auth accounts and assign their UID through POST /v1/partners. An authenticated account with no assignments shows an empty state, not sample businesses. The hidden owner view is preserved for future integration.

Tests/AuthChecks.swift covers secure-store abstraction, session refresh/rotation, coalesced concurrent refresh, sign-out isolation, and onboarding wire mapping/revisions. Run it with Models, Services, ViewModels using the existing standalone Swift check workflow. Live public health and Supabase settings checks passed; actual password sign-in and database-backed owner/partner isolation still require device testing. Never put passwords or bearer tokens in logs or test fixtures for live requests.

---

Historical phase notes below describe previous demo-only behavior.

# CrewCrate

Universal partner onboarding for any industry, built with SwiftUI and strict MVVM separation.

## Run

Open `CrewCrate/CrewCrate.xcodeproj` in Xcode and run the CrewCrate scheme on an iOS 18+ simulator or device.

## Architecture

- `CrewCrateApp.swift`: composition root; owns the observable onboarding and owner dashboard view models and injects their services.
- `Models/OnboardingDraft.swift`: Codable setup data, workflow enums, and validation rules.
- `ViewModels/OnboardingViewModel.swift`: main-actor `@Observable` state, navigation, validation, loading, saving, file inspection orchestration, and local review preparation.
- `Services/DraftStore.swift`: injected async storage protocol; actor-backed atomic JSON persistence and an in-memory implementation for previews/tests.
- `Services/LeadFileInspector.swift`: actor-backed security-scoped CSV reads and a pure CSV parser/summary builder.
- `Views/`: SwiftUI form rendering and user intents; no storage or CSV parsing in views.
- `ContentView.swift`: presents Owner demo, Leads, Campaigns and Partner setup tabs.

Observation is the state framework. All asynchronous operations use async/await. There are no UIKit or Combine imports.

## Working behavior

Seven steps: account/team, business, recovery goals, sales process, lead database, reporting/terms, and review. Any industry is accepted. Multiple recovery audiences, conditional booking fields, inline validation, step editing, and explicit save/continue are supported.

The draft is stored at Application Support/CrewCrate/Onboarding/draft-v1.json, independently of the old CRM store. Draft writes are atomic and use complete file protection on iOS. Save explicitly or continue to retain edits; the app also attempts to save when leaving the foreground. A restore failure blocks editing to avoid overwriting the existing draft. Previews use in-memory storage.

CSV inspection accepts UTF-8 files up to 5 MB/20,000 records, handles quoted commas/newlines/escaped quotes, maps a phone column, and summarizes unique plausible numbers, duplicates, and invalid numbers. It does not verify reachability, normalize international numbers fully, or establish contact consent. Only the summary persists; contact rows are discarded after inspection.

## Integration boundary

This is a local onboarding implementation. No accounts or invitations are created, no contacts are uploaded, no messages are sent, and no integrations or commercial agreements are executed. Prepare review saves a local prepared state; it does not submit to an owner or approve a launch. Existing CRM user data is untouched.

## Owner demo and review

The owner dashboard lists three clearly labeled sample businesses across roofing, dental and consulting. Search by business or industry, filter status, and inspect onboarding, lead inspection summaries, proposed terms and launch requirements. Review supports pilot approval, requesting changes, pausing and resuming the previous status, with timestamped decision history. Approval requires complete setup and launch requirements; change requests and pauses require a reason. Stale revisions reject conflicting decisions.

`Models/PartnerWorkspace.swift` defines status, readiness and decision history. `Services/PartnerRepository.swift` provides the replaceable async repository and in-memory demo actor. `ViewModels/OwnerDashboardViewModel.swift` owns dashboard and review state. The SwiftUI views render those models. Replace the repository at the app composition root when the backend is selected; the server must enforce authorization, partner isolation, atomic revisions and authoritative history.

Demo decisions reset on app restart. Partner setup drafts remain local and are not submitted to this sample list. Readiness flags and counts are sample data, not verified partner evidence. Pilot approval does not activate campaigns or notify anyone. Authentication, JWT issuance, live analytics and backend integration are deferred by request.

Next: connect these interfaces to authenticated partner workspaces, server-backed drafts, secure database uploads, reporting connections and agreement acceptance when the backend is chosen.

## Checks

`Tests/OnboardingChecks.swift` is a standalone async Swift check runner covering CSV parsing/rejection, industry-independent validation, persistent round trips, relaunch, validation gates, review state and storage failures. Compile it with the Models, Services and ViewModels source files using the macOS SDK, then run the result. It is deliberately outside the app's synchronized source folder.

The simulator build and check runner passed. In this tool environment only, the build used a command-line `-disable-sandbox` Swift flag to avoid nesting the Apple macro subprocess sandbox inside the tool sandbox. That flag is not saved in the Xcode project. Simulator services were unavailable for an actual UI launch; complete device, Dynamic Type, VoiceOver, dark-mode, keyboard and background/lock testing before release.

## Brand preservation

All original Assets.xcassets files remain unchanged, including normal/dark/tinted app icons and the three crate-mark resolutions. The existing display name, bundle identity and app-icon settings are retained. The previous CRM and backend remain archived from the ground-up reset.

`Tests/OwnerReviewChecks.swift` covers approval gates, invalid transitions, stale revisions, reason validation, pause/resume history, dashboard filters and view-model error recovery. The owner phase simulator build and checks passed; actual UI launch remains unverified.

## Lead workspace phase

The Leads tab lists every sample partner with measured in-memory lead and import totals. Each workspace supports security-scoped CSV selection, phone/name/email mapping, a read-only preview, up to 100 row-level duplicate/invalid issues, a separate import confirmation, searchable status-filtered lead lists, reversible review classifications, import history and actor-attributed activity. Lists paginate in batches of 50. Owner partner review links to the same workspace. The composition root shares one demo repository, so owner status changes and lead mutations use the same partner revision. Imports require draft or changes-requested status; paused partners cannot classify leads. Imports clear launch attestations and update the latest local import summary. No campaigns are sent by importing or marking a contact eligible.

A sample CSV demonstrates valid contacts, a duplicate and an invalid row. Demo contacts and activity remain in memory and reset on app restart; original uploaded files are discarded. This is explicitly separate from the existing persisted onboarding draft, which still saves a local inspection summary rather than uploading contacts. No account-to-partner authorization is simulated as real security in this demo.

`Models/LeadWorkspace.swift` defines lead records, batches, summary counts, issue previews and mappings. `Services/LeadRepository.swift` is the replaceable async contract. `DemoPartnerRepository` implements both owner review and lead services in one actor. `ViewModels/LeadWorkspaceViewModel.swift` owns list/detail/import workflow state, and `Views/LeadWorkspaceView.swift` renders it with SwiftUI/Observation.

`Services/APILeadRepository.swift` implements the actual HTTP adapter for the new backend endpoints: workspace summaries, paginated leads/imports/activity, multipart preview/commit and revision-checked classification. It requires an HTTPS API URL and an injected `APITokenProvider` supplying a verified Supabase session's access token per request. `URLSessionLeadTransport` is ephemeral with no cookie or response cache; credentials are not persisted by this adapter. Owner versus partner listing is selected from authenticated app state in a future composition, and the server still enforces privileges. Wire statuses, snake_case JSON, UUIDs and fractional ISO8601 timestamps are mapped explicitly. HTTP 401/403/404/409/413 failures are reported and mutations are not automatically retried.

The live composition remains deferred because the Render API URL and Supabase public settings are unavailable. Sign-in, token refresh/keychain storage, onboarding server synchronization and production configuration are not implemented by this lead phase. Configure these before substituting the live repository in the app; never embed a service-role key or database password. Prepared onboarding drafts are not automatically submitted to any workspace.

`Tests/LeadWorkspaceChecks.swift` covers previews staying read-only, local and cross-import deduplication, invalid mapping, stale import/classification revisions, cross-partner mutation rejection, paused status, search, activity, view-model reloads, multipart requests, bearer headers, pagination/query encoding, wire-model decoding and HTTP error propagation. Lead, owner and onboarding checks pass along with the simulator build. Actual device UI execution remains unverified.

## Campaign planning and manual conversation tracking

The Campaigns tab now provides partner-scoped recovery plans: offer, first-message draft, qualification/handoff rules, eligible-recipient selection, proposed time zone/window, daily contact cap (1–100), follow-up limit (0–3), and up to 500 recipients. Users save drafts and prepare them themselves; no per-campaign owner approval exists. Established partner setup must still satisfy its existing approval/readiness gates. An owner can inspect plans and place a server-enforced hold; only the owner can release that hold. A partner can pause/resume its own plan. Resume returns to draft, and archiving prevents edits.

Preparation requires complete setup, eligible contacts, manually recorded SMS permission references, no opt-out, and complete campaign fields. Preparing means ready to connect, not queued, launched or delivered. Changing settings clears preparation. Partner/recipient revision changes make previously prepared plans require another check. Lead permission editing records evidence or revocation in activity. Opted-out leads cannot be re-enabled through the endpoint. Permission records are team assertions, not external verification or a substitute for provider-specific requirements.

`Models/Campaign.swift`, `Services/CampaignRepository.swift`, `ViewModels/CampaignViewModel.swift` and `Views/CampaignView.swift` implement the MVVM workflow. The shared demo actor seeds one explicitly sample approved partner with permitted, unknown-permission and opted-out contacts. All records reset on app restart; no real permission claims are inferred from imports. HTTP campaign, permission and manual-tracking calls extend `APILeadRepository` with explicit wire models, revisions and error handling. The live adapter still requires the pending public URLs and a real Supabase session provider.

Manual follow-up tracking records new/interested/appointment/handoff/closed statuses and internal notes with actor/time history. These records do not represent SMS replies, delivery receipts, verified bookings or revenue. Conversation history and campaign history paginate separately. Unsaved campaign edits are protected from background reload; explicitly save or discard before refreshing.

`Tests/CampaignChecks.swift` covers self-service preparation, permission/opt-out blocks, stale revisions, controls, manual tracking, note history, unsaved edit protection and HTTP campaign/tracking contracts. All four standalone suites and the simulator build pass. Backend tests cover real owner-hold authorization with mocked identity; the local demo is not an authentication/security simulation. Actual device UI execution remains unverified.

Remaining integration work: validate both additive migrations against development Supabase/Postgres; configure public connection settings, Supabase sign-in/session refresh and scoped iOS composition; choose/connect an SMS provider. Provider work must add dispatch-time eligibility/suppression rechecks, actual time/volume enforcement, opt-out handling, signed inbound/delivery callbacks and idempotent delivery. Draft limits and planned follow-ups have no running scheduler yet. No provider connection or deployment was performed in this phase.

## Owner performance demonstration

Owner overview now places Partner sales performance between Demo workspace and All sample partners. An injected, explicitly demo-only OwnerAnalyticsProvider supplies example 30-day snapshots, independently of local lead/campaign mutations. The view model aggregates total leads, messaged leads, sales conversions, qualified leads awaiting sales contact and reported recovered revenue. Per-partner disclosure cards show replies, qualification, sales touches, appointments, overdue follow-ups and supporting-record gaps. Bright Dental has 1,200 illustrative leads and opens expanded. Counts represent unique leads in overlapping stages; conversions mean reported closed sales. Messaging/conversion rates use total leads as denominator; reply rate uses messaged leads. No live messages, sales or verified evidence are claimed. Default view-model composition has no analytics provider; the app's demo root explicitly injects it so a future live repository cannot silently show these fixtures.

Each expanded partner performance card now includes native Swift Charts for all twelve lead/sales count metrics and reported revenue. Count charts retain exact values and show their comparison denominator and percentage; chart scales vary with the comparison group. Revenue is a labeled period total rather than invented historical movement. Charts include accessibility values and remain clearly demo-only. Simulator build passes; runtime visual/device inspection remains outstanding.
