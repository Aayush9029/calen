import Foundation

public enum DurationParser {
  public static func parse(_ value: String) throws -> TimeInterval {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !trimmed.isEmpty else {
      throw CalenError.invalidInput("Duration cannot be empty.")
    }

    var index = trimmed.startIndex
    var sign = 1.0
    if trimmed[index] == "-" {
      sign = -1
      index = trimmed.index(after: index)
    } else if trimmed[index] == "+" {
      index = trimmed.index(after: index)
    }

    var total = 0.0
    var parsedComponent = false
    while index < trimmed.endIndex {
      let numberStart = index
      var sawDecimal = false
      while index < trimmed.endIndex {
        let character = trimmed[index]
        if character == ".", !sawDecimal {
          sawDecimal = true
          index = trimmed.index(after: index)
        } else if character.isNumber {
          index = trimmed.index(after: index)
        } else {
          break
        }
      }

      guard numberStart != index,
        let number = Double(trimmed[numberStart..<index]),
        index < trimmed.endIndex
      else {
        throw invalidDuration(value)
      }

      let unit = trimmed[index]
      index = trimmed.index(after: index)
      let multiplier: Double
      switch unit {
      case "s": multiplier = 1
      case "m": multiplier = 60
      case "h": multiplier = 3_600
      case "d": multiplier = 86_400
      case "w": multiplier = 604_800
      default: throw invalidDuration(value)
      }
      total += number * multiplier
      parsedComponent = true
    }

    guard parsedComponent, total.isFinite else {
      throw invalidDuration(value)
    }
    return sign * total
  }

  private static func invalidDuration(_ value: String) -> CalenError {
    .invalidInput(
      "Invalid duration “\(value)”. Combine values such as 30m, 1h30m, 2d, or -15m."
    )
  }
}
