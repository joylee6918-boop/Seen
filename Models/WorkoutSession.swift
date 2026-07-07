import Foundation
import SwiftData

// 动作条目（非 Model，直接编码存储）
struct ExerciseEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var exerciseName: String
    var weightKg: Double?
    var reps: Int?
    var setCount: Int
    var order: Int

    init(exerciseName: String, weightKg: Double? = nil, reps: Int? = nil, setCount: Int = 1, order: Int = 0) {
        self.id = UUID()
        self.exerciseName = exerciseName
        self.weightKg = weightKg
        self.reps = reps
        self.setCount = setCount
        self.order = order
    }
}

@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var date: Date = Date()
    var typeRaw: String = "力量训练"
    var note: String? = nil
    var durationMinutes: Int? = nil
    var exercisesData: Data = Data()
    // 2026-07-06 — 来源区分: 手动录入 (力量训练记动作组数) vs HealthKit 自动同步 (戴表训练)
    var sourceRaw: String = "manual"
    var externalId: String? = nil
    // 2026-07-06 — 时长 > 40 分钟自动标 true, 同步到云端给 Claude 读
    var isOvertime: Bool = false
    // HealthKit 拉来的额外字段 (手动录入不填)
    var activeEnergyKcal: Double? = nil
    var averageHeartRate: Double? = nil

    enum WorkoutType: String, CaseIterable {
        case strength = "力量训练"
        case cardio = "有氧"
        case hiit = "HIIT"
        case yoga = "瑜伽"
        case run = "跑步"
        case swim = "游泳"
        case other = "其他"

        var emoji: String {
            switch self {
            case .strength: return "🏋️"
            case .cardio: return "🚴"
            case .hiit: return "⚡️"
            case .yoga: return "🧘"
            case .run: return "🏃"
            case .swim: return "🏊"
            case .other: return "💪"
            }
        }
        /// HealthKit workoutActivityType → 我们的类型
        static func fromHealthKit(_ type: UInt) -> WorkoutType {
            switch type {
            case 52:  return .strength  // functionalStrengthTraining
            case 46:  return .strength  // traditionalStrengthTraining
            case 1:   return .run
            case 36:  return .swim
            case 11:  return .cardio    // cycling
            case 13:  return .cardio    // elliptical
            case 20:  return .yoga
            case 59:  return .hiit      // mixedMetabolicCardioTraining
            default:  return .other
            }
        }
    }

    enum Source: String, Codable {
        case manual    = "manual"
        case healthkit = "healthkit"
    }

    var type: WorkoutType {
        get { WorkoutType(rawValue: typeRaw) ?? .strength }
        set { typeRaw = newValue.rawValue }
    }

    var source: Source {
        get { Source(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var exercises: [ExerciseEntry] {
        get { (try? JSONDecoder().decode([ExerciseEntry].self, from: exercisesData)) ?? [] }
        set { exercisesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    /// 写入 durationMinutes 后调, >40 自动算 overtime
    func recomputeOvertime() {
        isOvertime = (durationMinutes ?? 0) > 40
    }

    init(date: Date = Date(), type: WorkoutType = .strength, source: Source = .manual) {
        self.id = UUID()
        self.date = date
        self.typeRaw = type.rawValue
        self.sourceRaw = source.rawValue
        self.exercisesData = Data()
        self.isOvertime = false
    }
}

// 预设动作库
struct ExerciseLibrary {
    static let categories: [(String, [String])] = [
        ("肩背", ["高位下拉", "引体向上（辅助）", "坐姿划船", "单侧划船", "绳索面拉", "直臂下压", "推肩", "哑铃飞鸟（后）"]),
        ("臀腿", ["深蹲", "硬拉", "单腿硬拉", "臀推", "髋外展", "保加利亚深蹲", "腿举", "腿弯举"]),
        ("有氧", ["爬坡跑步机", "楼梯机", "徒步", "骑行", "椭圆机"]),
        ("核心", ["平板支撑", "卷腹", "死虫式", "俄罗斯转体", "悬垂举腿"])
    ]
    static var all: [String] { categories.flatMap { $0.1 } }
}
