import Foundation

public enum CSVError: Error, LocalizedError {
    case invalid(String)
    public var errorDescription: String? { switch self { case .invalid(let message): message } }
}
public enum CSVImporter {
    public static func parse(_ text: String) throws -> [[String]] {
        let chars = Array(text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text)
        var rows: [[String]] = [], row: [String] = [], cell = "", quoted = false, closed = false, i = 0
        func finishRow() {
            row.append(cell); cell = ""
            if row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { rows.append(row) }
            row = []; closed = false
        }
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { cell.append("\""); i += 1 }
                    else { quoted = false; closed = true }
                } else { cell.append(c) }
            } else if c == "\"", cell.isEmpty, !closed { quoted = true }
            else if c == "," { row.append(cell); cell = ""; closed = false }
            else if c == "\n" || c == "\r" || c == "\r\n" {
                if c == "\r", i + 1 < chars.count, chars[i + 1] == "\n" { i += 1 }
                finishRow()
            } else {
                if c == "\"" || (closed && !c.isWhitespace) { throw CSVError.invalid("Unexpected text or quote in CSV cell.") }
                cell.append(c)
            }
            i += 1
        }
        guard !quoted else { throw CSVError.invalid("A quoted CSV cell is not closed.") }
        finishRow(); return rows
    }
    public static func medications(from text: String) throws -> [Medication] {
        guard text.utf8.count <= 200_000 else { throw CSVError.invalid("Use a CSV smaller than 200 KB.") }
        let rows = try parse(text)
        guard rows.count >= 2, rows.count <= 21 else { throw CSVError.invalid("Use a header and 1–20 medication rows.") }
        let header = rows[0].map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard header.allSatisfy({ !$0.isEmpty }), Set(header).count == header.count,
              header.contains("medication name"), header.contains("details") else {
            throw CSVError.invalid("Use unique, nonempty headers including Medication Name and Details.")
        }
        return try rows.dropFirst().enumerated().map { index, row in
            guard row.count == header.count else { throw CSVError.invalid("Row \(index + 2) has the wrong number of fields.") }
            let values = Dictionary(uniqueKeysWithValues: zip(header, row))
            func field(_ key: String) -> String { values[key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines) }
            let name = field("medication name"), details = field("details"), lower = details.lowercased()
            let status = field("task status").lowercased()
            let cancelled = status.contains("cancelled") || status.contains("canceled") || status.contains("discontinued")
            let unsupported = !lower.hasPrefix("po,") || !name.lowercased().contains("tablet") || matches("prn|as needed|every\\s+\\d+\\s*hours?|week|taper|alternate", in: lower)
            let reason: String? = cancelled ? "Cancelled order" : unsupported ? "Outside oral whole-tablet daily scope" : nil
            let dose = mass(in: details), strength = mass(in: field("strength"))
            var periods: Set<DayPeriod> = []
            if lower.contains("every morning") { periods.insert(.morning) }
            if lower.contains("every afternoon") { periods.insert(.afternoon) }
            if lower.contains("every evening") { periods.insert(.evening) }
            if lower.contains("at bedtime") { periods.insert(.bedtime) }
            var directions = field("instructions")
            if lower.contains("with meal") { directions += directions.isEmpty ? "With a meal" : "; with a meal" }
            return Medication(code: String(UnicodeScalar(65 + index)!), name: name, doseMG: dose, strengthMG: strength, periods: periods, directions: directions, sourceDetails: details, sourceRow: index + 2, included: reason == nil, exclusionReason: reason)
        }
    }
    private static func matches(_ pattern: String, in text: String) -> Bool { text.range(of: pattern, options: .regularExpression) != nil }
    private static func mass(in text: String) -> Double {
        let pattern = "(?i)([0-9]+(?:\\.[0-9]+)?)\\s*(mcg|mg|g)\\b"
        guard let expression = try? NSRegularExpression(pattern: pattern), let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let numberRange = Range(match.range(at: 1), in: text), let unitRange = Range(match.range(at: 2), in: text), let number = Double(text[numberRange]) else { return 0 }
        let unit = text[unitRange].lowercased()
        return number * (unit == "g" ? 1000 : unit == "mcg" ? 0.001 : 1)
    }
}
