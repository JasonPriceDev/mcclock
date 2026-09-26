import Foundation
import Testing
@testable import McClock

struct ClockFormatterTests {
    @Test func timeRespectsSecondsSetting() {
        let date = Date(timeIntervalSince1970: 1_700_000_045)
        let locale = Locale(identifier: "en_US_POSIX")
        let zone = TimeZone(secondsFromGMT: 0)!
        let short = ClockFormatter.time(at: date, includeSeconds: false, locale: locale, timeZone: zone)
        let long = ClockFormatter.time(at: date, includeSeconds: true, locale: locale, timeZone: zone)
        #expect(!short.contains(":05"))
        #expect(long.contains(":05"))
    }

    @Test func timeUsesProvidedTimeZone() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let locale = Locale(identifier: "en_US_POSIX")
        let utc = ClockFormatter.time(at: date, includeSeconds: false,
                                      locale: locale, timeZone: TimeZone(secondsFromGMT: 0)!)
        let east = ClockFormatter.time(at: date, includeSeconds: false,
                                       locale: locale, timeZone: TimeZone(secondsFromGMT: 3600)!)
        #expect(utc != east)
    }

    @Test func dateIsISO8601InLocalTimeZone() {
        let instant = Date(timeIntervalSince1970: 1_700_000_000)
        let utc = ClockFormatter.date(at: instant, timeZone: TimeZone(secondsFromGMT: 0)!)
        let plusTwo = ClockFormatter.date(at: instant, timeZone: TimeZone(secondsFromGMT: 7_200)!)
        #expect(utc == "2023-11-14")
        #expect(plusTwo == "2023-11-15")
    }
}
