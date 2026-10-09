import Foundation

extension APILeadRepository: PartnerSetupRepository {
    func identity() async throws -> LiveIdentity { try JSONDecoder().decode(LiveIdentity.self, from: await request("v1/me")) }
    func setupPartners() async throws -> [LivePartner] {
        var result: [LivePartner] = []; var offset = 0
        while true {
            let data = try await request("v1/partners", query: [URLQueryItem(name: "limit", value: "50"), URLQueryItem(name: "offset", value: String(offset))])
            let page = try JSONDecoder().decode([LivePartner].self, from: data); result += page
            if page.count < 50 { return result }; offset += 50
        }
    }
}
