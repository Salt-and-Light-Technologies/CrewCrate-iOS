import Foundation

nonisolated enum CRMProvider: String, CaseIterable, Identifiable, Sendable {
    case notSelected = ""
    case crewcrate = "CrewCrate"
    case salesforce = "Salesforce"
    case hubspot = "HubSpot"
    case zoho = "Zoho CRM"
    case pipedrive = "Pipedrive"
    case dynamics = "Microsoft Dynamics 365"
    case monday = "monday CRM"
    case freshsales = "Freshsales"
    case highlevel = "HighLevel"
    case other = "Other CRM"

    var id: String { rawValue }
    var title: String { self == .notSelected ? "Choose a CRM" : rawValue }
    var storedName: String { self == .other ? "Other: " : rawValue }
    static func selection(for name: String) -> CRMProvider {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return .notSelected }
        return CRMProvider(rawValue: value) ?? .other
    }
    static func customName(from name: String) -> String {
        name.hasPrefix("Other: ") ? String(name.dropFirst(7)) : name
    }
}
