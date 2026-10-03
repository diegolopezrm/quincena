import SwiftUI
import WidgetKit

/// What the app last said the widget shows. The app works the figure out
/// and leaves it in the folder it shares with its extensions; this only
/// draws it.
///
/// The same keys as `widgetFigure` in lib/widget/home_widget.dart.
struct Figure {
  let label: String
  let amount: String
  let short: Bool
  let until: String
  let when: String
  /// `2026-10-03`: the day the figure is for.
  let day: String
  let updated: String
  /// What to say once the day is over.
  let stale: String

  /// The same group and key as the widget channel in
  /// Runner/AppDelegate.swift.
  static let appGroup = "group.dev.dlsoft.quincena"
  static let key = "widget.figure"

  static func saved() -> Figure? {
    guard let saved = UserDefaults(suiteName: appGroup)?.dictionary(forKey: key)
    else { return nil }
    func text(_ name: String) -> String { saved[name] as? String ?? "" }
    return Figure(
      label: text("label"), amount: text("amount"), short: saved["short"] as? Bool ?? false,
      until: text("until"), when: text("when"), day: text("day"),
      updated: text("updated"), stale: text("stale"))
  }

  /// What the gallery shows before the widget is added: an example, not
  /// anyone's money.
  static var example: Figure {
    Figure(
      label: String(localized: "You can spend"),
      amount: String(localized: "$299,900"),
      short: false,
      until: String(localized: "until October 15"),
      when: String(localized: "Your pay arrives in 12 days"),
      day: "",
      updated: String(localized: "Updated 9:40 AM"),
      stale: "")
  }
}

struct SpendEntry: TimelineEntry {
  let date: Date
  /// Nil until the app has said anything, or after it forgot.
  let figure: Figure?
  /// The day has changed since the app worked the figure out.
  let stale: Bool
}

struct SpendProvider: TimelineProvider {
  func placeholder(in context: Context) -> SpendEntry {
    SpendEntry(date: Date(), figure: .example, stale: false)
  }

  func getSnapshot(in context: Context, completion: @escaping (SpendEntry) -> Void) {
    completion(context.isPreview ? placeholder(in: context) : entry(at: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SpendEntry>) -> Void) {
    let now = Date()
    var entries = [entry(at: now)]
    // At midnight the figure becomes yesterday's, and says so.
    if let midnight = Calendar.current.nextDate(
      after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
      matchingPolicy: .nextTime)
    {
      entries.append(entry(at: midnight))
    }
    // The app asks for a new timeline whenever it has a new figure.
    completion(Timeline(entries: entries, policy: .never))
  }

  private func entry(at date: Date) -> SpendEntry {
    let figure = Figure.saved()
    return SpendEntry(
      date: date, figure: figure, stale: figure.map { $0.day != Self.day(of: date) } ?? false)
  }

  /// The day of [date] where the phone is, as the app writes it.
  static func day(of date: Date) -> String {
    let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }
}

/// The app's colors, from lib/theme/tokens.dart.
struct Palette {
  let surface: Color
  let ink: Color
  let inkSoft: Color
  let inkFaint: Color
  let brand: Color
  let negative: Color
  let caution: Color

  init(_ scheme: ColorScheme) {
    let dark = scheme == .dark
    surface = Self.rgb(dark ? 0x151A18 : 0xFFFFFF)
    ink = Self.rgb(dark ? 0xE8EEEA : 0x111513)
    inkSoft = Self.rgb(dark ? 0xA7B2AC : 0x4A5450)
    inkFaint = Self.rgb(dark ? 0x909C96 : 0x5F6A64)
    brand = Self.rgb(dark ? 0x3FCB93 : 0x0B7552)
    negative = Self.rgb(dark ? 0xFF7A68 : 0xC8402F)
    caution = Self.rgb(dark ? 0xF2B93F : 0x9A6A00)
  }

  private static func rgb(_ hex: UInt32) -> Color {
    Color(
      red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}

struct SpendView: View {
  let entry: SpendEntry
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let palette = Palette(scheme)
    Group {
      if let figure = entry.figure {
        VStack(alignment: .leading, spacing: 2) {
          Text(figure.label)
            .font(.footnote.weight(.semibold))
            .foregroundColor(palette.inkSoft)
            .lineLimit(1)
          Text(figure.amount)
            .font(.system(size: family == .systemSmall ? 30 : 36, weight: .bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .allowsTightening(true)
            .foregroundColor(figure.short ? palette.negative : palette.ink)
            .opacity(entry.stale ? 0.6 : 1)
            // Left out where the phone shows widgets while locked.
            .privacySensitive()
          Text(figure.until)
            .font(.footnote)
            .foregroundColor(palette.ink)
            .lineLimit(2)
          if family != .systemSmall && !entry.stale && !figure.when.isEmpty {
            Text(figure.when)
              .font(.footnote)
              .foregroundColor(palette.inkSoft)
              .lineLimit(1)
          }
          Spacer(minLength: 4)
          Text(entry.stale ? figure.stale : figure.updated)
            .font(.caption2)
            .foregroundColor(entry.stale ? palette.caution : palette.inkFaint)
            .lineLimit(2)
        }
      } else {
        VStack(alignment: .leading, spacing: 6) {
          Text(verbatim: "Quincena")
            .font(.headline)
            .foregroundColor(palette.brand)
          Spacer(minLength: 4)
          Text("Open Quincena to see how much you can spend.")
            .font(.footnote)
            .foregroundColor(palette.inkSoft)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .widgetBackground(palette.surface)
  }
}

extension View {
  /// The surface behind the figure: from iOS 17 the system's container,
  /// which also sets the margins; before it, a padded background.
  @ViewBuilder func widgetBackground(_ color: Color) -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(color, for: .widget)
    } else {
      padding().background(color)
    }
  }
}

@main
struct SpendWidget: Widget {
  /// The same kind the app reloads in Runner/AppDelegate.swift.
  static let kind = "QuincenaSpend"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: SpendProvider()) { entry in
      SpendView(entry: entry)
    }
    .configurationDisplayName("You can spend")
    .description("How much you can spend until your next pay without hurting your plans.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
