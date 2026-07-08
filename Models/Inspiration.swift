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
    var categoryRaw: String = "灵光一显"

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

    enum Category: String, Codable, CaseIterable {
        case spark = "灵光一显"
        case todo = "需要处理"
        case bug = "BUG"

        var icon: String {
            switch self {
            case .spark: return "lightbulb"
            case .todo: return "tray.full"
            case .bug: return "exclamationmark.triangle"
            }
        }

        var color: DataType {
            switch self {
            case .spark: return .idea
            case .todo: return .habit
            case .bug: return .heart
            }
        }
    }

    var category: Category {
        get { Category(rawValue: categoryRaw) ?? .spark }
        set { categoryRaw = newValue.rawValue }
    }

    init(content: String, priority: Priority = .normal, category: Category = .spark) {
        self.id          = UUID()
        self.content     = content
        self.isCompleted = false
        self.createdAt   = Date()
        self.priorityRaw = priority.rawValue
        self.categoryRaw = category.rawValue
    }
}
