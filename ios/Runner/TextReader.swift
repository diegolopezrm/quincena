import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import Vision

/// Reads the text in a screenshot, a photo or a PDF, on the device, with
/// Vision. Shared by the iOS and the macOS apps.
///
/// The text comes out in rows, top to bottom: a receipt's label and its
/// value side by side read as one line, `Valor  $ 50.000`, which is how
/// `parseCapture` in lib/capture/parser.dart finds the figure that matters.
@available(iOS 16.0, macOS 11.0, *)
enum TextReader {
  static func read(_ data: Data) throws -> String {
    if data.starts(with: Array("%PDF".utf8)) { return try readPDF(data) }
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw CocoaError(.fileReadCorruptFile) }
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    let orientation = (properties?[kCGImagePropertyOrientation] as? UInt32)
      .flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up
    return try read(image, orientation: orientation)
  }

  static func read(_ image: CGImage, orientation: CGImagePropertyOrientation = .up) throws
    -> String
  {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["es-ES", "en-US"]
    request.usesLanguageCorrection = true
    try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
    let lines: [(CGRect, String)] = (request.results ?? []).compactMap { observation in
      guard let text = observation.topCandidates(1).first?.string else { return nil }
      return (observation.boundingBox, text)
    }
    return rows(lines)
  }

  /// Lines at the same height make one row, left to right, two spaces
  /// apart; rows go top to bottom. Vision's boxes start at the bottom left.
  static func rows(_ lines: [(CGRect, String)]) -> String {
    var rows: [[(CGRect, String)]] = []
    for line in lines.sorted(by: { $0.0.midY > $1.0.midY }) {
      if let first = rows.last?.first,
        abs(first.0.midY - line.0.midY) < min(first.0.height, line.0.height) / 2
      {
        rows[rows.count - 1].append(line)
      } else {
        rows.append([line])
      }
    }
    return rows.map { row in
      row.sorted(by: { $0.0.minX < $1.0.minX }).map(\.1).joined(separator: "  ")
    }.joined(separator: "\n")
  }

  /// Every page of a statement, as rows: the text a PDF carries, laid out
  /// line by line as it is printed, and a scanned page read like a photo.
  /// Not a PDF, it is read as an image.
  static func readStatement(_ data: Data, maxPages: Int = 60) throws -> String {
    guard data.starts(with: Array("%PDF".utf8)) else { return try read(data) }
    guard let document = PDFDocument(data: data) else { throw CocoaError(.fileReadCorruptFile) }
    var pages: [String] = []
    for index in 0..<min(document.pageCount, maxPages) {
      guard let page = document.page(at: index) else { continue }
      let text = printedRows(page)
      if text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20 {
        pages.append(text)
      } else if let image = render(page) {
        pages.append(try read(image))
      }
    }
    return pages.joined(separator: "\n")
  }

  /// A page's own text, row by row as it is printed: a statement's date,
  /// description and amount on one line, even when the PDF draws its
  /// columns one after another.
  static func printedRows(_ page: PDFPage) -> String {
    guard let all = page.selection(for: page.bounds(for: .mediaBox)) else {
      return page.string ?? ""
    }
    let lines: [(CGRect, String)] = all.selectionsByLine().compactMap { line in
      guard let text = line.string?.trimmingCharacters(in: .whitespacesAndNewlines),
        !text.isEmpty
      else { return nil }
      return (line.bounds(for: page), text)
    }
    return lines.isEmpty ? (page.string ?? "") : rows(lines)
  }

  /// A PDF's own text when it has some; a scanned one is a picture, read
  /// like a photo.
  static func readPDF(_ data: Data) throws -> String {
    guard let document = PDFDocument(data: data) else { throw CocoaError(.fileReadCorruptFile) }
    let pages = (0..<min(document.pageCount, 3)).compactMap { document.page(at: $0) }
    let text = pages.compactMap(\.string).joined(separator: "\n")
    if text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20 { return text }
    guard let page = pages.first, let image = render(page) else { return text }
    return try read(image)
  }

  /// The page at twice its size on white, enough for small print.
  static func render(_ page: PDFPage) -> CGImage? {
    let bounds = page.bounds(for: .mediaBox)
    let scale: CGFloat = 2
    let width = Int(bounds.width * scale)
    let height = Int(bounds.height * scale)
    guard width > 0, height > 0,
      let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { return nil }
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: context)
    return context.makeImage()
  }
}
