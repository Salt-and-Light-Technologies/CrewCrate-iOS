import Foundation

protocol DraftStore: Sendable {
    func load() async throws -> OnboardingDraft?
    func save(_ draft: OnboardingDraft) async throws
}

actor FileDraftStore: DraftStore {
    private let fileURL: URL
    init(fileURL: URL) { self.fileURL = fileURL }
    static func applicationStore() -> FileDraftStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return FileDraftStore(fileURL: base.appendingPathComponent("CrewCrate/Onboarding/draft-v1.json"))
    }
    func load() async throws -> OnboardingDraft? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let draft = try JSONDecoder().decode(OnboardingDraft.self, from: Data(contentsOf: fileURL))
        guard draft.schemaVersion == 1 else { throw DraftStoreError.unsupportedVersion }
        return draft
    }
    func save(_ draft: OnboardingDraft) async throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(draft)
        #if os(iOS)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: fileURL, options: .atomic)
        #endif
    }
}
nonisolated enum DraftStoreError: LocalizedError {
    case unsupportedVersion
    var errorDescription: String? { "This draft was saved by a different app version. It has not been overwritten." }
}
actor MemoryDraftStore: DraftStore {
    private var draft: OnboardingDraft?
    init(draft: OnboardingDraft? = nil) { self.draft = draft }
    func load() async throws -> OnboardingDraft? { draft }
    func save(_ draft: OnboardingDraft) async throws { self.draft = draft }
}
