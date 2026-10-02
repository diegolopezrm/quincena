import Flutter
import UIKit

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
  }
}
