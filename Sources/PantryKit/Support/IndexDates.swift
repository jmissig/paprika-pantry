import Foundation

enum MealHistoryDateSupport {
    static func parsedDate(from value: String) -> Date? {
        formatter().date(from: value)
    }

    static func dayDistance(from earlier: Date, to later: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let earlierDay = calendar.startOfDay(for: earlier)
        let laterDay = calendar.startOfDay(for: later)
        return calendar.dateComponents([.day], from: earlierDay, to: laterDay).day ?? 0
    }

    private static func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }
}

enum DatabaseTimestamp {
    static func encode(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    static func decode(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }

        return decodeRequired(value)
    }

    static func decodeRequired(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
            ?? ISO8601DateFormatter().date(from: value)
            ?? Date(timeIntervalSince1970: 0)
    }
}
