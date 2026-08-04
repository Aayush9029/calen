import Foundation

public enum RecurrenceFrequency: String, Codable, CaseIterable, Sendable {
  case daily
  case weekly
  case monthly
  case yearly
}

public enum Weekday: String, Codable, CaseIterable, Sendable {
  case sunday = "sun"
  case monday = "mon"
  case tuesday = "tue"
  case wednesday = "wed"
  case thursday = "thu"
  case friday = "fri"
  case saturday = "sat"
}

public struct WeekdaySpec: Codable, Equatable, Sendable {
  public let weekday: Weekday
  public let weekNumber: Int

  public init(weekday: Weekday, weekNumber: Int = 0) {
    self.weekday = weekday
    self.weekNumber = weekNumber
  }
}

public enum RecurrenceEndSpec: Equatable, Sendable {
  case date(Date)
  case count(Int)
}

public struct RecurrenceSpec: Equatable, Sendable {
  public let frequency: RecurrenceFrequency
  public let interval: Int
  public let daysOfWeek: [WeekdaySpec]
  public let daysOfMonth: [Int]
  public let monthsOfYear: [Int]
  public let weeksOfYear: [Int]
  public let daysOfYear: [Int]
  public let setPositions: [Int]
  public let end: RecurrenceEndSpec?

  public init(
    frequency: RecurrenceFrequency,
    interval: Int = 1,
    daysOfWeek: [WeekdaySpec] = [],
    daysOfMonth: [Int] = [],
    monthsOfYear: [Int] = [],
    weeksOfYear: [Int] = [],
    daysOfYear: [Int] = [],
    setPositions: [Int] = [],
    end: RecurrenceEndSpec? = nil
  ) throws {
    guard interval > 0 else {
      throw CalenError.invalidInput("Recurrence interval must be greater than zero.")
    }
    try Self.validate(daysOfMonth, range: -31...31, name: "month day")
    try Self.validate(monthsOfYear, range: 1...12, name: "month")
    try Self.validate(weeksOfYear, range: -53...53, name: "week of year")
    try Self.validate(daysOfYear, range: -366...366, name: "day of year")
    try Self.validate(setPositions, range: -366...366, name: "set position")
    for weekday in daysOfWeek where !(-53...53).contains(weekday.weekNumber) {
      throw CalenError.invalidInput("Weekday ordinal must be between -53 and 53.")
    }
    if case .count(let count) = end, count <= 0 {
      throw CalenError.invalidInput("Recurrence count must be greater than zero.")
    }

    self.frequency = frequency
    self.interval = interval
    self.daysOfWeek = daysOfWeek
    self.daysOfMonth = daysOfMonth
    self.monthsOfYear = monthsOfYear
    self.weeksOfYear = weeksOfYear
    self.daysOfYear = daysOfYear
    self.setPositions = setPositions
    self.end = end
  }

  private static func validate(
    _ values: [Int],
    range: ClosedRange<Int>,
    name: String
  ) throws {
    for value in values where value == 0 || !range.contains(value) {
      throw CalenError.invalidInput(
        "Recurrence \(name) \(value) is outside the allowed range and cannot be zero."
      )
    }
  }
}

public enum RecurrenceParser {
  public static func weekdays(_ value: String?) throws -> [WeekdaySpec] {
    guard let value, !value.isEmpty else {
      return []
    }
    return try value.split(separator: ",").map { token in
      let raw = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      guard let suffix = Weekday.allCases.first(where: { raw.hasSuffix($0.rawValue) }) else {
        throw CalenError.invalidInput(
          "Invalid weekday “\(token)”. Use sun, mon, tue, wed, thu, fri, or sat."
        )
      }
      let prefix = String(raw.dropLast(suffix.rawValue.count))
      let ordinal: Int
      if prefix.isEmpty {
        ordinal = 0
      } else if let parsed = Int(prefix), parsed != 0 {
        ordinal = parsed
      } else {
        throw CalenError.invalidInput(
          "Invalid weekday ordinal “\(token)”. Examples include mon, 2tue, and -1fri."
        )
      }
      return WeekdaySpec(weekday: suffix, weekNumber: ordinal)
    }
  }

  public static func integers(_ value: String?, name: String) throws -> [Int] {
    guard let value, !value.isEmpty else {
      return []
    }
    return try value.split(separator: ",").map { token in
      guard let integer = Int(token.trimmingCharacters(in: .whitespacesAndNewlines)) else {
        throw CalenError.invalidInput("Invalid \(name) value “\(token)”.")
      }
      return integer
    }
  }
}
