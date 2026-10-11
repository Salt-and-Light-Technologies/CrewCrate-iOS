# CrewCrate simplified interface

Campaign creation and editing now use four steps: campaign basics, assistant and team, contacts, review and save. Continue checks uploaded files before moving to review. Drafts may be saved without contacts. Sending settings are optional expanded details, and invalid settings open automatically on review.

Saved campaigns have three main actions: Campaign setup, Choose contacts, Try assistant. Start messages remains at the bottom. Its existing provider-pending behavior remains; this change does not enable SMS.

Contact selection has one select-all action, permission filtering, visible checks, 250-contact paging, and a fixed Save button. Leaving with changed selection asks whether to discard. Contact permission opens with the current status; detailed records are collapsed.

Business setup, account saving, and campaign saving use consistent large buttons. Technical workspace language is replaced with business language. Practice conversations clearly say that no real texts are sent.

## Verification

Swift syntax parsing and standalone macOS mock service/view-model checks passed. Added assertions for unsaved contact-selection state. No iOS app build or simulator run was performed. No backend changes, database migrations, or deployment are required.

On your device, check:
1. Sign in and edit your business and profile; save both.
2. Create a campaign through all four steps, including going Back.
3. Upload a CSV, confirm detected columns and permissions, then Continue.
4. Save, reopen, edit, and confirm your values are preserved.
5. Choose contacts, filter, select all, load more, save, and reopen.
6. Change selection and Cancel; confirm discard protection.
7. Try the assistant and Start messages; confirm practice-only/provider-pending behavior.
8. Increase text size in Settings and check each screen, including with the keyboard open.

## Commit and push

Run these commands from Terminal. The existing Xcode project-file changes are excluded.

```sh
cd /Users/jamesmcdougall/Desktop/Dev/SaltAndLight/CrewCrate/CrewCrate-iOS
git add CrewCrate/CrewCrate/Views/*.swift CrewCrate/CrewCrate/ViewModels/RecipientReviewViewModel.swift Tests/AuthenticationChecks.swift UI_UX_REFACTOR.md
git diff --cached --stat
git commit -m "Simplify campaign setup and contact selection"
git push origin main
```
