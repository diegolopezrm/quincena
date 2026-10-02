import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // The same channel as `CaptureChannel` in lib/capture/native_channel.dart:
    // the app asks for the text in an image, and hears when a shortcut ran
    // while it was open.
    let capture = FlutterMethodChannel(
      name: "dev.dlsoft.quincena/capture",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    capture.setMethodCallHandler { call, result in
      if call.method == "sharedInbox" {
        return result(CaptureInbox.sharedFolder?.path)
      }
      guard call.method == "readText" || call.method == "readStatement",
        let bytes = call.arguments as? FlutterStandardTypedData
      else { return result(FlutterMethodNotImplemented) }
      let statement = call.method == "readStatement"
      DispatchQueue.global(qos: .userInitiated).async {
        let text = try? (statement
          ? TextReader.readStatement(bytes.data) : TextReader.read(bytes.data))
        DispatchQueue.main.async { result(text) }
      }
    }
    CaptureInbox.onAppend = { capture.invokeMethod("captured", arguments: nil) }

    // The same channel as `Reminders` in lib/reminders/reminders.dart.
    let reminders = FlutterMethodChannel(
      name: "dev.dlsoft.quincena/reminders",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    reminders.setMethodCallHandler { call, result in
      let center = UNUserNotificationCenter.current()
      switch call.method {
      case "ask":
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
          DispatchQueue.main.async { result(granted) }
        }
      case "schedule":
        guard let args = call.arguments as? [String: Any],
          let days = args["days"] as? [NSNumber],
          let title = args["title"] as? String
        else { return result(FlutterError(code: "args", message: nil, details: nil)) }
        Reminders.schedule(
          days.map { Date(timeIntervalSince1970: $0.doubleValue / 1000) },
          title: title, body: args["body"] as? String ?? "")
        result(nil)
      case "cancel":
        Reminders.cancel()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// The reminder that the close of the fortnight is ready, on each payday.
/// It says only that: no amount ever shows on the lock screen.
enum Reminders {
  static let count = 12
  static func ids() -> [String] { (0..<count).map { "close-\($0)" } }

  static func schedule(_ days: [Date], title: String, body: String) {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: ids())
    let calendar = Calendar.current
    for (i, day) in days.prefix(count).enumerated() where day > Date() {
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      let when = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: day)
      center.add(
        UNNotificationRequest(
          identifier: "close-\(i)", content: content,
          trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)))
    }
  }

  static func cancel() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids())
  }
}
