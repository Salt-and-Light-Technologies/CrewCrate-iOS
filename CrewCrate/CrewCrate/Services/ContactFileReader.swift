import Foundation

nonisolated enum ContactFileReader {
    static func read(_ url: URL) async throws -> ContactFile {
        try await Task.detached {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard ["csv", "tsv", "xlsx"].contains(url.pathExtension.lowercased()) else {
                throw AuthenticationFailure(message: "Choose CSV, TSV or Excel .xlsx. Export Google Sheets or Numbers first.")
            }
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: 5_000_001) ?? Data()
            guard !data.isEmpty, data.count <= 5_000_000 else {
                throw AuthenticationFailure(message: "Choose a nonempty file smaller than 5 MB.")
            }
            return ContactFile(name: url.lastPathComponent, data: data)
        }.value
    }
}
