import SwiftUI
import SwiftData
import HealthKit
import Combine

// 首页 — 温柔陪伴状态日记
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyMood.date, order: .reverse) private var moods: [DailyMood]
    @Query(sort: \CheckIn.ts, order: .reverse) private var checkIns: [CheckIn]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workouts: [WorkoutSession]
    @Query(sort: \Inspiration.createdAt, order: .reverse) private var inspirations: [Inspiration]
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var messageStore: MessageStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var healthSnapshot: HealthSnapshot = .init()
    @State private var toast: ToastState? = nil
    @State private var refreshTimer: Timer? = nil
    @State private var showSleepDetail = false
    @State private var quickNoteText = ""
    @FocusState private var quickNoteFocused: Bool

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        tonightNote
                        healthDataOverview
                        recentlySeen
                        quickCheckIn
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                if let toast = toast {
                    ToastView(text: toast.text, undo: toast.undo)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear { scheduleToastDismiss() }
                }
            }
            .navigationTitle("Seen")
            .navigationBarTitleDisplayMode(.inline)
            .task { await refreshAll() }
            .refreshable { await refreshAll() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await refreshAll() }
                }
            }
            .onReceive(Timer.publish(every: 900, on: .main, in: .common).autoconnect()) { _ in
                Task { await refreshAll() }
            }
            .sheet(isPresented: $showSleepDetail) {
                SleepDetailSheet(stages: healthSnapshot.sleepStages,
                                 hours: healthSnapshot.sleepHours,
                                 breakdown: healthSnapshot.sleepScoreBreakdown)
            }
        }
    }

    // MARK: - 顶部
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.gH2)
                .foregroundColor(.gTextPrimary)
            Text(subGreeting)
                .font(.gCaption)
                .foregroundColor(.gTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 今日状态
    private var tonightNote: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.dAi)
                        .frame(width: 42, height: 42)
                        .background(Color.dAiBg)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("依安看过了")
                            .font(.gCaption)
                            .foregroundColor(.gTextSecondary)
                        Text("今晚先别硬撑")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.gTextPrimary)
                    }
                }
                Spacer()
                Text(Date().formatted(.dateTime.hour().minute()))
                    .font(.gCaption)
                    .foregroundColor(.gTextSecondary)
            }
            Text(tonightNoteBody)
                .font(.gBody)
                .foregroundColor(.gTextBody)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            HStack(spacing: 8) {
                NoteChip(
                    text: healthSnapshot.sleepHours.map { "睡眠 \(String(format: "%.1fh", $0))" } ?? "睡眠 未戴表",
                    foreground: .dSleep,
                    background: .dSleepBg
                )
                    .onTapGesture {
                        if healthSnapshot.sleepStages != nil { showSleepDetail = true }
                    }
                NoteChip(
                    text: healthSnapshot.hrv.map { "HRV \(Int($0))ms" } ?? "HRV --",
                    foreground: .dHrv,
                    background: .gWarmApricotBg
                )
                NoteChip(
                    text: todayMood.map { "心情 \($0.moodScore)/10" } ?? "心情 --",
                    foreground: .dMood,
                    background: .gSelectedBg
                )
            }
        }
        .padding(18)
        .background(Color.gSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.gHairline, lineWidth: 1))
        .shadow(color: Color.gTextPrimary.opacity(0.08), radius: 16, x: 0, y: 7)
    }

    // MARK: - 健康数据核对
    private var healthDataOverview: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                GrowSectionHeader(
                    title: "身体",
                    trailing: healthSnapshot.lastUpdated.map { "更新 \(formatClock($0))" } ?? "正在读取"
                )
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    HealthMetricTile(type: .sleep,
                                     title: "睡眠",
                                     value: healthSnapshot.sleepHours.map { String(format: "%.1f h", $0) } ?? "未戴表",
                                     detail: healthSnapshot.sleepHours == nil ? "Apple Watch 无睡眠样本" : sleepCardSub)
                    HealthMetricTile(type: .heart,
                                     title: "静息心率",
                                     value: healthSnapshot.heartRate.map { "\(Int($0)) bpm" } ?? "无数据",
                                     detail: "HealthKit 今日平均")
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                GrowSectionHeader(title: "日常", trailing: nil)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    HealthMetricTile(type: .move,
                                     title: "步数",
                                     value: healthSnapshot.steps.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "0",
                                     detail: "今日累计")
                    HealthMetricTile(type: .energy,
                                     title: "消耗卡路里",
                                     value: healthSnapshot.activeKcal.map { "\(Int($0)) kcal" } ?? "无数据",
                                     detail: "今日累计")
                    HealthMetricTile(type: .hrv,
                                     title: "HRV",
                                     value: healthSnapshot.hrv.map { "\(Int($0)) ms" } ?? "无数据",
                                     detail: "恢复参考")
                    HealthMetricTile(type: .heart,
                                     title: "最新心率",
                                     value: healthSnapshot.latestHeartRate.map { "\(Int($0)) bpm" } ?? "无数据",
                                     detail: "近 24 小时最新样本")
                    HealthMetricTile(type: .move,
                                     title: "运动圆环",
                                     value: activityRingValue,
                                     detail: "活动 / 锻炼 / 站立")
                    HealthMetricTile(type: .idea,
                                     title: "今日灵感",
                                     value: "\(todayInspirationCount)",
                                     detail: "洞悉记录")
                }
            }
        }
    }

    // MARK: - 刚刚看见
    private var recentlySeen: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("刚刚看见")
                .font(.gH3)
                .foregroundColor(.gTextPrimary)
                .padding(.bottom, 8)
            if seenItems.isEmpty {
                SeenRow(time: Date().formatted(.dateTime.hour().minute()),
                        title: "今天还没有新的记录",
                        reply: "依安：等你想说的时候，我会在这里。")
            } else {
                ForEach(Array(seenItems.prefix(2).enumerated()), id: \.element.id) { index, item in
                    SeenRow(time: item.time, title: item.title, reply: item.reply)
                    if index < min(seenItems.count, 2) - 1 {
                        Divider().background(Color.gHairline)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.gHairline, lineWidth: 1))
        .shadow(color: Color.gTextPrimary.opacity(0.06), radius: 12, x: 0, y: 5)
    }

    // MARK: - 快捷打卡
    private var quickCheckIn: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("跟我说一声").font(.gH3)
                .foregroundColor(.gTextPrimary)
            FlowLayout(spacing: 8) {
                QuickPhraseButton(title: "我有点累") { addCheckIn(.back, value: "累") }
                QuickPhraseButton(title: "早饭吃过了") { addCheckIn(.meal, value: "早") }
                QuickPhraseButton(title: "午饭吃过了") { addCheckIn(.meal, value: "午") }
                QuickPhraseButton(title: "晚饭吃过了") { addCheckIn(.meal, value: "晚") }
                QuickPhraseButton(title: "我喝咖啡了") { addCheckIn(.coffee) }
                QuickPhraseButton(title: "我准备睡了") { addCheckIn(.goodnight) }
            }
            QuickNoteInput(text: $quickNoteText) {
                submitQuickNote()
            }
            .focused($quickNoteFocused)
        }
        .gleanCard()
    }

    // MARK: - 派生
    private var todayMood: DailyMood? {
        let today = calendar.startOfDay(for: Date())
        return moods.first { calendar.isDate($0.date, inSameDayAs: today) && $0.moodScore > 0 }
    }
    private var todayWorkout: WorkoutSession? {
        let today = calendar.startOfDay(for: Date())
        return workouts.first { calendar.isDate($0.date, inSameDayAs: today) }
    }
    private var todayInspirationCount: Int {
        let today = calendar.startOfDay(for: Date())
        return inspirations.filter { calendar.isDate($0.createdAt, inSameDayAs: today) }.count
    }
    private var todayCheckIns: [CheckIn] {
        let today = calendar.startOfDay(for: Date())
        return validCheckIns.filter { calendar.isDate($0.ts, inSameDayAs: today) }
    }
    private var validCheckIns: [CheckIn] {
        checkIns.filter { $0.typeRaw != "__deleted__" }
    }
    private var recentCheckIns: [CheckIn] {
        validCheckIns
    }
    private var seenItems: [SeenItem] {
        var items = recentCheckIns.map { c in
            SeenItem(date: c.ts,
                     time: c.ts.formatted(.dateTime.hour().minute()),
                     title: seenTitle(c),
                     reply: "依安：\(shortReply(c))")
        }
        if let mood = todayMood {
            items.append(SeenItem(date: mood.date,
                                  time: mood.date.formatted(.dateTime.hour().minute()),
                                  title: "你说\(moodStateText(mood))",
                                  reply: "依安：看到了，今晚慢一点。"))
        }
        return items.sorted { $0.date > $1.date }
    }
    private var periodDay: Int? {
        // 经期: 按时间正序扫所有 period 打卡, 遇到"结束"就重置起点,
        // 遇到来潮记录就设起点. 最后一个未结束的起点就是当前经期第 1 天.
        // 距今 > 7 天或已结束都不显示.
        let today = calendar.startOfDay(for: Date())
        var start: Date? = nil
        for c in checkIns.sorted(by: { $0.ts < $1.ts }) where c.kind == .period {
            if c.value == "结束" { start = nil }
            else if c.value != "无" {
                if let s = start {
                    let gap = calendar.dateComponents([.day], from: calendar.startOfDay(for: s), to: calendar.startOfDay(for: c.ts)).day ?? 0
                    if gap > 7 { start = c.ts }
                } else {
                    start = c.ts
                }
            }
        }
        guard let s = start else { return nil }
        let gap = calendar.dateComponents([.day], from: calendar.startOfDay(for: s), to: today).day ?? 0
        if gap < 0 || gap > 7 { return nil }
        return gap + 1
    }

    // MARK: - 动作
    private func addCheckIn(_ kind: CheckIn.Kind, value: String = "") {
        let c = CheckIn(kind: kind, value: value)
        modelContext.insert(c)
        try? modelContext.save()
        toast = ToastState(text: "已看见，慢慢来。", undo: { c.typeRaw = "__deleted__"; modelContext.delete(c); try? modelContext.save() })
        Task {
            if let msg = try? await CloudSync.shared.syncCheckIn(c) {
                messageStore.apply(msg)
            }
        }
    }

    private func submitQuickNote() {
        let text = quickNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        quickNoteText = ""
        quickNoteFocused = false
        dismissKeyboard()
        addCheckIn(.note, value: text)
    }

    private func refreshAll() async {
        // 拉未读留言 (不带 mark_read, 看到弹窗后才标)
        if let msgs = try? await CloudSync.shared.fetchUnreadMessages(), !msgs.isEmpty {
            messageStore.enqueue(msgs)
        }
        // HealthKit
        if healthManager.authorizationStatus != .sharingAuthorized {
            try? await healthManager.requestAuthorization()
        }
        healthSnapshot.hrv = try? await healthManager.fetchTodayHRV()
        healthSnapshot.sleepHours = try? await healthManager.fetchLastNightSleep()
        healthSnapshot.sleepScoreBreakdown = await healthManager.fetchSleepScoreBreakdown()
        healthSnapshot.sleepStages = try? await healthManager.fetchLastNightSleepStages()
        healthSnapshot.heartRate = try? await healthManager.fetchTodayRestingHeartRate()
        healthSnapshot.latestHeartRate = try? await healthManager.fetchLatestHeartRate()
        healthSnapshot.steps = try? await healthManager.fetchTodaySteps()
        healthSnapshot.activeKcal = try? await healthManager.fetchTodayActiveEnergy()
        healthSnapshot.exerciseMinutes = try? await healthManager.fetchTodayExerciseMinutes()
        healthSnapshot.standHours = try? await healthManager.fetchTodayStandTime()
        healthSnapshot.floors = try? await healthManager.fetchTodayFlightsClimbed()
        healthSnapshot.bloodOxygen = try? await healthManager.fetchTodayBloodOxygen()
        healthSnapshot.lastUpdated = Date()
        // HealthKit 全量数据推 VPS — Claude 读一条 health record 就能看到当天身体全貌
        Task {
            if let r = try? await CloudSync.shared.syncHealthSnapshot(
                hrv: healthSnapshot.hrv,
                sleepHours: healthSnapshot.sleepHours,
                sleepScore: healthSnapshot.sleepScoreBreakdown?.total,
                sleepStages: healthSnapshot.sleepStages,
                heartRate: healthSnapshot.heartRate,
                steps: healthSnapshot.steps,
                activeKcal: healthSnapshot.activeKcal,
                standHours: healthSnapshot.standHours,
                floors: healthSnapshot.floors,
                bloodOxygen: healthSnapshot.bloodOxygen,
                audioDb: nil
            ) {
                messageStore.apply(r)
            }
        }
        // Workout 自动同步
        try? await healthManager.syncWorkouts(into: modelContext, days: 7)
        // 睡眠 stages 同步到 VPS (每次进前台/15min 刷一次, 服务端按 date 幂等覆写, 不会重复)
        if let stages = healthSnapshot.sleepStages, let hours = healthSnapshot.sleepHours {
            let today = calendar.startOfDay(for: Date())
            let mood: DailyMood
            if let existing = moods.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
                mood = existing
                mood.sleepHours = hours
            } else {
                mood = DailyMood(date: today, moodScore: 0)
                mood.sleepHours = hours
                modelContext.insert(mood)
                try? modelContext.save()
            }
            Task {
                if let r = try? await CloudSync.shared.syncMood(mood, sleepStages: stages) {
                    messageStore.apply(r)
                }
            }
        }
        // 今日摘要 — 本地根据当天数据拼一段, 不依赖服务端 /echo
        messageStore.todaySummary = SummaryBuilder.build(SummaryInput(
            mood: todayMood,
            sleepHours: healthSnapshot.sleepHours,
            sleepStages: healthSnapshot.sleepStages,
            hrv: healthSnapshot.hrv,
            heartRate: healthSnapshot.heartRate,
            steps: healthSnapshot.steps,
            activeKcal: healthSnapshot.activeKcal,
            workout: todayWorkout,
            checkIns: todayCheckIns,
            periodDay: periodDay
        ))
    }

    private func scheduleToastDismiss() {
        let currentToast = toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if toast?.text == currentToast?.text { toast = nil }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - 标签
    private var greeting: String {
        let hour = calendar.component(.hour, from: Date())
        switch hour {
        case 5..<11:  return "早上好，阿芸"
        case 11..<14: return "中午好，阿芸"
        case 14..<18: return "下午好，阿芸"
        default:      return "晚上好，阿芸"
        }
    }
    private var subGreeting: String {
        "依安刚刚看过你的状态"
    }
    private var companionText: String {
        if let summary = messageStore.todaySummary, !summary.isEmpty {
            return summary
        }
        if let hrv = healthSnapshot.hrv, hrv < 35 {
            return "昨晚睡得有点浅，HRV 也偏低。今天不用硬撑，先把晚饭、热水和休息安排好。"
        }
        if let sleep = healthSnapshot.sleepHours, sleep < 6 {
            return "身体像是还没完全充好电。今天先少消耗一点，把收尾做轻，把休息放前面。"
        }
        return "我会把今天的心情、睡眠和身体信号放在一起看。你不用记得很完整，先把这一刻放下来就好。"
    }
    private var tonightNoteBody: String {
        if healthSnapshot.sleepHours == nil {
            return "昨晚没有 Apple Watch 睡眠数据，我先不替你猜。今晚照着真实状态慢慢收尾。"
        }
        return "我看见你今天有点累。睡眠和恢复都在提醒你，今晚慢一点就好。"
    }
    private func moodLabel(_ s: Int) -> String { ["很糟糕","有点低","还好啦","不错","超级棒"][max(0, min(s-1, 4))] }
    private func sleepQualityLabel(_ h: Double) -> String { h < 5 ? "偏少" : (h < 7 ? "一般" : "良好") }
    private var sleepCardSub: String {
        // 评分按阿芸定的 Seen 公式: 时长50 + 规律30 + 中断20 + HRV恢复参考(0..8), 封顶100.
        if let b = healthSnapshot.sleepScoreBreakdown, let stages = healthSnapshot.sleepStages {
            return "评分\(b.total) · 深睡\(formatHours(stages.deep))"
        }
        if let b = healthSnapshot.sleepScoreBreakdown { return "评分 \(b.total)" }
        if let h = healthSnapshot.sleepHours { return sleepQualityLabel(h) }
        return "未记录"
    }
    private func formatHours(_ h: Double) -> String {
        let mins = Int(h * 60)
        if mins >= 60 { return String(format: "%.1fh", h) }
        return "\(mins)min"
    }
    private func formatClock(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
    private func dbLabel(_ db: Double) -> String { db < 60 ? "安静" : (db < 80 ? "正常" : "偏吵") }
    private func hrvLabel(_ v: Double) -> String { v < 30 ? "偏低" : (v < 60 ? "正常" : "良好") }
    private var activityRingValue: String {
        let kcal = healthSnapshot.activeKcal.map { "\(Int($0))" } ?? "--"
        let exercise = healthSnapshot.exerciseMinutes.map { "\(Int($0.rounded()))" } ?? "--"
        let stand = healthSnapshot.standHours.map { "\(Int($0.rounded()))" } ?? "--"
        return "\(kcal) / \(exercise) / \(stand)"
    }
    private func moodStateText(_ mood: DailyMood) -> String {
        if mood.tags.contains("疲惫") { return "有点疲惫" }
        if let first = mood.tags.first { return first }
        return moodLabel(mood.moodScore)
    }
    private func seenTitle(_ c: CheckIn) -> String {
        switch c.kind {
        case .coffee: return "你喝了咖啡"
        case .goodnight: return "你准备睡了"
        case .meal:
            switch c.value {
            case "早": return "你吃了早饭"
            case "午": return "你吃了午饭"
            case "晚": return "你吃了晚饭"
            default: return "你吃过了"
            }
        case .back: return c.value == "累" ? "你说有点累" : "你说身体有点\(c.value)"
        case .period: return "你记录了经期"
        case .note: return "你说：\(c.value)"
        }
    }
    private func shortReply(_ c: CheckIn) -> String {
        switch c.kind {
        case .coffee: return "记下啦，睡前别太着急。"
        case .goodnight: return "好，今天到这里就可以了。"
        case .back: return "看到了，今晚慢一点。"
        case .meal: return "记下啦，照顾自己这件事很重要。"
        case .period: return "我记着了，今天温柔一点。"
        case .note: return "看到了，我帮你记着。"
        }
    }
}

private struct SeenItem: Identifiable {
    let id = UUID()
    let date: Date
    let time: String
    let title: String
    let reply: String
}

private struct NoteChip: View {
    let text: String
    let foreground: Color
    let background: Color

    var body: some View {
        Text(text)
            .font(.gCaption)
            .foregroundColor(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(background.opacity(0.82))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.gHairline.opacity(0.7), lineWidth: 1))
    }
}

private struct GrowSectionHeader: View {
    let title: String
    let trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.gTextPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.gBody)
                    .foregroundColor(.gTextSecondary)
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct HealthMetricTile: View {
    let type: DataType
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: type.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(type.main)
                    .frame(width: 24, height: 24)
                    .background(type.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(title)
                    .font(.gCaption)
                    .foregroundColor(.gTextSecondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 25, weight: .semibold))
                .foregroundColor(.gTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(detail)
                .font(.gCaption)
                .foregroundColor(.gTextWeak)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Spacer(minLength: 0)
            MiniTileBars(color: type.main)
                .frame(height: 22)
                .opacity(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(16)
        .background(Color.gSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.gHairline, lineWidth: 1))
        .shadow(color: Color.gTextPrimary.opacity(0.06), radius: 13, x: 0, y: 6)
    }
}

private struct MiniTileBars: View {
    let color: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach([0.22, 0.48, 0.82, 0.58, 0.72, 0.38], id: \.self) { ratio in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 5, height: 22 * ratio)
            }
            Spacer(minLength: 0)
            Circle()
                .fill(color.opacity(0.35))
                .frame(width: 5, height: 5)
            Circle()
                .fill(color.opacity(0.25))
                .frame(width: 5, height: 5)
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 5, height: 5)
        }
    }
}

private struct SeenRow: View {
    let time: String
    let title: String
    let reply: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text(time)
                    .font(.gCaption)
                    .foregroundColor(.gTextSecondary)
                    .frame(width: 44, alignment: .leading)
                Text(title)
                    .font(.gBody)
                    .foregroundColor(.gTextPrimary)
                    .lineLimit(1)
            }
            Text(reply)
                .font(.gCaption)
                .foregroundColor(.gTextBody)
                .lineLimit(1)
                .padding(.leading, 54)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dAiBg.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct QuickPhraseButton: View {
    let title: String
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            pressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                pressed = false
            }
        } label: {
            Text(title)
                .font(.gBody)
                .foregroundColor(pressed ? .dMood : .gTextBody)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(pressed ? Color.dMoodBg : Color.gSurface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(pressed ? Color.dMood : Color.gHairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct QuickNoteInput: View {
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("自己写一句给依安", text: $text)
                .font(.gBody)
                .foregroundColor(.gTextPrimary)
                .textInputAutocapitalization(.never)
                .submitLabel(.send)
                .onSubmit(onSubmit)
            Button(action: onSubmit) {
                Text("发送")
                    .font(.gCaption)
                    .foregroundColor(canSubmit ? .dMood : .gTextSecondary)
            }
            .disabled(!canSubmit)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.gSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gHairline, lineWidth: 1))
    }

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - 多值打卡行 (腰况/吃饭, 多个候选按钮)
private struct CheckInRow: View {
    let title: String
    let icon: String
    let onPick: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(.dMove)
                .frame(width: 28)
            Text(title).font(.gBody)
            Spacer()
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { v in
                    Button {
                        onPick(v)
                    } label: {
                        Text(v).font(.gCaption).foregroundColor(.gTextPrimary)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.gHairline.opacity(0.5))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    private var values: [String] {
        switch title {
        case "腰况": return ["好", "酸", "胀"]
        case "吃饭": return ["早", "午", "晚"]
        default: return []
        }
    }
}

// MARK: - 一键按钮 (咖啡/晚安)
private struct OneTapButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 14))
                Text(title).font(.gCaption)
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 最近打卡行
private struct RecentCheckInRow: View {
    let c: CheckIn
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: c.kind.icon).font(.system(size: 14)).foregroundColor(.gTextSecondary)
                .frame(width: 20)
            Text(c.kind.label).font(.gCaption).foregroundColor(.gTextSecondary)
            if !c.value.isEmpty {
                Text("·\(c.value)").font(.gCaption).foregroundColor(.gTextPrimary)
            }
            Spacer()
            Text(c.ts.formatted(.dateTime.hour().minute())).font(.gCaption).foregroundColor(.gTextSecondary)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Toast (轻提示 + 可撤销)
private struct ToastView: View {
    let text: String
    let undo: (() -> Void)?

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Text(text).font(.gCaption).foregroundColor(.white)
                if let undo = undo {
                    Button("撤销", action: undo).font(.gCaption.bold()).foregroundColor(.dAi)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.gTextPrimary.opacity(0.92))
            .clipShape(Capsule())
            .padding(.bottom, 100)
        }
    }
}

private struct ToastState: Equatable {
    let text: String
    let undo: (() -> Void)?
    static func == (lhs: ToastState, rhs: ToastState) -> Bool { lhs.text == rhs.text }
}

private struct HealthSnapshot {
    var hrv: Double? = nil
    var sleepHours: Double? = nil
    var sleepScoreBreakdown: HealthManager.SleepScoreBreakdown? = nil
    var sleepStages: (deep: Double, core: Double, rem: Double, awake: Double)? = nil
    var heartRate: Double? = nil
    var latestHeartRate: Double? = nil
    var steps: Double? = nil
    var activeKcal: Double? = nil
    var exerciseMinutes: Double? = nil
    var standHours: Double? = nil
    var floors: Double? = nil
    var bloodOxygen: Double? = nil
    var lastUpdated: Date? = nil
}

// MARK: - 睡眠详情弹窗
private struct SleepDetailSheet: View {
    let stages: (deep: Double, core: Double, rem: Double, awake: Double)?
    let hours: Double?
    let breakdown: HealthManager.SleepScoreBreakdown?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // 评分总览
                        if let b = breakdown {
                            VStack(spacing: 6) {
                                Text("\(b.total)").font(.system(size: 48, weight: .semibold)).foregroundColor(.dSleep)
                                Text("Seen 睡眠评分").font(.gCaption).foregroundColor(.gTextSecondary)
                                Text(formatHours(hours ?? 0) + " · " + (stages.map { "深睡\(formatHours($0.deep))" } ?? ""))
                                    .font(.gCaption).foregroundColor(.gTextSecondary)
                            }
                            .padding(.top, 8)

                            // 评分明细 — 四块
                            VStack(alignment: .leading, spacing: 12) {
                                Text("评分明细").font(.gH3)
                                scoreRow(name: "睡眠时长", score: b.duration, full: 50, color: .dSleep)
                                scoreRow(name: "作息规律", score: b.consistency, full: 30, color: .dSleep.opacity(0.8))
                                scoreRow(name: "睡眠中断", score: b.interruptions, full: 20, color: .dSleep.opacity(0.6))
                                Divider().background(Color.gHairline)
                                HStack {
                                    Text("恢复参考 (HRV)").font(.gBody)
                                    Spacer()
                                    Text(b.recoveryHRV.map { "\(Int($0))ms  +\(b.recoveryBonus)" } ?? "—  +\(b.recoveryBonus)")
                                        .font(.gBody.bold()).foregroundColor(.dHrv)
                                }
                                HStack {
                                    Text("说明").font(.gCaption).foregroundColor(.gTextSecondary)
                                    Spacer()
                                }
                                Text("时长/规律/中断 三块贴 Apple 结构；恢复参考是 Seen 加的 HRV 加成，只回血不倒扣。")
                                    .font(.gCaption).foregroundColor(.gTextSecondary)
                            }
                            .gleanCard()
                        } else if let h = hours {
                            VStack(spacing: 6) {
                                Text(formatHours(h)).font(.system(size: 40, weight: .semibold)).foregroundColor(.dSleep)
                                Text("总睡眠时长").font(.gCaption).foregroundColor(.gTextSecondary)
                            }
                            .padding(.top, 8)
                        }

                        // 阶段
                        if let s = stages {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("睡眠阶段").font(.gH3)
                                stageBar(name: "深睡", hours: s.deep, color: .dSleep, total: totalSleep)
                                stageBar(name: "核心", hours: s.core, color: .dSleep.opacity(0.7), total: totalSleep)
                                stageBar(name: "REM", hours: s.rem, color: .dSleep.opacity(0.5), total: totalSleep)
                                stageBar(name: "清醒", hours: s.awake, color: .gTextSecondary, total: totalSleep)
                            }
                            .gleanCard()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("阶段占比").font(.gH3)
                                stageRatio("深睡", s.deep)
                                stageRatio("核心", s.core)
                                stageRatio("REM", s.rem)
                                stageRatio("清醒", s.awake)
                            }
                            .gleanCard()
                        } else if breakdown == nil {
                            Text("暂无睡眠数据").font(.gBody).foregroundColor(.gTextSecondary)
                                .padding(.top, 60)
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("睡眠详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
    }

    private var totalSleep: Double {
        guard let s = stages else { return 0 }
        return s.deep + s.core + s.rem
    }

    private func formatHours(_ h: Double) -> String {
        let mins = Int(h * 60)
        if mins >= 60 { return String(format: "%.1fh", h) }
        return "\(mins)min"
    }

    private func scoreRow(name: String, score: Int, full: Int, color: Color) -> some View {
        let ratio = full > 0 ? CGFloat(score) / CGFloat(full) : 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).font(.gBody)
                Spacer()
                Text("\(score)/\(full)").font(.gBody.bold()).foregroundColor(color)
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gHairline)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(color).frame(width: geo.size.width * ratio)
                    }
            }
            .frame(height: 6)
        }
    }

    private func stageBar(name: String, hours: Double, color: Color, total: Double) -> some View {
        let ratio = total > 0 ? hours / total : 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).font(.gBody)
                Spacer()
                Text(formatHours(hours)).font(.gBody.bold()).foregroundColor(color)
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gHairline)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geo.size.width * ratio)
                    }
            }
            .frame(height: 8)
        }
    }

    private func stageRatio(_ name: String, _ h: Double) -> some View {
        let pct = totalSleep > 0 ? Int(h / totalSleep * 100) : 0
        return HStack {
            Text(name).font(.gCaption).foregroundColor(.gTextSecondary)
            Spacer()
            Text("\(pct)%").font(.gCaption.bold()).foregroundColor(.dSleep)
        }
    }
}
