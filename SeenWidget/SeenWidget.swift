import SwiftUI
import WidgetKit

private struct SeenWidgetSnapshot: Codable {
    let updatedAt: Date
    let headline: String
    let sleepHours: Double?
    let hrv: Double?
    let restingHeartRate: Double?
}

private enum SeenWidgetStore {
    static let suiteName = "group.YL.Seen"
    static let storageKey = "seen.widget.today.snapshot"

    static func load() -> SeenWidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(SeenWidgetSnapshot.self, from: data) else {
            return SeenWidgetSnapshot(
                updatedAt: .now,
                headline: "今天也要照顾好自己",
                sleepHours: nil,
                hrv: nil,
                restingHeartRate: nil
            )
        }
        return snapshot
    }
}

private struct SeenWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: SeenWidgetSnapshot
}

private struct SeenWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SeenWidgetEntry {
        SeenWidgetEntry(
            date: .now,
            snapshot: SeenWidgetSnapshot(
                updatedAt: .now,
                headline: "今晚先慢一点",
                sleepHours: 7.2,
                hrv: 48,
                restingHeartRate: 62
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SeenWidgetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : SeenWidgetEntry(date: .now, snapshot: SeenWidgetStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SeenWidgetEntry>) -> Void) {
        let entry = SeenWidgetEntry(date: .now, snapshot: SeenWidgetStore.load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

private struct SeenTodayWidgetView: View {
    let entry: SeenWidgetEntry
    @Environment(\.widgetFamily) private var family

    private let brand = Color(red: 0xF2 / 255, green: 0x8C / 255, blue: 0x53 / 255)
    private let sleep = Color(red: 0x6D / 255, green: 0xB8 / 255, blue: 0xE8 / 255)
    private let recovery = Color(red: 0x8C / 255, green: 0x87 / 255, blue: 0xD3 / 255)
    private let mood = Color(red: 0xEE / 255, green: 0x7C / 255, blue: 0x8D / 255)

    var body: some View {
        if family == .systemMedium {
            mediumContent
        } else {
            smallContent
        }
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(brand)
                    .frame(width: 26, height: 26)
                    .background(brand.opacity(0.13), in: Circle())
                Text("Seen")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Text(entry.date.formatted(.dateTime.month().day()))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(entry.snapshot.headline)
                .font(.system(size: 18, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .padding(.top, 11)

            Spacer(minLength: 8)

            HStack(spacing: 0) {
                metric(icon: "moon.fill", value: sleepText, color: sleep)
                Divider().frame(height: 22)
                metric(icon: "waveform.path.ecg", value: hrvText, color: recovery)
                Divider().frame(height: 22)
                metric(icon: "heart.fill", value: heartRateText, color: mood)
            }
        }
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    private var mediumContent: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(brand)
                        .frame(width: 26, height: 26)
                        .background(brand.opacity(0.13), in: Circle())
                    Text("Seen")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                Text(entry.snapshot.headline)
                    .font(.system(size: 20, weight: .semibold))
                    .lineLimit(2)
                Text(entry.date.formatted(.dateTime.month().day()))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                metric(icon: "moon.fill", value: sleepText, color: sleep)
                metric(icon: "waveform.path.ecg", value: hrvText, color: recovery)
                metric(icon: "heart.fill", value: heartRateText, color: mood)
            }
            .frame(width: 144)
        }
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    private var widgetBackground: LinearGradient {
        LinearGradient(
            colors: [Color(.systemBackground), brand.opacity(0.065)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func metric(icon: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    private var sleepText: String {
        entry.snapshot.sleepHours.map { String(format: "%.1fh", $0) } ?? "—"
    }

    private var hrvText: String {
        entry.snapshot.hrv.map { "\(Int($0))" } ?? "—"
    }

    private var heartRateText: String {
        entry.snapshot.restingHeartRate.map { "\(Int($0)) bpm" } ?? "—"
    }
}

struct SeenTodayWidget: Widget {
    let kind = "SeenTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SeenWidgetProvider()) { entry in
            SeenTodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Seen 今日状态")
        .description("看一眼今天的提醒、睡眠、HRV 和静息心率。")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct SeenWidgetBundle: WidgetBundle {
    var body: some Widget {
        SeenTodayWidget()
    }
}
