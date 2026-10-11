import Foundation

nonisolated enum LeadAPIError: LocalizedError {
    case configuration, signIn, forbidden, conflict, tooLarge, invalidResponse, server(String)
    var errorDescription: String? {
        switch self {
        case .configuration: "A secure CrewCrate API URL is required."
        case .signIn: "Your session needs sign-in again."
        case .forbidden: "Your account cannot perform this action."
        case .conflict: "The record changed or its status prevents this action. Refresh and preview again."
        case .tooLarge: "Use a CSV smaller than 5 MB."
        case .invalidResponse: "The API response was not recognized. Refresh before retrying."
        case .server(let message): message
        }
    }
}
