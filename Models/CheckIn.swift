import Foundation
import SwiftData

// 通用一键打卡 — 腰况 / 咖啡 / 吃饭 / 晚安 等轻量记录.
// type 区分种类, value 存具体值 (腰况: 好/酸/胀; 吃饭: 早/午/晚; 咖啡/晚安: 空).
@Model
final class CheckIn {
    var id: UUID = UUID()
    var typeRaw: String = "coffee"
    var value: String = ""
    var note: String? = nil
    var ts: Date = Date()

    enum Kind: String, CaseIterable, Codable {
        case back    = "back"      // 腰况
        case coffee  = "coffee"    // 咖啡
        case meal    = "meal"      // 吃饭
        case goodnight = "goodnight" // 晚安
        case period  = "period"    // 经期 — 手动记, 每天点一下
        case note    = "note"      // 自由输入

        var label: String {
            switch self {
            case .back:      return "腰况"
            case .coffee:    return "咖啡"
            case .meal:      return "吃饭"
            case .goodnight: return "晚安"
            case .period:    return "经期"
            case .note:      return "此刻"
            }
        }
        var icon: String {
            switch self {
            case .back:      return "figure.stand"
            case .coffee:    return "cup.and.saucer"
            case .meal:      return "fork.knife"
            case .goodnight: return "moon.zzz"
            case .period:    return "drop.fill"
            case .note:      return "text.bubble"
            }
        }
        /// 候选值, nil 表示无 value (咖啡/晚安/经期 点一下就完事)
        var values: [String]? {
            switch self {
            case .back:      return ["好", "酸", "胀"]
            case .meal:      return ["早", "午", "晚"]
            case .coffee:    return nil
            case .goodnight: return nil
            case .period:    return nil
            case .note:      return nil
            }
        }
    }

    var kind: Kind {
        get { Kind(rawValue: typeRaw) ?? .coffee }
        set { typeRaw = newValue.rawValue }
    }

    init(kind: Kind, value: String = "", note: String? = nil, ts: Date = Date()) {
        self.id = UUID()
        self.typeRaw = kind.rawValue
        self.value = value
        self.note = note
        self.ts = ts
    }
}
