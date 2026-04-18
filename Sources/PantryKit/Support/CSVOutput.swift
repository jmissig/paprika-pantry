import Foundation

public enum CSVOutput {
    public static func render(headers: [String], rows: [[String]]) -> String {
        var lines = [encodeRow(headers)]
        lines.reserveCapacity(rows.count + 1)

        for row in rows {
            lines.append(encodeRow(row))
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func encodeRow(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") else {
            return field
        }

        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
