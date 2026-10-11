# CrewCrate iOS — Fresh start

The user requested a fresh SwiftUI starter on October 11, 2026. The active app now contains login, account creation and password recovery views, shared authentication styling, and an Observation-based AuthenticationViewModel. Authentication uses injected Supabase services, Keychain session persistence and the backend /v1/me verification endpoint. Recovery callbacks use crewcrate://auth; that redirect must be allowed in Supabase. Standalone service checks use mocks and do not build the iOS app. Prior features and checks are archived outside the target in LegacyReference/BeforeFreshStart-20261011.

Preserve all asset catalog files and images byte for byte, the existing purple CrateMark launch screen, bundle identity and existing archives. Do not restore old features unless requested. Future work uses SwiftUI, strict MVVM, Observation and async/await with views, view-models, models and services in their appropriate folders.

Do not build the iOS application or run Xcode builds. The user builds and tests manually. Provide specific terminal commit/push commands after changes; do not automatically commit or push. Leave the backend and live data unchanged unless separately requested.
