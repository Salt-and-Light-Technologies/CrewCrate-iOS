import Foundation

nonisolated struct BusinessProfileFields: Codable, Sendable, Equatable {
    var business_name = ""
    var website = ""
    var industry = ""
    var services = ""
    var service_area = ""
    var time_zone = "America/Chicago"
    var ai_boundaries = ""
}
nonisolated struct BusinessProfileRecord: Decodable, Sendable {
    let id: UUID
    let revision: Int
    let onboarding: BusinessProfileFields
}
