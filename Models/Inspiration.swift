import Foundation
import SwiftData

@Model
final class Inspiration {
    var id: UUID = UUID()
    var content: String = ""
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var completedAt: Date? = nil
    var priorityRaw: String = "普通"

    enum Priority: String, Codable, CaseIterable {
        case normal    = "普通"
        case important = "重要"
        case urgent    = "紧急"

        var emoji: String {
            switch self {
            case .normal:    return "💭"
            case .important: return "⭐️"
            case .urgent:    return "🔥"
            }
        }
    }

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    init(content: String, priority: Priority = .normal) {
        self.id          = UUID()
        self.content     = content
        self.isCompleted = false
        self.createdAt   = Date()
        self.priorityRaw = priority.rawValue
    }
}
