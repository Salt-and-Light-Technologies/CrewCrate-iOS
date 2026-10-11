import Foundation

nonisolated struct CSVDocument: Sendable {
    let fileName: String
    let headers: [String]
    let rows: [[String]]
}
