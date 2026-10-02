import AppIntents
import Foundation
import UniformTypeIdentifiers

/// Reads screenshots, photos, PDFs or texts of payments on the device and
/// leaves what they say in Quincena's inbox, without opening the app.
///
/// A shortcut with this action shows up in the share sheet when "Show in
/// Share Sheet" is on, and with "Take Screenshot" before it, Back Tap reads
/// whatever is on the screen. What the text means is decided in Dart, by
/// `parseCapture`; an image always waits there for the person to confirm.
struct ReadReceiptIntent: AppIntent {
  static let title: LocalizedStringResource = "Read a receipt"
  static let description = IntentDescription(
    "Reads screenshots, photos, PDFs or texts of payments on the device and leaves them in Quincena's inbox to confirm."
  )
  static let openAppWhenRun = false
  static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

  @Parameter(
    title: "Receipts",
    description: "Screenshots, photos, PDFs or texts.",
    supportedTypeIdentifiers: ["public.image", "com.adobe.pdf", "public.plain-text"])
  var files: [IntentFile]

  static var parameterSummary: some ParameterSummary {
    Summary("Read \(\.$files)")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    var kept = 0
    for file in files {
      let isText = file.type?.conforms(to: .plainText) ?? file.filename.hasSuffix(".txt")
      let text = isText ? String(decoding: file.data, as: UTF8.self) : try TextReader.read(file.data)
      let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !clean.isEmpty else { continue }
      try CaptureInbox.append([
        "source": isText ? "paste" : "screenshot",
        "at": Date().ISO8601Format(),
        "text": clean,
      ])
      kept += 1
    }
    switch kept {
    case 0: return .result(dialog: "There was no text to read in it.")
    case 1: return .result(dialog: "It is waiting in Quincena's inbox.")
    default: return .result(dialog: "They are waiting in Quincena's inbox.")
    }
  }
}
