import Foundation

nonisolated protocol LeadFileInspecting: Sendable {
    func inspect(_ url: URL) async throws -> CSVDocument
}
