import CoreGraphics
import Foundation

public struct CalendarColor: Equatable, Sendable {
  public let red: Double
  public let green: Double
  public let blue: Double
  public let alpha: Double

  public init(red: Double, green: Double, blue: Double, alpha: Double = 1) throws {
    for component in [red, green, blue, alpha] where !(0...1).contains(component) {
      throw CalenError.invalidInput("Color components must be between 0 and 1.")
    }
    self.red = red
    self.green = green
    self.blue = blue
    self.alpha = alpha
  }

  public init(hex value: String) throws {
    var raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if raw.hasPrefix("#") {
      raw.removeFirst()
    }
    guard raw.count == 6 || raw.count == 8,
      let integer = UInt64(raw, radix: 16)
    else {
      throw CalenError.invalidInput(
        "Invalid color “\(value)”. Use #RRGGBB or #RRGGBBAA."
      )
    }

    let hasAlpha = raw.count == 8
    let redShift = hasAlpha ? 24 : 16
    let greenShift = hasAlpha ? 16 : 8
    let blueShift = hasAlpha ? 8 : 0
    self.red = Double((integer >> redShift) & 0xFF) / 255
    self.green = Double((integer >> greenShift) & 0xFF) / 255
    self.blue = Double((integer >> blueShift) & 0xFF) / 255
    self.alpha = hasAlpha ? Double(integer & 0xFF) / 255 : 1
  }

  public init?(cgColor: CGColor?) {
    guard let cgColor,
      let converted = cgColor.converted(
        to: CGColorSpace(name: CGColorSpace.sRGB)!,
        intent: .defaultIntent,
        options: nil
      ),
      let components = converted.components
    else {
      return nil
    }
    if components.count >= 4 {
      red = Double(components[0])
      green = Double(components[1])
      blue = Double(components[2])
      alpha = Double(components[3])
    } else if components.count == 2 {
      red = Double(components[0])
      green = Double(components[0])
      blue = Double(components[0])
      alpha = Double(components[1])
    } else {
      return nil
    }
  }

  public var cgColor: CGColor {
    CGColor(
      colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
      components: [red, green, blue, alpha]
    )!
  }

  public var hex: String {
    let values = [red, green, blue, alpha].map {
      Int(($0 * 255).rounded()).clamped(to: 0...255)
    }
    if values[3] == 255 {
      return String(format: "#%02X%02X%02X", values[0], values[1], values[2])
    }
    return String(
      format: "#%02X%02X%02X%02X",
      values[0],
      values[1],
      values[2],
      values[3]
    )
  }

  public func approximatelyEquals(_ other: CalendarColor, tolerance: Double = 0.01) -> Bool {
    abs(red - other.red) <= tolerance
      && abs(green - other.green) <= tolerance
      && abs(blue - other.blue) <= tolerance
      && abs(alpha - other.alpha) <= tolerance
  }
}

extension Comparable {
  fileprivate func clamped(to limits: ClosedRange<Self>) -> Self {
    min(max(self, limits.lowerBound), limits.upperBound)
  }
}
