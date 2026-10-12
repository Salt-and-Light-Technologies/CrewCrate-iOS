# Current iOS workflow and device walkthrough

The next iOS views are implemented using SwiftUI, Observation-based MVVM and async/await.
No images, bundle identity or Xcode settings were edited in this step. No iOS build,
commit, push, deployment, live profile edit, import or model request was performed.

## What can be demonstrated

New signup is two steps: login details → business questions → Create account. Continue
does not call Supabase. Email-confirmation signups retain the business draft in user
metadata; the approval request is submitted after the first verified login. Immediate
session signups proceed through the same protected application flow. Test returning to
step one to edit credentials, invalid/missing business fields, signup failure, and
confirmation followed by login on another device. Business answers should not be asked
again for a valid saved signup draft. No client-supplied owner flag is stored or trusted.

1. Log in with an approved business account. The Home tab opens its campaign list.
   Accounts with multiple businesses choose a workspace; the platform owner opens
   any authorized business from Businesses. Unapproved applicants stay in the access flow.
2. Create a campaign. The editor has three steps: offer, assistant, contacts. Save a
   draft with just a name, or complete the offer/qualification details first. No sending
   occurs. The optional contact email is retained for existing backend planning compatibility;
   it does not enable email handoffs. Future real worker handoff will use the in-app inbox.
3. Choose one of ten assistant names, edit writing instructions, or apply a style preset.
   Presets replace the instructions field. The optional sending plan is a stored plan,
   not a connected scheduler. Existing hidden scheduling/recipient values survive editing.
4. Try the assistant using current unsaved or saved settings. Practice requires the
   existing AI-test migration, deployed endpoints and backend OpenAI configuration.
   This performs real model requests if configured; it never sends SMS or makes real bookings.
   Use fictional lead replies. Retry reuses a pending turn's ID/text/revision; Refresh
   recovers a committed reply after an uncertain response. A new test captures new settings.
5. Optionally choose CSV, TSV or Excel .xlsx from Files. Pick an Excel worksheet if there
   are several. Map phone (required), a combined name and email (optional). Preview must
   succeed before a staged file can be saved. Changing mapping invalidates the preview.
   The existing backend supports a combined name column; separate first/last-name mapping
   is still future work. Export Google Sheets/Numbers first. Files are limited to 5 MB.
6. Save imports valid contacts, preserves saved recipients and opt-outs, reuses duplicate
   business contacts and skips invalid rows atomically. A stale preview is rejected by
   the server. Uncertain saves are blocked from blind replay: return to the campaign list
   to check whether creation/import committed. A saved campaign can be reloaded after
   explicitly discarding unsaved edits. No device files or raw uploads are retained.
7. Open a saved campaign → Review campaign contacts. Search and paginate contacts
   attached to that campaign. Record permission evidence/source/date/country with an
   attestation, exclude a contact, or record an opt-out with confirmation. Opted-out
   contacts cannot be re-enabled. Registry status explicitly remains not screened.
   Permission recording is a business assertion, not external verification.
8. Account → Business information edits shared business name, website, services, area,
   time zone and assistant boundaries. Changes preserve unrelated onboarding fields on
   the backend and may invalidate readiness. Business calendar integration labels remain
   unconnected; there are no fake connect controls.

## Validation performed

- Standalone macOS Swift checks compiled service/model/view-model sources with the app's
  MainActor default. They pass for preserved campaign settings, preview invalidation,
  uncertain saves, stable practice-turn retries, opted-out contact protection and JWT,
  revision and multipart API request contracts.
- Existing business-access state checks pass.
- SwiftUI sources were syntax-parsed. This does not establish SwiftUI type checking,
  layout or navigation on a device; the user builds/tests iOS manually.

## Manual device checks

Verify Dynamic Type and VoiceOver labels, long offers, keyboard scrolling, close/discard,
loading/error states and back navigation. Test a mocked/development file with a bad row,
duplicate phone, multiple worksheets and a mapping change. Verify no second campaign is
created after an uncertain save. Test an expired/stale revision and refreshing before
retry. Test STOP, a declined offer and handoff in practice, and confirm simulated outcomes
cannot be mistaken for live bookings/messages. Check one business cannot access another.

## Still to implement

Worker roles/assignments and real conversation inbox; recipient selection and readiness
controls; invitations; separate first/last name mapping; provider delivery; authorized
national/state registry screening; Google Calendar/Calendly; recovery financial evidence
and analytics. Until integration is complete, there is no start-sending control.

## Commit/push commands

Review pre-existing reset changes before staging. These commands do not silently stage
old deleted sources or Xcode settings. Ensure the intended reset is included in your
reviewed commit(s) so the committed target matches this working tree.

```sh
cd /Users/jamesmcdougall/Desktop/Dev/SaltAndLight/CrewCrate/CrewCrate-iOS
git status --short
git diff
git add CrewCrate/CrewCrate/Models/CampaignWorkspace.swift CrewCrate/CrewCrate/Models/BusinessProfile.swift CrewCrate/CrewCrate/Models/WorkspaceContact.swift
git add CrewCrate/CrewCrate/Services/CampaignWorkspaceServicing.swift CrewCrate/CrewCrate/Services/BusinessProfileServicing.swift CrewCrate/CrewCrate/Services/WorkspaceContactServicing.swift
git add CrewCrate/CrewCrate/ViewModels/CampaignWorkspaceViewModel.swift CrewCrate/CrewCrate/ViewModels/BusinessProfileEditorModel.swift CrewCrate/CrewCrate/ViewModels/WorkspaceContactViewModel.swift
git add CrewCrate/CrewCrate/Views/CampaignWorkspaceView.swift CrewCrate/CrewCrate/Views/BusinessProfileEditorView.swift CrewCrate/CrewCrate/Views/WorkspaceContactView.swift CrewCrate/CrewCrate/Views/BusinessTimeZonePicker.swift Tests/CampaignWorkspaceChecks.swift IOS_WORKFLOW_SETUP.md
git add -p CrewCrate/CrewCrate/Models/BusinessApplication.swift CrewCrate/CrewCrate/Services/BusinessApplicationServicing.swift CrewCrate/CrewCrate/Views/BusinessAccessView.swift README.md ARCHITECTURE.md CLAUDE.md
git diff --cached
git commit -m "Add guided campaign, contact upload and AI practice views"
git push origin HEAD
```

The business-access foundation has its own staging instructions in the backend's
BUSINESS_ACCESS_SETUP.md. This iOS step adds no backend migration or new deployment
requirements beyond the existing business-access and AI-test features it calls.

For the two-step signup update:

```sh
git add CrewCrate/CrewCrate/Views/SignupBusinessView.swift Tests/SignupChecks.swift
git add -p CrewCrate/CrewCrate/Views/CreateAccountView.swift CrewCrate/CrewCrate/ViewModels/AuthenticationViewModel.swift CrewCrate/CrewCrate/Services/AuthenticationServicing.swift CrewCrate/CrewCrate/Services/SupabaseSession.swift CrewCrate/CrewCrate/Services/BusinessApplicationServicing.swift CrewCrate/CrewCrate/Models/BusinessApplication.swift README.md ARCHITECTURE.md IOS_WORKFLOW_SETUP.md
git diff --cached
git commit -m "Collect business details before creating an account"
git push origin HEAD
```

The owner setup guide can be committed separately in the backend repository with
`git add PLATFORM_OWNER_SETUP.md`, `git commit -m "Document platform owner login setup"`
and `git push origin HEAD`. Account creation and SQL execution are manual live setup;
no live owner account has been created by this change.
