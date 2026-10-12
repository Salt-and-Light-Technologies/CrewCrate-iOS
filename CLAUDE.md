# CrewCrate iOS — Fresh start

## Current implementation requirements — October 11, 2026

Use Swift and SwiftUI for the application, with strict MVVM and the Observation framework (`@Observable`, `@Bindable`). Do not introduce Combine, ObservableObject or Published for new application state. Use UIKit only when a required capability cannot reasonably be implemented through SwiftUI/native Swift APIs.

Use async/await for asynchronous operations. Keep UI-facing observable state and updates on MainActor. Put networking, persistence, parsing and expensive processing in injected services with appropriate actor isolation or explicit off-main execution. Async alone does not guarantee CPU work runs off the main actor; do not perform heavy synchronous work in UI tasks or main-actor view models. Do not move all code off-main indiscriminately or introduce detached tasks without a demonstrated need and correct cancellation/lifetime handling.

Design for a first-time, nontechnical user: plain language, clear navigation, large accessible controls, Dynamic Type, VoiceOver labels, readable contrast and useful empty/error/loading states. Each task should have a clear primary action and next step. Use guided upload/mapping/preview flows and progressive disclosure instead of presenting configuration all at once. Keep platform administration separate from business administration and worker experiences, with server-verified roles. Never present a planned or unconnected integration as working.

The accepted product scope and external setup dependencies are recorded in ../PROJECT_TODO.md. Existing instructions to preserve branding and avoid iOS builds remain in effect.

The user subsequently authorized rebuilding the product. Active new work includes
business applications/owner review, campaign list and guided create/edit screens,
file mapping/preview/import, AI practice, campaign contact permission review and business
profile editing. Keep these current implementations; the reset notes below are history.
Worker inbox/assignments and external integrations remain incomplete, and must not be
presented as active until implemented. See IOS_WORKFLOW_SETUP.md for current verification.

The user requested a fresh SwiftUI starter on October 11, 2026. The active app now contains login, account creation and password recovery views, shared authentication styling, and an Observation-based AuthenticationViewModel. Authentication uses injected Supabase services, Keychain session persistence and the backend /v1/me verification endpoint. Recovery callbacks use crewcrate://auth; that redirect must be allowed in Supabase. Standalone service checks use mocks and do not build the iOS app. Prior features and checks are archived outside the target in LegacyReference/BeforeFreshStart-20261011.

Preserve all asset catalog files and images byte for byte, the existing purple CrateMark launch screen, bundle identity and existing archives. Do not restore old features unless requested. Future work uses SwiftUI, strict MVVM, Observation and async/await with views, view-models, models and services in their appropriate folders.

Do not build the iOS application or run Xcode builds. The user builds and tests manually. Provide specific terminal commit/push commands after changes; do not automatically commit or push. Leave the backend and live data unchanged unless separately requested.

## Reset on October 11, 2026

The user requested another reset. Active code now contains only login, account creation, their password recovery support, and a minimal logged-in placeholder with logout. Campaign, account profile, business, contacts, AI practice and deletion screens and their dependencies were removed. Keep all image assets unchanged. Backend and live records were left untouched. Do not restore removed features without a new user request.
