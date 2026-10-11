import Foundation

nonisolated enum LeadStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case unreviewed, eligible, excluded
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
nonisolated struct LeadRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let importID: UUID
    let name: String
    let phone: String
    let email: String
    var status: LeadStatus = .unreviewed
    var revision = 0
    var smsPermission = "unknown"
    var permissionEvidence = ""
    var optedOut = false
}
nonisolated struct LeadImportBatch: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let fileName: String
    let totalRows: Int
    let imported: Int
    let duplicates: Int
    let invalid: Int
    let timestamp: Date
}
nonisolated struct LeadActivity: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let action: String
    let actorName: String
    let detail: String
    let timestamp: Date
}
nonisolated struct LeadWorkspaceSummary: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let status: PartnerStatus
    let revision: Int
    let totalLeads: Int
    let importCount: Int
    let counts: [LeadStatus: Int]
    var canImport: Bool { status != .paused }
}
nonisolated struct LeadColumnMapping: Equatable, Sendable {
    var phone = 0
    var name: Int?
    var email: Int?
}
nonisolated struct LeadImportIssue: Identifiable, Codable, Equatable, Sendable {
    let rowNumber: Int
    let kind: String
    let detail: String
    var id: String { "\(rowNumber)-\(kind)" }
}
nonisolated struct LeadImportPreview: Equatable, Sendable {
    let partnerRevision: Int
    let totalRows: Int
    let imported: Int
    let duplicates: Int
    let invalid: Int
    let issues: [LeadImportIssue]
    let issuesTruncated: Bool
}
nonisolated enum LeadRepositoryError: LocalizedError {
    case missing, conflict, invalidMapping, locked, invalidContact
    var errorDescription: String? {
        switch self {
        case .missing: "This record is no longer available. Refresh the workspace."
        case .conflict: "The workspace changed. Refresh and preview the file again before importing."
        case .invalidMapping: "Choose distinct phone, name and email columns."
        case .locked: "CSV uploads and lead changes are unavailable while the partner is paused."
        case .invalidContact: "The file has no new valid contacts to import."
        }
    }
}
nonisolated enum LeadImportAnalyzer {
    static func analyze(_ document: CSVDocument, mapping: LeadColumnMapping, existing: Set<String>, revision: Int) throws -> (LeadImportPreview, [(String, String, String)]) {
        let indices = [Optional(mapping.phone), mapping.name, mapping.email].compactMap { $0 }
        guard indices.allSatisfy(document.headers.indices.contains), Set(indices).count == indices.count else { throw LeadRepositoryError.invalidMapping }
        var seen = existing, contacts: [(String, String, String)] = [], issues: [LeadImportIssue] = []
        var duplicates = 0, invalid = 0
        for (index, row) in document.rows.enumerated() {
            guard row.count == document.headers.count else { throw CSVError.malformed }
            let original = row[mapping.phone].trimmingCharacters(in: .whitespacesAndNewlines)
            let phone = original.filter { $0.isASCII && $0.isNumber }
            let allowed = original.allSatisfy { ($0.isASCII && $0.isNumber) || "+(). -".contains($0) }
            let name = mapping.name.map { row[$0].trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
            let email = mapping.email.map { row[$0].trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
            guard allowed, (7...15).contains(phone.count), name.count <= 200, email.count <= 320, email.isEmpty || OnboardingValidation.email(email) else {
                invalid += 1; issues.append(LeadImportIssue(rowNumber: index + 1, kind: "invalid", detail: "Check phone, email or field length")); continue
            }
            if !seen.insert(phone).inserted {
                duplicates += 1; issues.append(LeadImportIssue(rowNumber: index + 1, kind: "duplicate", detail: "Phone already appears in this list or partner workspace"))
            } else { contacts.append((name, phone, email)) }
        }
        return (LeadImportPreview(partnerRevision: revision, totalRows: document.rows.count, imported: contacts.count, duplicates: duplicates, invalid: invalid, issues: Array(issues.prefix(100)), issuesTruncated: issues.count > 100), contacts)
    }
}
