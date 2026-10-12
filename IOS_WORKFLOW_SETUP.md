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

## Sending-plan controls (October 12, 2026)

New Campaign step two and Edit campaign details share `CampaignEditorView`.
Timing and limits now uses compact native time pickers (locale-aware display) and
direct numeric fields with number-pad keyboards and Done dismissal. Start/end retain
hour/minute wire fields and use the selected campaign time zone as wall-clock times;
changing the device or campaign time zone does not shift those saved clock values.
The valid planning window remains 09:00–17:00 with start before end.

Edited numeric values accept whole numbers: 1–1000 leads contacted per day and 0–3
planned follow-ups, using the authorized increased daily maximum. Blank, overflow,
noninteger and out-of-range edits show an error and block Continue from step two and
Save. Saved values remain intact and are not clamped on opening. Values outside 1–1000
require correction before saving. Reload clears numeric
drafts and displays the server values again.

The daily helper distinguishes the planned daily outreach limit from repeated contact
with one lead. Follow-up helper deliberately states the integration gap: the backend
stores `follow_up_limit` but has no scheduler or defined per-lead/campaign-wide counting,
interval, or total-attempt calculation. Do not interpret this UI as defining delivery
semantics. Sending logic, backend values, shared AI rules and additive signals are unchanged.

Validation: standalone macOS CampaignWorkspaceChecks compiled and passed with
MainActor isolation, including numeric boundaries/recovery, unchanged saved values,
reload, clock minutes/time-zone preservation and equal-window rejection. SwiftUI view
syntax parsing and `git diff --check` passed. No iOS/Xcode app build, deployment or real
messages occurred. Manually verify native picker locale display, number-pad dismissal,
Dynamic Type/VoiceOver and create/edit navigation on the device.

To commit this follow-up after reviewing the accumulated changes:

```sh
cd /Users/jamesmcdougall/Desktop/Dev/SaltAndLight/CrewCrate/CrewCrate-iOS
git diff
git add CrewCrate/CrewCrate/Views/CampaignWorkspaceView.swift CrewCrate/CrewCrate/ViewModels/CampaignWorkspaceViewModel.swift Tests/CampaignWorkspaceChecks.swift IOS_WORKFLOW_SETUP.md
git commit -m "Use editable sending plan controls and clarify limits"
git push origin HEAD
```

The view/model files also contain the authorized earlier AI changes; review and stage
those together with `CrewCrate/CrewCrate/Models/CampaignWorkspace.swift` if still uncommitted.

### Leads contacted maximum

The shared field label and accessibility label are exactly `Leads contacted`; helper
text retains daily scope. Both the frontend and CampaignConfig API contract accept
1–1000 and reject 1001, with unchanged time and follow-up limits. The backend previously
had no upper daily limit; it now enforces the authorized 1000 maximum. No migration is
required. Existing values are not rewritten; stored values above 1000 must be corrected
before use with the updated contract. Standalone Swift checks verify saving 1000 and
blocking 1001; backend API checks verify create acceptance and create/edit rejection.

The follow-up field and accessibility label are exactly `Planned follow-up`. Its label
allows vertical wrapping instead of truncation; detailed help stays below the control.

## Campaign start and end dates

Timing and limits now places native Start date and End date pickers directly above
Business time zone in the shared New Campaign/Edit editor. Enable `Use a date range`
to choose dates (initial selection is today in the chosen business time zone through
seven days later). Disable it to retain the explicitly labeled no-date-restriction
behavior used by old campaigns. Neither opening the editor nor changing the time zone
rewrites stored dates. Both dates are included; equal dates are valid and a reversed
range blocks Continue/Save. The existing clock pickers and numeric/follow-up controls
remain unchanged. ISO date strings round-trip in campaign configuration JSON, rather
than shifting calendar days through timestamp conversions.

Backend launch checks the selected local date before reaching its disabled delivery
boundary. The period is a stored daily campaign plan; no daily scheduler or follow-up
sending exists yet. There are no current weekday controls to change. Device checks
should verify picker locale display, dates above Business time zone, equal/reversed
ranges, legacy undated edits and date retention after save/reload. Swift standalone
checks and syntax parsing pass; no iOS app build or live requests were performed.

Additional backend files for review/staging: `app/campaign_schedule.py`,
`app/campaigns.py`, `app/schemas.py`, `app/ai_tests.py`, `openapi.json`,
`tests/test_campaign_schedule.py`, and `AI_BEHAVIOR.md`. Stage the iOS campaign model,
view/model, `Tests/CampaignWorkspaceChecks.swift` and this document along with the
previous authorized uncommitted changes; the earlier commit/push commands still apply.

## Permission import and filtered contact preview

Both create/edit upload flows map SMS permission, Permission evidence and Opted out.
Recognized unambiguous headers are preselected; ambiguous aliases need manual mapping.
The attestation defaults off. A yes/true/recorded value requires at least 8 characters
of evidence and business-specific review confirmation; missing/unknown values never
grant consent, and unrecognized values reject the import. No opt-out is not consent.
No import/review can resurrect an existing opt-out.

Preview and actual multipart upload share one mapping builder, including attestation.
Eligible-only display defaults on; turn it off to inspect excluded contacts/reasons.
Counts cover distinct normalized phones across the whole file, using existing stored
preferences and all duplicate rows. Samples cap at 100 eligible plus 100 excluded;
invalid rows remain separately counted. Display filtering never controls eligibility.
All valid contacts/preferences remain saved, even excluded contacts. The app requests
`eligible_recipients_only=true` on campaign import; the backend then selects only
eligible contacts, including removing newly suppressed saved recipients. Preview
filtering is independent of that enforcement. The recipient-save endpoint also filters
excluded contacts. Legacy API callers can retain all associations, but preparation and
launch still block selected excluded contacts. Test-only records are
excluded from real SMS eligibility too.

Parsed source rows are retained per import batch for backend audit, including excluded
and invalid rows in successful imports. This requires the new manual backend migration
`202610120001_import_row_audit.sql`; it has not been applied. Raw data is not forwarded
to AI. Deploy/migrate the backend before using the new app fields. Standalone Swift
mapping/preselection/preview decoding and payload parity checks pass, along with 123
backend tests, Ruff, SwiftUI syntax parsing and diff checks. No iOS app build or live
model/SMS requests were performed; verify picker/accessibility/preview layouts on-device.

Review/stage this feature with:

```sh
cd /Users/jamesmcdougall/Desktop/Dev/SaltAndLight/CrewCrate/CrewCrate-iOS
git add CrewCrate/CrewCrate/Models/CampaignWorkspace.swift CrewCrate/CrewCrate/Services/CampaignWorkspaceServicing.swift CrewCrate/CrewCrate/ViewModels/CampaignWorkspaceViewModel.swift CrewCrate/CrewCrate/Views/CampaignWorkspaceView.swift Tests/CampaignWorkspaceChecks.swift IOS_WORKFLOW_SETUP.md
git diff --cached
git commit -m "Import contact permissions and show safe eligibility previews"
git push origin HEAD
cd ../CrewCrate-Backend
git add app/imports.py app/main.py app/models.py app/schemas.py app/campaigns.py app/contact_policy.py openapi.json tests/test_permission_preview.py tests/test_spreadsheet_imports.py supabase/migrations/202610120001_import_row_audit.sql README.md
git diff --cached
git commit -m "Preserve imported preferences and enforce preview eligibility"
git push origin HEAD
```

These files contain earlier authorized uncommitted changes too; review those before
committing. No automatic commit/push is performed.

## Sole designated AI identity control

The step-one AI assistant name text field has been removed. Step two's Designated AI
picker is now the sole identity editor for both create and edit. It reads/writes the
existing `ai_name` field; there is no separate AI profile ID or hidden override in this
application. New campaigns still default to Emma. Legacy custom names remain visible
as saved picker options; nil/blank names display AI Assistant, matching backend context.
Selecting a listed AI replaces the old name in save/import and new practice payloads.
The shared policy now explicitly says tone/profile/offer/lead text cannot override the
selected name. Partner business identity and honest AI disclosure remain required.

Previously saved practice sessions keep their captured campaign context; start a new
practice session after changing the designated AI. Saved campaign preparation generates
a new opening from the current name rather than reusing the old opening draft. Legacy
custom names are supported, not silently migrated or hidden behind an unrelated default.
Standalone Swift checks verify replacing an old name, saving the selected one and
nil/blank fallback. Backend tests verify context/selected opening identity. No iOS app
build, deployment or live model/outreach requests were performed.
