import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // The same channel as `CaptureChannel` in lib/capture/native_channel.dart.
    // On the desktop it only reads the text in an image or a PDF.
    let capture = FlutterMethodChannel(
      name: "dev.dlsoft.quincena/capture",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    capture.setMethodCallHandler { call, result in
      guard call.method == "readText",
        let bytes = call.arguments as? FlutterStandardTypedData
      else { return result(FlutterMethodNotImplemented) }
      guard #available(macOS 11.0, *) else { return result(nil) }
      DispatchQueue.global(qos: .userInitiated).async {
        let text = try? TextReader.read(bytes.data)
        DispatchQueue.main.async { result(text) }
      }
    }

    super.awakeFromNib()
  }
}
