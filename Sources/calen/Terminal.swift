import CalenCore
import Darwin
import Foundation

enum Terminal {
  static var isInteractive: Bool {
    isatty(STDIN_FILENO) != 0 && isatty(STDERR_FILENO) != 0
  }

  static func requiredValue(
    _ value: String?,
    name: String,
    prompt: String,
    defaultValue: String? = nil
  ) throws -> String {
    if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return value
    }
    guard isInteractive else {
      throw CalenError.invalidInput(
        "Missing \(name) in noninteractive mode. Pass --\(name.replacingOccurrences(of: " ", with: "-"))."
      )
    }
    let answer = ask(prompt, defaultValue: defaultValue)
    guard let answer, !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw CalenError.invalidInput("\(name.capitalized) is required.")
    }
    return answer
  }

  static func confirm(
    _ prompt: String,
    force: Bool,
    dryRun: Bool
  ) throws {
    switch try DestructivePolicy.decision(
      force: force,
      dryRun: dryRun,
      isInteractive: isInteractive
    ) {
    case .proceed:
      return
    case .confirm:
      let answer = ask("\(prompt) [y/N]", defaultValue: nil)?.lowercased()
      guard answer == "y" || answer == "yes" else {
        throw CalenError.invalidInput("Cancelled.")
      }
    }
  }

  static func ask(_ prompt: String, defaultValue: String?) -> String? {
    let suffix = defaultValue.map { " [\($0)]" } ?? ""
    writeError("\(prompt)\(suffix): ")
    guard let line = readLine() else {
      return nil
    }
    if line.isEmpty {
      return defaultValue
    }
    return line
  }

  static func writeError(_ value: String) {
    FileHandle.standardError.write(Data(value.utf8))
  }
}
