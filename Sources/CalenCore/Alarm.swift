import Foundation

public enum AlarmProximity: String, Codable, CaseIterable, Sendable {
  case enter
  case leave
}

public struct StructuredLocationSpec: Equatable, Sendable {
  public let title: String
  public let latitude: Double
  public let longitude: Double
  public let radiusMeters: Double

  public init(
    title: String,
    latitude: Double,
    longitude: Double,
    radiusMeters: Double = 100
  ) throws {
    guard (-90...90).contains(latitude) else {
      throw CalenError.invalidInput("Latitude must be between -90 and 90.")
    }
    guard (-180...180).contains(longitude) else {
      throw CalenError.invalidInput("Longitude must be between -180 and 180.")
    }
    guard radiusMeters >= 0 else {
      throw CalenError.invalidInput("Location radius cannot be negative.")
    }
    self.title = try ValueTools.requireNonempty(title, name: "Location title")
    self.latitude = latitude
    self.longitude = longitude
    self.radiusMeters = radiusMeters
  }
}

public enum AlarmSpec: Equatable, Sendable {
  case relative(TimeInterval)
  case absolute(Date)
  case location(AlarmProximity, StructuredLocationSpec)
}

public enum AlarmParser {
  public static func location(_ value: String) throws -> AlarmSpec {
    let parts = value.split(separator: ",", maxSplits: 4).map(String.init)
    guard parts.count == 5,
      let proximity = AlarmProximity(rawValue: parts[0].lowercased()),
      let latitude = Double(parts[1]),
      let longitude = Double(parts[2]),
      let radius = Double(parts[3])
    else {
      throw CalenError.invalidInput(
        "Invalid location alarm. Use enter|leave,latitude,longitude,radius,title."
      )
    }
    let location = try StructuredLocationSpec(
      title: parts[4],
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radius
    )
    return .location(proximity, location)
  }
}
