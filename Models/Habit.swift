import Foundation
import SwiftData

@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "💧"
    var targetDays: [Int] = [1,2,3,4,5,6,0]
    var records: [Date] = []
    var createdAt: Date = Date()

    init(name: String, emoji: String, targetDays: [Int] = [1,2,3,4,5,6,0]) {
        self.id         = UUID()
        self.name       = name
        self.emoji      = emoji
        self.targetDays = targetDays
        self.records    = []
        self.createdAt  = Date()
    }

    func isCompletedOn(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return records.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    func toggle(on date: Date) {
        let calendar = Calendar.current
        if let index = records.firstIndex(where: { calendar.isDate($0, inSameDayAs: date) }) {
            records.remove(at: index)
        } else {
            records.append(calendar.startOfDay(for: date))
        }
    }
}
