import Foundation

enum ClockFormatter {
    static func time(
        at date: Date,
        includeSeconds: Bool,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.timeStyle = includeSeconds ? .medium : .short
        return formatter.string(from: date)
    }

    static func date(
        at date: Date,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
}
