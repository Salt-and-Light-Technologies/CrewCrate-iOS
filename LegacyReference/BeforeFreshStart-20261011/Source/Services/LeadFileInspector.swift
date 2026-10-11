import Foundation

nonisolated enum CSVError: LocalizedError {
    case tooLarge, encoding, malformed, empty, invalidHeaders, column
    var errorDescription: String? {
        switch self {
        case .tooLarge: "Use a CSV smaller than 5 MB with no more than 20,000 records."
        case .encoding: "Export this list as a UTF-8 CSV file."
        case .malformed: "The CSV contains invalid quoting or inconsistent column counts."
        case .empty: "This CSV needs a header row and at least one contact."
        case .invalidHeaders: "Each CSV column needs a unique, nonempty header."
        case .column: "Choose a phone-number column."
        }
    }
}
nonisolated enum CSVParser {
    static func parse(data: Data, fileName: String) throws -> CSVDocument {
        guard data.count <= 5_000_000 else { throw CSVError.tooLarge }
        guard var text = String(data: data, encoding: .utf8) else { throw CSVError.encoding }
        if text.first == "\u{FEFF}" { text.removeFirst() }
        // Treat CRLF and bare CR as row breaks; preserve line breaks within quoted fields.
        text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var rows: [[String]] = [], row: [String] = [], field = ""
        var quoted = false, afterQuote = false
        let chars = Array(text)
        var index = 0
        func appendRow() {
            row.append(field); field = ""
            if row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { rows.append(row) }
            row = []
        }
        while index < chars.count {
            let char = chars[index]
            if quoted {
                if char == "\"" {
                    if index + 1 < chars.count && chars[index + 1] == "\"" { field.append("\""); index += 1 }
                    else { quoted = false; afterQuote = true }
                } else { field.append(char) }
            } else if afterQuote {
                if char == "," { row.append(field); field = ""; afterQuote = false }
                else if char == "\n" { appendRow(); afterQuote = false }
                else { throw CSVError.malformed }
            } else {
                switch char {
                case "\"":
                    guard field.isEmpty else { throw CSVError.malformed }
                    quoted = true
                case ",": row.append(field); field = ""
                case "\n": appendRow()
                default: field.append(char)
                }
            }
            index += 1
            if rows.count > 20_001 { throw CSVError.tooLarge }
        }
        guard !quoted else { throw CSVError.malformed }
        if !field.isEmpty || !row.isEmpty || afterQuote { appendRow() }
        guard rows.count >= 2 else { throw CSVError.empty }
        let headers = rows.removeFirst().map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !headers.contains(""), Set(headers.map { $0.lowercased() }).count == headers.count else { throw CSVError.invalidHeaders }
        guard rows.count <= 20_000 else { throw CSVError.tooLarge }
        guard rows.allSatisfy({ $0.count == headers.count }) else { throw CSVError.malformed }
        return CSVDocument(fileName: fileName, headers: headers, rows: rows)
    }
    static func summarize(_ document: CSVDocument, phoneIndex: Int) throws -> ImportSummary {
        guard document.headers.indices.contains(phoneIndex) else { throw CSVError.column }
        var seen: Set<String> = [], invalid = 0, duplicate = 0
        for row in document.rows {
            let phone = row[phoneIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let digits = phone.filter { $0.isASCII && $0.isNumber }
            let allowed = phone.allSatisfy { ($0.isASCII && $0.isNumber) || "+()- .".contains($0) }
            guard allowed, (7...15).contains(digits.count) else { invalid += 1; continue }
            if !seen.insert(digits).inserted { duplicate += 1 }
        }
        return ImportSummary(fileName: document.fileName, totalRows: document.rows.count, validContacts: seen.count, duplicateContacts: duplicate, invalidContacts: invalid, phoneColumn: document.headers[phoneIndex])
    }
}
actor LeadFileInspector: LeadFileInspecting {
    func inspect(_ url: URL) async throws -> CSVDocument {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 5_000_000 else { throw CSVError.tooLarge }
        return try CSVParser.parse(data: Data(contentsOf: url), fileName: url.lastPathComponent)
    }
}
