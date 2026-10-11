# CrewCrate iOS

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
