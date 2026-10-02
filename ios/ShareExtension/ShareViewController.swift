import UIKit
import UniformTypeIdentifiers

/// Quincena in the share sheet: a screenshot, a photo, a PDF or a text of a
/// payment, shared from any app, is read on the device and left in the
/// inbox the app shares with this extension, to confirm in "Por revisar".
///
/// Nothing leaves the device here, and nothing is recorded: the app decides
/// what the text means when it opens, as it does with the shortcuts.
@available(iOS 16.0, *)
final class ShareViewController: UIViewController {
  private let label = UILabel()
  private let spinner = UIActivityIndicatorView(style: .medium)

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    label.font = .preferredFont(forTextStyle: .headline)
    label.adjustsFontForContentSizeCategory = true
    label.textAlignment = .center
    label.numberOfLines = 0
    label.text = Self.text(es: "Leyendo…", en: "Reading…")
    let stack = UIStackView(arrangedSubviews: [spinner, label])
    stack.axis = .vertical
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    // Pinned to both sides: a label that wraps takes the width it is given,
    // and without one it wraps after every letter.
    NSLayoutConstraint.activate([
      stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 8),
      stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -8),
    ])
    spinner.startAnimating()
    Task { await read() }
  }

  private func read() async {
    var kept = 0
    var lost = 0
    let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
    for item in items {
      for provider in item.attachments ?? [] {
        guard let (text, source) = await Self.text(of: provider) else { continue }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { continue }
        do {
          try CaptureInbox.append(
            ["source": source, "at": Date().ISO8601Format(), "text": clean], shared: true)
          kept += 1
        } catch {
          lost += 1
        }
      }
    }
    spinner.stopAnimating()
    label.text =
      kept > 0
      ? Self.text(es: "Quedó en Por revisar.", en: "It is waiting in To review.")
      : lost > 0
        ? Self.text(es: "No se pudo guardar. Inténtalo de nuevo.", en: "It could not be saved. Try again.")
        : Self.text(es: "No había texto que leer.", en: "There was no text to read.")
    try? await Task.sleep(nanoseconds: 1_200_000_000)
    extensionContext?.completeRequest(returningItems: nil)
  }

  /// The text in what was shared, read on the device, and where it came
  /// from: a screenshot or a photo, a PDF, or plain text.
  private static func text(of provider: NSItemProvider) async -> (String, String)? {
    if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
      || provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier)
    {
      let type =
        provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier)
        ? UTType.pdf : UTType.image
      guard let data = await load(provider, type), let text = try? TextReader.read(data) else {
        return nil
      }
      return (text, "screenshot")
    }
    if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
      let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
      if let text = item as? String { return (text, "paste") }
      if let data = item as? Data { return (String(decoding: data, as: UTF8.self), "paste") }
    }
    return nil
  }

  private static func load(_ provider: NSItemProvider, _ type: UTType) async -> Data? {
    await withCheckedContinuation { continuation in
      provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
        continuation.resume(returning: data)
      }
    }
  }

  private static func text(es: String, en: String) -> String {
    Locale.preferredLanguages.first?.hasPrefix("en") == true ? en : es
  }
}
