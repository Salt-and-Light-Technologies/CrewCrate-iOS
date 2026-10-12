# Owner request inbox loading failure

The deployed public API contract was inspected and includes the owner application routes
and business approval field. This confirms routes are deployed, not that the database
migrations are applied or authenticated calls succeed.

## Corrected iOS behavior

The owner dashboard previously awaited Requests and Businesses as one result. A failure
in either discarded both, hiding successfully fetched requests. These results and their
errors now update independently. An inbox error no longer looks like an empty queue.
HTTP failures without a JSON detail now identify the resource/status instead of showing
only the generic message. No raw provider error body or credentials are displayed.

Standalone checks reproduce both partial failures and pass; SwiftUI syntax parsing passes.
No iOS build, live database access, deployment or record changes were performed.

## Determine the remaining live server failure

Open Render → CrewCrate API → Logs, then refresh Requests on the phone. Look for the
failed request to `/v1/owner/applications` or `/v1/partners` and its error/traceback.
Do not share connection strings, passwords or access tokens. The actual database/server
failure cannot be established from the screenshot alone.

In Supabase SQL Editor, this read-only query checks required schema without modifying data:

```sql
SELECT
    to_regclass('public.cc_business_applications') IS NOT NULL AS applications_table_exists,
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'cc_partners'
          AND column_name = 'access_approved'
    ) AS approval_column_exists;
```

If the first result is false, apply the business-applications migration. If the second
is false, apply the business-access-gate migration after the first. Do not rerun an
already applied CREATE TABLE/ADD COLUMN migration. See the backend's BUSINESS_APPROVAL_FIX.md.
Both checks should use the same database configured for Render, not an unrelated project.
If both are true, inspect the actual Render traceback rather than assuming a migration issue.

## Commit this iOS correction

```sh
cd /Users/jamesmcdougall/Desktop/Dev/SaltAndLight/CrewCrate/CrewCrate-iOS
git diff
git add CrewCrate/CrewCrate/Services/BusinessApplicationServicing.swift CrewCrate/CrewCrate/ViewModels/BusinessAccessViewModel.swift CrewCrate/CrewCrate/Views/BusinessAccessView.swift Tests/BusinessAccessChecks.swift OWNER_INBOX_DIAGNOSTICS.md
git commit -m "Load owner approval inbox independently of business overview"
git push origin HEAD
```

Build/install the updated iOS app manually. No backend code change was needed for this
client correction. Existing live server issues still require their own diagnosis/fix.
