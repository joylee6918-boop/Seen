import Foundation
import WidgetKit

struct SeenWidgetSnapshot: Codable {
    let updatedAt: Date
    let headline: String
    let sleepHours: Double?
    let hrv: Double?
    let restingHeartRate: Double?
}

enum SeenWidgetSnapshotStore {
    static let suiteName = "group.YL.Seen"
    static let storageKey = "seen.widget.today.snapshot"

    static func save(_ snapshot: SeenWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot),
              let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(data, forKey: storageKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "SeenTodayWidget")
    }
}
