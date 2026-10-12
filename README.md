# CrewCrate iOS

## Two-step signup

Business login now checks the application first. Pending/denied applicants cannot open
business screens, and a membership is usable only with an explicit server approval flag.
Missing approval fields from an older backend do not grant access. Signup completion
states that approval is required. See ../CrewCrate-Backend/BUSINESS_APPROVAL_FIX.md;
the additional gate migration/backend deployment is required for live behavior.

CreateAccountView now validates login details locally and navigates to SignupBusinessView
without creating an authentication user. The second screen collects business name,
contact name/phone and optional referral; its Create account button performs signup.
Business details are staged in Supabase signup metadata (never the password) so they
survive email confirmation and another device. After verified login, an unassigned user
with no existing application submits that draft through the authenticated application
endpoint. This grants no business access until owner approval. Existing users without
signup metadata can still complete the signed-in application form.

Standalone Tests/SignupChecks.swift passes for no signup before business completion,
metadata request payloads and application recovery. No live signup or iOS build was run.
The selected platform-owner email and secure setup SQL are documented in
../CrewCrate-Backend/PLATFORM_OWNER_SETUP.md; no credentials are embedded in the app.

## Current implementation — business access foundation

The signed-in placeholder is now replaced by an Observation/MVVM business-access flow.
Unassigned users complete a short business/contact/referral application and see a pending
or denied state. Verified platform owners see Businesses, Requests and Account; Requests
supports approve/deny with revision checks. Approved businesses see a simple three-step
recovery overview. Platform-owner sign-in is selectable on Login and verified by the
backend; the toggle does not grant privileges. Request lists refresh while the app is
active and retain pending requests on the backend. No push notification delivery exists.

Deploy the business-application backend migration/endpoints before using these screens.
See ../CrewCrate-Backend/BUSINESS_ACCESS_SETUP.md.

Approved businesses now open a campaign list with a three-step draft editor: offer,
assistant and contacts. The editor supports ten assistant names, writing-style presets,
custom instructions, draft editing, CSV/TSV/XLSX upload, worksheet selection, mapping,
preview and atomic campaign/import saving. AI practice uses a snapshot of the editor's
settings and retains request IDs for turn retries. Saved campaigns expose paginated
contact review and opt-out recording. Account opens business information editing;
calendar connections remain explicitly unconnected. See IOS_WORKFLOW_SETUP.md.

Worker assignments/inbox, Twilio delivery, national registry screening, calendar booking,
financial tracking and invitations are not enabled yet. No live outreach can start.

Tests/BusinessAccessChecks.swift exercises approval UI state and owner-login authorization
with injected fakes as a standalone macOS executable, not an iOS build. SwiftUI sources
were syntax-parsed; on-device layout/navigation remains for the user's manual checks.
Tests/CampaignWorkspaceChecks.swift adds mocked editing/import/retry/permission and
HTTP-contract checks. The historical sections below describe earlier implementations;
consult the current sections and active source for present behavior.

Reset to a minimal SwiftUI starter application on October 11, 2026 at the user's request.

The app opens a login screen with CrateMark, email and password fields, and links to account creation and password recovery. Forms connect to the existing Supabase project for password login, signup, recovery emails and password updates. Keychain stores sessions; refresh tokens renew expired access tokens. The API verifies login through GET /v1/me. Signed-in users start on Campaigns, with an Account tab. Campaigns load from assigned backend workspaces; the plus button opens a full-screen form and saves campaign details as a server draft. All asset catalog files, images, the existing purple CrateMark launch screen, bundle identity and Xcode project settings are preserved.

Previous onboarding, authentication, analytics, campaigns, lead management, account features and standalone checks are archived in LegacyReference/BeforeFreshStart-20261011, outside the app target. No backend files or live records were changed. The starter app does not access previously stored sessions or drafts.

The user builds and tests the iOS application manually. Do not run application builds.

## Authentication configuration and checks

In Supabase Authentication → URL Configuration, add `crewcrate://auth` to Redirect URLs. Signup confirmation and recovery requests use that URL, registered by AuthInfo.plist. Keep standard confirmation/recovery email templates that follow Supabase verification links. Email confirmation requirements, signup availability, password policy and email delivery are controlled by the existing Supabase project. No live settings were modified by this change.

Recovery links open the new-password form; successful updates verify the session against the backend. New auth users are not automatically assigned a partner workspace or owner role. Those remain existing backend provisioning operations. No onboarding screens were restored.

Tests/AuthenticationChecks.swift is a standalone macOS service check using mocked HTTP and memory storage. It covers login/JWT headers, confirmation-required signup, recovery requests/callbacks/password updates, session refresh, logout and invalid credentials. It does not build or run the iOS application, send emails, or prove live deployment behavior.

## Campaigns and account

Campaigns and Account each have their own navigation stack. Campaign loading paginates workspaces and campaign records through the existing API. Unassigned users see an explicit empty state; draft creation requires an assigned, non-paused workspace. Details include name, offer, AI name/instructions, qualification and handoff email. Saving creates only a draft; recipients, preparation and sending are outside this screen's current scope.

Account loads and saves first_name/last_name in Supabase user metadata. Email changes use Supabase user updates, showing pending confirmation rather than pretending the address changed immediately. Pull to refresh account after confirmation. Profile photos are resized and stored under Application Support/ProfilePhotos by authenticated user UUID with file protection; they persist on this device but do not sync to other devices. Logout clears the Keychain session through the shared authentication service.

Standalone checks additionally verify account metadata/email request payloads and campaign workspace/list/draft API calls with mocks. No live profile edits, campaigns or iOS build were performed for validation.

## Test AI

Saved campaigns now open a details screen with Test AI. The new campaign form also
supports testing its current unsaved settings when a workspace and campaign name are
selected. The practice screen generates the opening outreach, accepts fictional lead
replies, displays simulated decisions/handoff summaries, and supports New test.
Opt-out, decline and handoff states stop the session. No SMS, real handoff notification
or real contact permission update occurs.

AITestViewModel owns async workflow and retry IDs; SupabaseSession implements
TestAIServicing using JWT-authenticated CrewCrate endpoints. Test DTOs remain in the
existing Models/AuthenticatedIdentity.swift source file, alongside other API DTOs.
Backend deployment and the new ai_test_sessions migration are required before use;
see ../CrewCrate-Backend/TEST_AI.md for exact rollout and manual device checks.

Business onboarding opens after authentication when no workspace is available, including
for existing accounts. Email-confirmation signups complete business setup on their first
sign-in. Users can defer setup and return through Account → Set up your business. Once
saved, campaigns reload with the assigned workspace. Account → Edit business information
updates business name, website, industry, services/products, service area, time zone and
AI boundaries; users with several businesses select one in that screen. The backend binds
creation to the verified user and stores updates with expected revisions. Deploy the new
backend endpoints before testing. No additional database migration is needed.

Saved campaigns support Edit → Save changes using the existing backend PUT endpoint.
The editor preloads campaign name, offer, AI name/instructions, qualification and sales
email. Saves use expected_revision, update the existing campaign, refresh the details
and list, and reset campaign preparation to draft. Unexposed template, schedule, limits
and recipient IDs survive updates. Failed saves retain edits; Reload and discard edits
fetches the latest saved campaign after a conflict. Paused/archived editing restrictions
remain enforced by the backend. No backend deployment or migration is needed.

Campaign leads: Upload contact file is available in both new and saved-campaign editors.
Choose a CSV, TSV or .xlsx from Files, select an Excel worksheet if needed, map phone
(required) and name/email (optional), then Preview leads. Changing mappings invalidates
the preview; Save is disabled until a new preview succeeds. Saving atomically adds valid
contacts to the campaign, preserves existing recipients, reuses duplicates and skips
invalid rows. Up to 500 distinct recipients per campaign, 5 MB per file. Export Google
Sheets or Numbers to supported formats first. Imports do not establish permission to
text, and no SMS is sent. Deploy the new backend before device testing. Original files
are read with security-scoped access and staged only in memory until save/dismiss.
