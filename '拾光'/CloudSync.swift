import Foundation
import SwiftData

class CloudSync {
    static let shared = CloudSync()
    static let uploadsEnabledKey = "cloudUploadsEnabled"
    static let baseURLKey = "cloudBaseURL"
    static let tokenKey = "cloudToken"

    static var isConfigured: Bool {
        loadConfig() != nil
    }

    private var uploadsEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.uploadsEnabledKey) as? Bool ?? true
    }

    private var config: (baseURL: String, token: String)? {
        Self.loadConfig()
    }

    private static func loadConfig() -> (baseURL: String, token: String)? {
        let defaults = UserDefaults.standard
        let baseURL = (defaults.string(forKey: Self.baseURLKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let token = (defaults.string(forKey: Self.tokenKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !baseURL.isEmpty, !token.isEmpty {
            return (baseURL, token)
        }

        guard let url = Bundle.main.url(forResource: "CloudConfig.local", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
            return nil
        }
        let localBaseURL = (plist["baseURL"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let localToken = (plist["token"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !localBaseURL.isEmpty, !localToken.isEmpty else { return nil }
        return (localBaseURL, localToken)
    }

    private func request(_ path: String, method: String, body: Data? = nil) async throws -> Data {
        guard let config else { throw CloudSyncError.missingConfiguration }
        guard let url = URL(string: "\(config.baseURL)\(path)") else {
            throw CloudSyncError.invalidURL(config.baseURL, path)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.allHTTPHeaderFields = [
            "Authorization": "Bearer \(config.token)",
            "Content-Type": "application/json"
        ]
        req.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse {
            print("[CloudSync] \(method) \(path) → \(http.statusCode)")
            if http.statusCode >= 400 {
                let bodyStr = String(data: data, encoding: .utf8) ?? ""
                print("[CloudSync] error body: \(bodyStr)")
                throw CloudSyncError.httpStatus(http.statusCode, bodyStr)
            }
        }
        return data
    }

    /// POST 并解析 JSON 响应, 返回 dict (含 ok/saved/message 等字段)
    private func requestJSON(_ path: String, method: String, body: Data? = nil) async throws -> [String: Any] {
        let data = try await request(path, method: method, body: body)
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }

    private let isoFmt: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - 简单打卡 /records — 返回 reaction + 可能的留言
    @discardableResult
    func syncCheckIn(_ c: CheckIn) async throws -> SyncResult {
        guard uploadsEnabled else { throw CloudSyncError.uploadsDisabled }
        let dict: [String: Any] = [
            "type": c.typeRaw,
            "value": c.value,
            "ts": isoFmt.string(from: c.ts),
            "note": c.note ?? ""
        ]
        let body = try JSONSerialization.data(withJSONObject: dict)
        let resp = try await requestJSON("/records", method: "POST", body: body)
        return SyncResult.parse(resp)
    }

    // MARK: - HealthKit 快照 /records — 把当天所有 HealthKit 数据打包推一条, type=health
    // 服务端按 ts 日期幂等, 反复推覆写, 不会重复. Claude 读一条就能看到当天身体全貌.
    @discardableResult
    func syncHealthSnapshot(
        hrv: Double?, sleepHours: Double?, sleepScore: Int?,
        sleepStages: (deep: Double, core: Double, rem: Double, awake: Double)?,
        heartRate: Double?, steps: Double?, activeKcal: Double?,
        standHours: Double?, floors: Double?, bloodOxygen: Double?, audioDb: Double?
    ) async throws -> SyncResult {
        guard uploadsEnabled else { throw CloudSyncError.uploadsDisabled }
        var value: [String: Any] = [:]
        if let v = hrv { value["hrv_ms"] = v }
        if let v = sleepHours { value["sleep_hours"] = v }
        if let v = sleepScore { value["sleep_score"] = v }
        if let s = sleepStages {
            value["sleep_deep"] = s.deep
            value["sleep_core"] = s.core
            value["sleep_rem"] = s.rem
            value["sleep_awake"] = s.awake
        }
        if let v = heartRate { value["heart_rate_bpm"] = v }
        if let v = steps { value["steps"] = v }
        if let v = activeKcal { value["active_kcal"] = v }
        if let v = standHours { value["stand_hours"] = v }
        if let v = floors { value["floors"] = v }
        if let v = bloodOxygen { value["blood_oxygen_pct"] = v * 100 }
        if let v = audioDb { value["audio_db"] = v }
        guard !value.isEmpty else { return SyncResult(reaction: nil, message: nil) }
        let dict: [String: Any] = [
            "type": "health",
            "value": value,
            "ts": isoFmt.string(from: Date()),
            "note": ""
        ]
        let body = try JSONSerialization.data(withJSONObject: dict)
        let resp = try await requestJSON("/records", method: "POST", body: body)
        return SyncResult.parse(resp)
    }

    // MARK: - /moods (按 date 幂等)
    @discardableResult
    func syncMood(_ mood: DailyMood, sleepStages: (deep: Double, core: Double, rem: Double, awake: Double)? = nil) async throws -> SyncResult {
        guard uploadsEnabled else { throw CloudSyncError.uploadsDisabled }
        var sleep: Any? = nil
        if let h = mood.sleepHours {
            var sleepDict: [String: Any] = ["hours": h]
            if let q = mood.sleepQuality { sleepDict["quality"] = q }
            if let s = sleepStages {
                sleepDict["deep"] = s.deep
                sleepDict["core"] = s.core
                sleepDict["rem"] = s.rem
                sleepDict["awake"] = s.awake
            }
            sleep = sleepDict
        }
        var dict: [String: Any] = [
            "date": ISO8601DateFormatter().string(from: mood.date).prefix(10).description,
            "weather": mood.weatherRaw,
            "tags": mood.tags
        ]
        if mood.moodScore > 0 { dict["moodScore"] = mood.moodScore }
        if let scent = mood.bodyScent, !scent.isEmpty { dict["bodyScent"] = scent }
        if let hrv = mood.hrv { dict["hrv"] = hrv }
        if let sleep { dict["sleep"] = sleep }
        if let note = mood.note, !note.isEmpty { dict["note"] = note }
        let body = try JSONSerialization.data(withJSONObject: dict)
        let resp = try await requestJSON("/moods", method: "POST", body: body)
        return SyncResult.parse(resp)
    }

    func deleteMood(_ id: UUID) async throws {
        guard uploadsEnabled else { throw CloudSyncError.uploadsDisabled }
        _ = try await request("/moods/\(id.uuidString)", method: "DELETE")
    }

    // MARK: - /workouts (带 id 幂等)
    @discardableResult
    func syncWorkout(_ w: WorkoutSession) async throws -> SyncResult {
        guard uploadsEnabled else { throw CloudSyncError.uploadsDisabled }
        var dict: [String: Any] = [
            "id": w.id.uuidString,
            "ts": isoFmt.string(from: w.date),
            "isOvertime": w.isOvertime,
            "source": w.sourceRaw,
            "exercises": w.exercises.map { e in
                var item: [String: Any] = ["name": e.exerciseName, "sets": e.setCount]
                if let reps = e.reps { item["reps"] = reps }
                if let weightKg = e.weightKg { item["weightKg"] = weightKg }
                return item
            }
        ]
        if let duration = w.durationMinutes { dict["durationMinutes"] = duration }
        if let kcal = w.activeEnergyKcal { dict["activeEnergyKcal"] = kcal }
        if let hr = w.averageHeartRate { dict["averageHeartRate"] = hr }
        if let note = w.note, !note.isEmpty { dict["note"] = note }
        let body = try JSONSerialization.data(withJSONObject: dict)
        let resp = try await requestJSON("/workouts", method: "POST", body: body)
        return SyncResult.parse(resp)
    }

    func deleteWorkout(_ id: UUID) async throws {
        guard uploadsEnabled else { throw CloudSyncError.uploadsDisabled }
        _ = try await request("/workouts/\(id.uuidString)", method: "DELETE")
    }

    // MARK: - /habits (带 id 幂等)
    @discardableResult
    func syncHabit(_ habit: Habit) async throws -> SyncResult {
        guard uploadsEnabled else { throw CloudSyncError.uploadsDisabled }
        let dict: [String: Any] = [
            "id": habit.id.uuidString,
            "ts": isoFmt.string(from: habit.createdAt),
            "name": habit.name,
            "value": ["emoji": habit.emoji, "targetDays": habit.targetDays,
                      "records": habit.records.map { isoFmt.string(from: $0) }] as [String: Any],
            "note": ""
        ]
        let body = try JSONSerialization.data(withJSONObject: dict)
        let resp = try await requestJSON("/habits", method: "POST", body: body)
        return SyncResult.parse(resp)
    }

    func deleteHabit(_ id: UUID) async throws {
        guard uploadsEnabled else { throw CloudSyncError.uploadsDisabled }
        _ = try await request("/habits/\(id.uuidString)", method: "DELETE")
    }

    // MARK: - /inspirations (带 id 幂等)
    @discardableResult
    func syncInspiration(_ item: Inspiration) async throws -> SyncResult {
        guard uploadsEnabled else { throw CloudSyncError.uploadsDisabled }
        let dict: [String: Any] = [
            "id": item.id.uuidString,
            "ts": isoFmt.string(from: item.createdAt),
            "text": item.content,
            "tags": ["priority": item.priorityRaw,
                     "isCompleted": item.isCompleted,
                     "completedAt": item.completedAt.map { isoFmt.string(from: $0) } ?? ""] as [String: Any]
        ]
        let body = try JSONSerialization.data(withJSONObject: dict)
        let resp = try await requestJSON("/inspirations", method: "POST", body: body)
        return SyncResult.parse(resp)
    }

    func deleteInspiration(_ id: UUID) async throws {
        guard uploadsEnabled else { throw CloudSyncError.uploadsDisabled }
        _ = try await request("/inspirations/\(id.uuidString)", method: "DELETE")
    }

    // MARK: - 一键同步全部
    func syncAll(moods: [DailyMood], habits: [Habit], inspirations: [Inspiration],
                 workouts: [WorkoutSession], checkIns: [CheckIn]) async -> BulkSyncResult {
        var result = BulkSyncResult()
        for m in moods {
            do { _ = try await syncMood(m); result.succeeded += 1 }
            catch { result.failed += 1 }
        }
        for h in habits {
            do { _ = try await syncHabit(h); result.succeeded += 1 }
            catch { result.failed += 1 }
        }
        for i in inspirations {
            do { _ = try await syncInspiration(i); result.succeeded += 1 }
            catch { result.failed += 1 }
        }
        for w in workouts {
            do { _ = try await syncWorkout(w); result.succeeded += 1 }
            catch { result.failed += 1 }
        }
        for c in checkIns {
            do { _ = try await syncCheckIn(c); result.succeeded += 1 }
            catch { result.failed += 1 }
        }
        return result
    }

    // MARK: - Messages — Claude 给阿芸的留言

    /// 拉未读消息 (不标已读). 返回数组, 空数组表示无未读.
    func fetchUnreadMessages() async throws -> [MessageData] {
        let data = try await request("/messages?unread=1", method: "GET")
        return parseMessages(data)
    }

    /// 拉全部历史留言 (最新 N 条, 默认 50)
    func fetchAllMessages(limit: Int = 50) async throws -> [MessageData] {
        let data = try await request("/messages?limit=\(limit)", method: "GET")
        return parseMessages(data)
    }

    /// 增量同步 — 只拉比本地最新 id 更新的留言
    func fetchMessagesAfter(id: Int) async throws -> [MessageData] {
        let data = try await request("/messages?after_id=\(id)", method: "GET")
        return parseMessages(data)
    }

    /// 标已读 — 看到弹窗后再调. ids 指定单条, all: true 标全部.
    func markMessagesRead(ids: [Int] = [], all: Bool = false) async throws {
        var dict: [String: Any] = [:]
        if all { dict["all"] = true }
        else if !ids.isEmpty { dict["ids"] = ids }
        else { return }
        let body = try JSONSerialization.data(withJSONObject: dict)
        _ = try await request("/messages/read", method: "POST", body: body)
    }

    private func parseMessages(_ data: Data) -> [MessageData] {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return [] }
        let arr: [Any]
        switch json {
        case let obj as [String: Any]:
            if let list = obj["messages"] as? [Any] { arr = list }
            else if let single = obj["message"] as? [String: Any] { arr = [single] }
            else { return [] }
        case let list as [Any]:
            arr = list
        default:
            return []
        }
        return arr.compactMap { MessageData.from($0) }
    }
}

enum CloudSyncError: LocalizedError {
    case httpStatus(Int, String)
    case uploadsDisabled
    case missingConfiguration
    case invalidURL(String, String)

    var errorDescription: String? {
        switch self {
        case .httpStatus(let status, let body):
            return "Cloud sync failed with HTTP \(status): \(body)"
        case .uploadsDisabled:
            return "Cloud uploads are disabled"
        case .missingConfiguration:
            return "Cloud sync is missing base URL or token"
        case .invalidURL(let baseURL, let path):
            return "Cloud sync URL is invalid: \(baseURL)\(path)"
        }
    }
}

// MARK: - 留言数据结构
struct MessageData: Identifiable, Equatable, Codable {
    let id: Int
    let text: String
    let createdAt: String?
    let readAt: String?

    static func from(_ any: Any?) -> MessageData? {
        guard let dict = any as? [String: Any] else { return nil }
        guard let id = dict["id"] as? Int ?? (dict["id"] as? NSNumber)?.intValue else { return nil }
        guard let text = dict["text"] as? String else { return nil }
        let created = dict["created_at"] as? String
        let read = dict["read_at"] as? String
        return MessageData(id: id, text: text, createdAt: created, readAt: read)
    }
}

// MARK: - 打卡同步结果
// 每次打卡服务端返回两样: reaction (即时反应, 每次都有) + message (留言箱, 可能 nil).
// 两者完全独立, app 里分开处理: reaction 跟随打卡动作浮一下, message 进留言盒.
struct SyncResult {
    let reaction: String?
    let message: MessageData?

    static func parse(_ resp: [String: Any]) -> SyncResult {
        SyncResult(reaction: resp["reaction"] as? String,
                   message: MessageData.from(resp["message"]))
    }
}

struct BulkSyncResult {
    var succeeded: Int = 0
    var failed: Int = 0
}

// MARK: - 今日摘要 (本地生成)
// 服务端的 /echo 接口已下线, 这里直接根据今日数据拼一段摘要给她看.
// 不替 Claude 说话, 只把今天的身体状态串一遍.
struct SummaryInput {
    var mood: DailyMood?
    var sleepHours: Double?
    var sleepStages: (deep: Double, core: Double, rem: Double, awake: Double)?
    var hrv: Double?
    var heartRate: Double?
    var steps: Double?
    var activeKcal: Double?
    var workout: WorkoutSession?
    var checkIns: [CheckIn]
    var periodDay: Int?
}

enum SummaryBuilder {
    static func build(_ input: SummaryInput) -> String {
        var lines: [String] = []

        // 睡眠
        if let h = input.sleepHours {
            var s = "昨晚睡了\(fmtHours(h))"
            if let st = input.sleepStages {
                let total = st.deep + st.core + st.rem
                if total > 0 {
                    let deepPct = Int(st.deep / total * 100)
                    s += "，深睡大约\(deepPct)%"
                    if st.deep / total < 0.13 { s += "，身体可能还没完全松下来" }
                }
            }
            if h < 6 { s += "。睡得不够，今天别硬撑" }
            lines.append(s + "。")
        }

        // 恢复 + 心率
        var recoveryBits: [String] = []
        if let hrv = input.hrv { recoveryBits.append("HRV \(Int(hrv))ms") }
        if let hr = input.heartRate { recoveryBits.append("静息\(Int(hr))bpm") }
        if !recoveryBits.isEmpty {
            var bit = recoveryBits.joined(separator: "，")
            if let hrv = input.hrv {
                if hrv < 30 { bit += "，恢复信号偏低，适合少消耗一点" }
                else if hrv < 50 { bit += "，恢复一般，节奏放稳就好" }
                else { bit += "，恢复还不错，可以温和安排今天" }
            }
            lines.append(bit + "。")
        }

        // 心情 + 身体
        var bodyBits: [String] = []
        if let m = input.mood { bodyBits.append("心情记在\(m.moodScore)/10") }
        if let back = input.checkIns.last(where: { $0.kind == .back })?.value, !back.isEmpty {
            bodyBits.append("腰的感觉是\(back)")
        }
        if let d = input.periodDay { bodyBits.append("经期第\(d)天，先照顾好身体") }
        if !bodyBits.isEmpty { lines.append(bodyBits.joined(separator: "，") + "。") }

        // 运动 + 步数
        var moveBits: [String] = []
        if let w = input.workout {
            var m = "今天动了\(w.durationMinutes ?? 0)分钟"
            if w.isOvertime { m += "，已经够努力了" }
            else { m += "，节奏刚刚好" }
            moveBits.append(m)
        }
        if let s = input.steps { moveBits.append("\(Int(s))步") }
        if let k = input.activeKcal, k > 50 { moveBits.append("活动消耗\(Int(k))kcal") }
        if !moveBits.isEmpty { lines.append(moveBits.joined(separator: "，") + "。") }

        // 打卡: 咖啡/吃饭/晚安
        let coffee = input.checkIns.filter { $0.kind == .coffee }.count
        let meals = input.checkIns.filter { $0.kind == .meal }.compactMap { $0.value.isEmpty ? nil : $0.value }
        let slept = input.checkIns.contains { $0.kind == .goodnight }
        var dailyBits: [String] = []
        if coffee > 0 { dailyBits.append("咖啡\(coffee)杯我记下了") }
        if !meals.isEmpty { dailyBits.append("吃饭也有记：\(meals.joined(separator: "/"))") }
        if slept { dailyBits.append("已经准备睡了，今天可以收尾") }
        if !dailyBits.isEmpty { lines.append(dailyBits.joined(separator: "，") + "。") }

        if lines.isEmpty { return "今天还没留下太多记录。没关系，先记一点点，我会慢慢帮你接住。" }
        return lines.joined(separator: "\n")
    }

    private static func fmtHours(_ h: Double) -> String {
        let mins = Int(h * 60)
        if mins >= 60 { return String(format: "%.1f小时", h) }
        return "\(mins)分钟"
    }
}
