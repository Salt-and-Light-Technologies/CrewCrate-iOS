# CrewCrate iOS — Session Memory

## Project

- Native SwiftUI CRM application in `CrewCrate/CrewCrate`.
- App target: `CrewCrate`.
- The target deployment setting is iOS 18.0.
- The project uses Xcode filesystem-synchronized groups, so Swift source files added under the app folder are included automatically.

## Current Architecture

- SwiftUI with `NavigationStack`, `TabView`, Swift Concurrency-compatible code, and SwiftData local persistence.
- Data models are declared in `CrewCrate/CrewCrate/Models.swift`.
- SwiftData models: `Client`, `ActivityRecord`, `Appointment`, `CRMNote`, `CRMTask`, `FinancialDocument`, `LineItem`, and `MediaAttachment`.
- `CRMService` and `LocalCRMService` establish a seam for the future FastAPI backend.
- `CrewCrateApp.swift` owns the shared `ModelContainer`.
- `SeedData.installIfNeeded` creates Ava Mitchell, Eli Rodriguez, Ava’s $2,400 invoice, Eli’s open estimate, a Kitchen walkthrough appointment, a task, and their initial activity records.

## Primary Screens

- Dashboard, Clients, Activity, Calendar, and More tabs are defined in `ContentView.swift`.
- Dashboard: Today’s Schedule, Outstanding Invoices, Open Estimates, Recent Activity, and quick actions.
- Client search, favorites filter, name sort, add, edit, and delete are supported.
- Client profiles show contact information, quick actions, media, estimates/invoices, tasks, and unified activity.
- Calendar supports a graphical day selector and appointment creation, editing, and deletion.

## Quick Actions

`QuickAction` currently includes:

- Client
- Estimate
- Invoice
- Appointment
- Note
- Task
- Media

Dashboard shows all actions. Client profiles show all except Client, and automatically attach newly created items to the currently open client.

## CRUD and Cross-Screen Behavior

- Clients: create, edit, delete, favorite.
- Appointments: create from quick actions/calendar; edit by tapping, long-pressing, or swiping on Calendar; delete via Calendar.
- Calendar updates mutate the same `Appointment` model shown on Dashboard and client profiles.
- Appointment activity records use `relatedAppointmentID` so edits update, and deletion removes, the linked activity timeline entry. Fallback matching exists for older seeded records.
- Notes, tasks, estimates, invoices, and media are created locally and associated with a selected client.
- Estimates/invoices use persistent `LineItem` records and calculate document totals.
- Tasks can be toggled complete from the client profile and log activity.

## Media

- `CameraCapturePicker.swift` wraps `UIImagePickerController`.
- Media quick action supports **Take Photo or Video** and **Choose from Library**.
- The camera/library interface is shown with `fullScreenCover`, never in a small sheet.
- Simulator camera requests fall back to photo library.
- Captured media is stored as external SwiftData `Data` in `MediaAttachment` and appears on the associated client profile.
- Camera, microphone, and photo-library usage descriptions were added to both target configurations in `project.pbxproj`.

## Client Profile Photos

- `Client.profileImageData` persists a profile image as external storage.
- The profile avatar camera badge opens actions to take a photo, choose from library, or remove the current photo.
- Profile photos accept images only; videos remain regular client media attachments.
- `ClientAvatar` in `Components.swift` displays the saved photo or falls back to client initials.

## Visual Design Decisions

- Uses a light/dark adaptive glass style via `glassCard()` and `AppBackground()` in `Components.swift`.
- Dashboard quick actions are three-column, floating glass cards.
- Activity status badges are color-coded.
- Recent Activity uses fixed device-local timestamps (`7:30 AM` style), not changing relative timers.
- Calendar event rows use one local time string (`10:00 AM` style), avoiding split hour/minute rendering.
- Tab icons are intended to use outline symbols when inactive and filled versions when selected. The tab view also sets `.environment(\.symbolVariants, .none)` to suppress the system’s automatic filled variant.

## Brand Asset

- Dashboard header uses `Image("CrateMark")`, a transparent extraction of the crate mark from the existing app icon.
- Asset catalog location: `CrewCrate/CrewCrate/Assets.xcassets/CrateMark.imageset`.
- Correctly mapped variants:
  - `CrateMark-1x.png` — 256 × 256
  - `CrateMark-2x.png` — 512 × 512
  - `CrateMark-3x.png` — 768 × 768
- `Contents.json` maps the above files to their matching 1×, 2×, and 3× universal slots. Do not re-add the removed legacy `CrateMark.png`, as it created an unassigned-asset warning.

## Key Files

- `CrewCrate/CrewCrate/ContentView.swift` — root tabs, Dashboard, Clients, Activity, Calendar, More.
- `CrewCrate/CrewCrate/Models.swift` — SwiftData domain models and service protocol.
- `CrewCrate/CrewCrate/Components.swift` — reusable cards, badges, rows, visual helpers, client avatar/media previews.
- `CrewCrate/CrewCrate/FormsAndSeed.swift` — quick-create forms, activity logging, appointment editor, seed data.
- `CrewCrate/CrewCrate/ClientProfileView.swift` — profile UI, quick actions, profile-photo controls.
- `CrewCrate/CrewCrate/CameraCapturePicker.swift` — camera/photo-library capture wrapper.
- `CrewCrate/CrewCrate/CrewCrateApp.swift` — app entry and SwiftData container.

## Verification Note

- This environment’s active developer directory is Command Line Tools rather than a full Xcode toolchain, so command-line simulator builds have not been run here. Validate with a clean Xcode build after substantial model/schema changes.
