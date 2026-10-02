import Foundation

/// Where the App Intent leaves what the shortcuts hand it, one JSON object
/// per line, for the app to take when it opens or comes back.
///
/// The same file as `captureFileName` in `lib/capture/native_inbox_io.dart`,
/// in the folder `getApplicationSupportDirectory` returns.
enum CaptureInbox {
  static let fileName = "capture-inbox.jsonl"

  /// The folder the app shares with its share extension.
  static let appGroup = "group.dev.dlsoft.quincena"

  /// Where the share extension leaves what it read, or nil without the App
  /// Group, as in a build not signed with the team.
  static var sharedFolder: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
  }

  /// Set while the Flutter engine runs, so an open app takes each event
  /// as it arrives instead of on its next return.
  @MainActor static var onAppend: (() -> Void)?

  /// Appends one event to the file.
  ///
  /// One `write` on a file opened for appending: the app renames the file
  /// before reading it, and an event that arrives meanwhile starts a new
  /// one rather than mixing with the one being read.
  ///
  /// [shared] writes to the App Group's folder instead, as the share
  /// extension does: it cannot reach the app's own.
  static func append(_ event: [String: Any], shared: Bool = false) throws {
    var line = try JSONSerialization.data(
      withJSONObject: event, options: [.sortedKeys, .withoutEscapingSlashes])
    line.append(0x0A)
    let folder: URL
    if shared {
      guard let group = sharedFolder else { throw CocoaError(.fileNoSuchFile) }
      folder = group
    } else {
      folder = try FileManager.default.url(
        for: .applicationSupportDirectory, in: .userDomainMask,
        appropriateFor: nil, create: true)
    }
    let path = folder.appendingPathComponent(fileName).path
    let fd = open(path, O_WRONLY | O_APPEND | O_CREAT, 0o600)
    guard fd >= 0 else { throw CocoaError(.fileWriteNoPermission) }
    defer { close(fd) }
    let written = line.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
    guard written == line.count else { throw CocoaError(.fileWriteUnknown) }
    Task { @MainActor in onAppend?() }
  }
}
