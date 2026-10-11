# CrewCrate iOS

Reset to a minimal SwiftUI starter application on October 11, 2026 at the user's request.

The app opens a login screen with CrateMark, email and password fields, and links to account creation and password recovery. Forms connect to the existing Supabase project for password login, signup, recovery emails and password updates. Keychain stores sessions; refresh tokens renew expired access tokens. The API verifies login through GET /v1/me. The signed-in screen is a minimal confirmation pending the new workspace UI. All asset catalog files, images, the existing purple CrateMark launch screen, bundle identity and Xcode project settings are preserved.

Previous onboarding, authentication, analytics, campaigns, lead management, account features and standalone checks are archived in LegacyReference/BeforeFreshStart-20261011, outside the app target. No backend files or live records were changed. The starter app does not access previously stored sessions or drafts.

The user builds and tests the iOS application manually. Do not run application builds.

## Authentication configuration and checks

In Supabase Authentication → URL Configuration, add `crewcrate://auth` to Redirect URLs. Signup confirmation and recovery requests use that URL, registered by AuthInfo.plist. Keep standard confirmation/recovery email templates that follow Supabase verification links. Email confirmation requirements, signup availability, password policy and email delivery are controlled by the existing Supabase project. No live settings were modified by this change.

Recovery links open the new-password form; successful updates verify the session against the backend. New auth users are not automatically assigned a partner workspace or owner role. Those remain existing backend provisioning operations. No onboarding screens were restored.

Tests/AuthenticationChecks.swift is a standalone macOS service check using mocked HTTP and memory storage. It covers login/JWT headers, confirmation-required signup, recovery requests/callbacks/password updates, session refresh, logout and invalid credentials. It does not build or run the iOS application, send emails, or prove live deployment behavior.
