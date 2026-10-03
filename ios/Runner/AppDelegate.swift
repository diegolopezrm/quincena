import Flutter
import UIKit
import UserNotifications
import WidgetKit

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
          let items = args["items"] as? [[String: Any]]
        else { return result(FlutterError(code: "args", message: nil, details: nil)) }
        Reminders.schedule(
          items.compactMap { item in
            guard let at = item["at"] as? NSNumber, let title = item["title"] as? String
            else { return nil }
            return (
              Date(timeIntervalSince1970: at.doubleValue / 1000), title,
              item["body"] as? String ?? ""
            )
          })
        result(nil)
      case "cancel":
        Reminders.cancel()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // The same channel as `HomeWidget` in lib/widget/home_widget.dart: the
    // figure the widget on the home screen shows, left where it reads it.
    let widget = FlutterMethodChannel(
      name: "dev.dlsoft.quincena/widget",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    widget.setMethodCallHandler { call, result in
      // Without the App Group, as in a build not signed with the team,
      // there is no widget to tell.
      guard let shared = UserDefaults(suiteName: CaptureInbox.appGroup) else {
        return result(nil)
      }
      switch call.method {
      case "show":
        guard let figure = call.arguments as? [String: Any] else {
          return result(FlutterError(code: "args", message: nil, details: nil))
        }
        // The same key and kind as ios/QuincenaWidget.
        shared.set(figure, forKey: "widget.figure")
      case "clear":
        shared.removeObject(forKey: "widget.figure")
      default:
        return result(FlutterMethodNotImplemented)
      }
      WidgetCenter.shared.reloadTimelines(ofKind: "QuincenaSpend")
      result(nil)
    }

    // The same channel as `ShareText` in lib/platform/share_text.dart: the
    // system's share sheet, with a message the person chose to send.
    let share = FlutterMethodChannel(
      name: "dev.dlsoft.quincena/share",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    share.setMethodCallHandler { call, result in
      guard call.method == "text", let text = call.arguments as? String,
        let root = UIApplication.shared.connectedScenes
          .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
          .first
      else { return result(false) }
      var top = root
      while let shown = top.presentedViewController { top = shown }
      let sheet = UIActivityViewController(activityItems: [text], applicationActivities: nil)
      // An iPad shows it as a popover, which needs somewhere to point.
      sheet.popoverPresentationController?.sourceView = top.view
      sheet.popoverPresentationController?.sourceRect = CGRect(
        x: top.view.bounds.midX, y: top.view.bounds.maxY - 80, width: 0, height: 0)
      top.present(sheet, animated: true)
      result(true)
    }
  }
}

/// Quincena's reminders: the close of the fortnight on payday, and the
/// renewals the person asked about. None ever carries an amount, since the
/// lock screen shows them.
enum Reminders {
  static let count = 24
  // The ones before build 9 were named after the close only.
  static func ids() -> [String] {
    (0..<count).map { "quincena-\($0)" } + (0..<12).map { "close-\($0)" }
  }

  static func schedule(_ items: [(Date, String, String)]) {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: ids())
    let calendar = Calendar.current
    for (i, (day, title, body)) in items.prefix(count).enumerated() where day > Date() {
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      let when = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: day)
      center.add(
        UNNotificationRequest(
          identifier: "quincena-\(i)", content: content,
          trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)))
    }
  }

  static func cancel() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids())
  }
}
