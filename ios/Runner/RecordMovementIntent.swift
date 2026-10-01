import AppIntents
import CoreLocation
import Foundation

/// Where what the shortcut hands over came from. The raw values are the
/// ones `CaptureSource.parse` reads in `lib/capture/event.dart`.
enum CaptureSourceOption: String, AppEnum {
  case wallet
  case sms
  case email
  case notification
  case screenshot
  case paste

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Source"
  static let caseDisplayRepresentations: [CaptureSourceOption: DisplayRepresentation] = [
    .wallet: "Apple Pay",
    .sms: "Message",
    .email: "Email",
    .notification: "Notification",
    .screenshot: "Screenshot",
    .paste: "Text",
  ]
}

/// Hands Quincena a payment or a bank's message without opening the app.
///
/// Built for Shortcuts' automations: Wallet after each Apple Pay payment,
/// Message for the bank's texts, Email for its alerts and, from iOS 27,
/// Notification for the banks' apps. The event waits in a file until the
/// app opens; the app reads it, and nothing here decides what it is.
struct RecordMovementIntent: AppIntent {
  static let title: LocalizedStringResource = "Record a movement"
  static let description = IntentDescription(
    "Hands Quincena a payment or a bank's message. It waits in the inbox until you confirm it, or is recorded on its own when everything about it is clear."
  )
  static let openAppWhenRun = false
  static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

  @Parameter(title: "Source", default: .notification)
  var source: CaptureSourceOption

  @Parameter(
    title: "Text",
    description: "The message, the email's subject or the notification, as it arrived.")
  var text: String?

  @Parameter(title: "Merchant")
  var merchant: String?

  @Parameter(title: "Amount")
  var amount: String?

  @Parameter(title: "Card")
  var card: String?

  @Parameter(title: "Sender")
  var sender: String?

  @Parameter(
    title: "Location",
    description: "Where the phone was. Quincena only uses it when the location is on in its settings.",
    inputConnectionBehavior: .connectToPreviousIntentResult)
  var location: CLPlacemark?

  static var parameterSummary: some ParameterSummary {
    Switch(\.$source) {
      Case(.wallet) {
        Summary("Record \(\.$amount) at \(\.$merchant) paid with \(\.$card)") {
          \.$source
          \.$location
        }
      }
      DefaultCase {
        Summary("Record \(\.$text) from \(\.$source)") {
          \.$sender
          \.$location
        }
      }
    }
  }

  func perform() async throws -> some IntentResult {
    let text = Self.clean(self.text)
    let merchant = Self.clean(self.merchant)
    let amount = Self.clean(self.amount)
    guard text != nil || merchant != nil || amount != nil else {
      throw $text.needsValueError("What does the message say?")
    }
    var event: [String: Any] = [
      "source": source.rawValue,
      "at": Date().ISO8601Format(),
    ]
    if let text { event["text"] = text }
    if let merchant { event["merchant"] = merchant }
    if let amount { event["amount"] = amount }
    if let card = Self.clean(card) { event["card"] = card }
    if let sender = Self.clean(sender) { event["sender"] = sender }
    if let place = location?.location, place.horizontalAccuracy >= 0 {
      event["lat"] = place.coordinate.latitude
      event["lng"] = place.coordinate.longitude
      event["accuracy"] = place.horizontalAccuracy
    }
    try CaptureInbox.append(event)
    return .result()
  }

  private static func clean(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
      !trimmed.isEmpty
    else { return nil }
    return trimmed
  }
}

/// Puts the action in Shortcuts and Spotlight with nothing to set up.
struct QuincenaShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: RecordMovementIntent(),
      phrases: ["Record a movement in \(.applicationName)"],
      shortTitle: "Record a movement",
      systemImageName: "tray.and.arrow.down"
    )
  }
}
