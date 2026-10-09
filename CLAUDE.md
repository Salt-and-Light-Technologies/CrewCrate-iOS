# CrewCrate — Current Project State

CrewCrate was reset on October 8, 2026. The active app now implements universal partner onboarding and an owner review demo locally.

## Required architecture

Use SwiftUI, strict MVVM, Observation (`@Observable`/`@Bindable`) and async/await. Do not introduce Combine for state. UIKit is permitted only for a necessary older-framework integration; none is currently used. Keep data/file operations in injected services and workflow logic in view models.

## Source

Models/OnboardingDraft.swift defines setup data and validation. ViewModels/OnboardingViewModel.swift owns main-actor workflow state. Services provide actor-backed persistence and CSV inspection. Views render the seven steps. CrewCrateApp is the composition root. Read README.md for behavior and checks.

## Integration boundary

Setup is local, not authenticated or server-submitted. No invitations, lead uploads, messaging, reporting integrations or binding agreements exist yet. Never display locally prepared setup as owner-approved. No old CRM stores should be opened or erased.

## Protected branding

Preserve all Assets.xcassets files byte for byte, the CrewCrate name and bundle identity. Do not restore the archived contractor CRM. Add future features incrementally with clear explanations for the owner.

## Owner review demo

PartnerWorkspace models, PartnerRepository async service, and observable dashboard/review view models power the Owner demo tab. All owner records and decisions are explicitly sample data and reset on restart. Partner drafts do not submit to the sample list. Preserve approval gates, required decision reasons, revision conflict checks and history. Backend/JWT work is deferred. A real adapter must enforce authorization and isolation on the server.

## Lead workspaces

LeadWorkspace models, the async LeadRepository contract, observable list/detail models, SwiftUI views and APILeadRepository now exist. One shared DemoPartnerRepository powers owner/lead state in-memory. Importing changes the shared partner revision and clears attestations; classify with lead revision, honor paused partners, and require a separate preview and commit. Keep mapping changes invalidating previews. The demo is clearly labeled and resets on restart. Never silently connect local demo contacts or local onboarding drafts to real accounts. HTTP adapter is implemented but live auth/configuration remain deferred. Keep tokens out of logs/files and use the injected session provider. Read README.md and run all affected standalone checks.

## Campaign boundary

Campaign planning, recorded SMS permission/opt-out controls, partner self-service preparation, owner oversight and manual follow-up tracking now exist. Do not introduce mandatory owner approval for every campaign. Existing partner setup gates remain separate. Shared demo state includes an explicitly sample approved partner. No SMS delivery, inbound replies, scheduler or revenue verification exists. Ready to connect is never launched/delivered. Backend owner holds cannot be released by partner users. Keep evidence/revision checks, opt-out suppression, preparation invalidation and unsaved-edit protection. Provider integration must enforce dispatch-time checks rather than flipping a capability flag. Run CampaignChecks and existing affected checks before handoff.

## Live authentication connection

The composition root now selects LiveAppView / SessionViewModel. SupabaseSession provides async sign-in, refresh coalescing, Keychain persistence and local-scope sign-out. APILeadRepository uses the supplied Render URL; server /v1/me determines owner status. LiveOnboardingStore maps server drafts and submits with expected revisions. Keep demo previews separate and never automatically migrate local drafts. Owner overview remains hidden. Accounts without provisioned memberships show an empty state. Invite acceptance and password recovery are not yet implemented. Preserve public-only client configuration and run AuthChecks and existing checks after relevant changes.

## Partner home redesign

The live root is now first-login onboarding then Analytics/Account only. PartnerExperienceViewModel routes by server status; completing onboarding reloads that status. Do not reintroduce partner setup, leads or campaigns tabs. Preserve Account and hidden owner source. PartnerHomeViewModel measures existing campaign memberships and manual tracking records only. Do not represent manual closed statuses as verified sales or unavailable messaging/revenue as measured zero. No workspace assignment and server errors are blocking states. Run PartnerHomeChecks and affected auth/onboarding checks.

## MVVM ownership and source placement

Read ARCHITECTURE.md. App/AppDependencies.swift is the live composition root. Views/ContentView.swift only selects screens. Keep each primary screen/view-model in its matching folder/file. Domain data belongs under Models; public endpoint settings under Configuration. View-models use Observation/main actor and injected async protocols/factories, never direct networking or persistence. OnboardingViewModel emits the submitted completion action and PartnerExperienceViewModel reloads server status; do not move that workflow into the view. CampaignAnalyticsService owns network pagination. Preserve all owner source and brand assets. Compile standalone checks with Models, Services, ViewModels and Configuration; run MVVMChecks plus affected suites.
