import Foundation
import SwiftData

@Model
final class DailyMood {
    var id: UUID = UUID()
    var date: Date = Date()
    var moodScore: Int = 0
    var weatherRaw: String = "☀️ 晴天"
    var bodyScent: String? = nil
    var hrv: Double? = nil
    var sleepHours: Double? = nil
    var sleepQuality: Int? = nil
    var tags: [String] = []
    var note: String? = nil
    var photo: Data? = nil

    enum Weather: String, Codable, CaseIterable {
        case sunny  = "☀️ 晴天"
        case cloudy = "☁️ 多云"
        case rainy  = "🌧 雨天"
        case snowy  = "❄️ 雪天"
        case foggy  = "🌫 雾天"

        var emoji: String { String(rawValue.prefix(2)) }
    }

    var weather: Weather {
        get { Weather(rawValue: weatherRaw) ?? .sunny }
        set { weatherRaw = newValue.rawValue }
    }

    init(date: Date = Date(), moodScore: Int = 0) {
        self.id         = UUID()
        self.date       = Calendar.current.startOfDay(for: date)
        self.moodScore  = moodScore
        self.weatherRaw = Weather.sunny.rawValue
        self.tags       = []
    }
}
