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

    // The same channel as `CaptureChannel` in lib/capture/native_channel.dart.
    // On iOS it only goes one way: a shortcut ran while the app was open.
    let capture = FlutterMethodChannel(
      name: "dev.dlsoft.quincena/capture",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    capture.setMethodCallHandler { _, result in result(FlutterMethodNotImplemented) }
    CaptureInbox.onAppend = { capture.invokeMethod("captured", arguments: nil) }
  }
}
