import Foundation

public struct ParsedDate: Equatable, Sendable {
  public let date: Date
  public let isDateOnly: Bool
  public let timeZone: TimeZone

  public init(date: Date, isDateOnly: Bool, timeZone: TimeZone) {
    self.date = date
    self.isDateOnly = isDateOnly
    self.timeZone = timeZone
  }
}

public struct DateParser: Sendable {
  public let timeZone: TimeZone

  public init(timeZone: TimeZone = .current) {
    self.timeZone = timeZone
  }

  public static func timeZone(named value: String?) throws -> TimeZone {
    guard let value, !value.isEmpty, value.lowercased() != "local" else {
      return .current
    }
    guard let timeZone = TimeZone(identifier: value) else {
      throw CalenError.invalidInput(
        "Unknown time zone “\(value)”. Use an IANA name such as America/Edmonton."
      )
    }
    return timeZone
  }

  public func parse(_ value: String, allowDateOnly: Bool = true) throws -> ParsedDate {
    if let date = parseISO8601(value) {
      return ParsedDate(date: date, isDateOnly: false, timeZone: timeZone)
    }

    if allowDateOnly, value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
      return try parseLocal(value, format: "yyyy-MM-dd", dateOnly: true)
    }

    let localPatterns = [
      (#"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$"#, "yyyy-MM-dd'T'HH:mm:ss"),
      (#"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$"#, "yyyy-MM-dd'T'HH:mm"),
      (#"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$"#, "yyyy-MM-dd HH:mm:ss"),
      (#"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$"#, "yyyy-MM-dd HH:mm"),
    ]
    for (pattern, format) in localPatterns
    where value.range(of: pattern, options: .regularExpression) != nil {
      return try parseLocal(value, format: format, dateOnly: false)
    }

    throw CalenError.invalidInput(
      "Invalid date “\(value)”. Use ISO 8601, YYYY-MM-DD, or YYYY-MM-DD HH:MM."
    )
  }

  public func startOfDay(for date: Date) -> Date {
    calendar.startOfDay(for: date)
  }

  public func addingDays(_ days: Int, to date: Date) throws -> Date {
    guard let result = calendar.date(byAdding: .day, value: days, to: date) else {
      throw CalenError.invalidInput("Could not calculate a date \(days) days away.")
    }
    return result
  }

  public var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = timeZone
    return calendar
  }

  private func parseISO8601(_ value: String) -> Date? {
    guard value.contains("T"),
      value.hasSuffix("Z")
        || value.range(of: #"[+-]\d{2}:\d{2}$"#, options: .regularExpression) != nil
    else {
      return nil
    }

    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: value) {
      return date
    }

    let standard = ISO8601DateFormatter()
    standard.formatOptions = [.withInternetDateTime]
    return standard.date(from: value)
  }

  private func parseLocal(_ value: String, format: String, dateOnly: Bool) throws -> ParsedDate {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = format
    formatter.isLenient = false

    guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
      throw CalenError.invalidInput(
        "The local time “\(value)” does not exist or is invalid in \(timeZone.identifier)."
      )
    }
    return ParsedDate(date: date, isDateOnly: dateOnly, timeZone: timeZone)
  }
}

public enum DateComponentsConverter {
  public static func components(from parsed: ParsedDate) -> DateComponents {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = parsed.timeZone
    let units: Set<Calendar.Component> =
      parsed.isDateOnly
      ? [.year, .month, .day]
      : [.year, .month, .day, .hour, .minute, .second]
    var components = calendar.dateComponents(units, from: parsed.date)
    components.calendar = calendar
    components.timeZone = parsed.timeZone
    return components
  }

  public static func date(from components: DateComponents?) -> Date? {
    guard let components else {
      return nil
    }
    if let date = components.date {
      return date
    }
    var calendar = components.calendar ?? Calendar(identifier: .gregorian)
    if let timeZone = components.timeZone {
      calendar.timeZone = timeZone
    }
    return calendar.date(from: components)
  }

  public static func isDateOnly(_ components: DateComponents?) -> Bool {
    guard let components else {
      return false
    }
    return components.hour == nil && components.minute == nil && components.second == nil
  }
}
