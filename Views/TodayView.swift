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
                SeenBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        tonightNote
                        healthDataOverview
                        mealCheckIn
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
                        Text("AIname 看过了")
                            .font(.gCaption)
                            .foregroundColor(.gTextBody)
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
                    background: .dHrvBg
                )
                NoteChip(
                    text: todayMood.map { "心情 \($0.moodScore)/10" } ?? "心情 --",
                    foreground: .dMood,
                    background: .dMoodBg
                )
            }
        }
        .padding(18)
        .background(SeenCardSurface())
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .seenCardElevation()
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
                                     value: healthSnapshot.heartRate.map { "\(Int($0)) bpm" } ?? "—",
                                     detail: "HealthKit 最近一次记录")
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
                                     value: healthSnapshot.activeKcal.map { "\(Int($0)) kcal" } ?? "—",
                                     detail: "今日累计")
                    HealthMetricTile(type: .heart,
                                     title: "最新心率",
                                     value: healthSnapshot.latestHeartRate.map { "\(Int($0)) bpm" } ?? "—",
                                     detail: "近 24 小时最新样本")
                    ActivityRingMetricTile(kcal: healthSnapshot.activeKcal,
                                           exerciseMinutes: healthSnapshot.exerciseMinutes,
                                           standHours: healthSnapshot.standHours)
                    ActivityActionTile(type: .coffee,
                                       title: "咖啡",
                                       value: todayCoffeeCount == 0 ? "未记录" : "\(todayCoffeeCount) 杯",
                                       detail: "点一下加一杯",
                                       cancelTitle: todayCoffeeCount > 0 ? "撤掉一杯" : nil,
                                       cancelAction: todayCoffeeCount > 0 ? { removeLatestCheckIn(.coffee) } : nil) {
                        addCheckIn(.coffee)
                    }
                    ActivityActionTile(type: .sleep,
                                       title: "我去睡了",
                                       value: hasGoodnight ? "已记录" : "未记录",
                                       detail: "今晚收尾打卡",
                                       done: hasGoodnight) {
                        toggleUniqueCheckIn(.goodnight)
                    }
                }
            }
        }
    }

    // MARK: - 饮食打卡
    private var mealCheckIn: some View {
        VStack(alignment: .leading, spacing: 12) {
            GrowSectionHeader(title: "吃饭", trailing: nil)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                MealCheckButton(title: "早饭",
                                icon: "cup.and.saucer.fill",
                                color: .dAi,
                                background: .dAiBg,
                                done: hasMeal("早")) { toggleMeal("早") }
                MealCheckButton(title: "午饭",
                                icon: "leaf.fill",
                                color: .dAi,
                                background: .dAiBg,
                                done: hasMeal("午")) { toggleMeal("午") }
                MealCheckButton(title: "晚饭",
                                icon: "fork.knife",
                                color: .dAi,
                                background: .dAiBg,
                                done: hasMeal("晚")) { toggleMeal("晚") }
                MealCheckButton(title: "加餐",
                                icon: "takeoutbag.and.cup.and.straw.fill",
                                color: .dAi,
                                background: .dAiBg,
                                done: hasMeal("加")) { toggleMeal("加") }
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
                        reply: "AIname：等你想说的时候，我会在这里。")
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
        .background(SeenCardSurface())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .seenCardElevation()
    }

    // MARK: - 快捷打卡
    private var quickCheckIn: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("跟我说一声").font(.gH3)
                .foregroundColor(.gTextPrimary)
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
    private var todayCheckIns: [CheckIn] {
        let today = calendar.startOfDay(for: Date())
        return validCheckIns.filter { calendar.isDate($0.ts, inSameDayAs: today) }
    }
    private var todayCoffeeCount: Int {
        todayCheckIns.filter { $0.kind == .coffee }.count
    }
    private var hasGoodnight: Bool {
        todayCheckIns.contains { $0.kind == .goodnight }
    }
    private func hasMeal(_ value: String) -> Bool {
        todayCheckIns.contains { $0.kind == .meal && $0.value == value }
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
                     reply: "AIname：\(shortReply(c))")
        }
        if let mood = todayMood {
            items.append(SeenItem(date: mood.date,
                                  time: mood.date.formatted(.dateTime.hour().minute()),
                                  title: "你说\(moodStateText(mood))",
                                  reply: "AIname：看到了，今晚慢一点。"))
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

    private func toggleMeal(_ value: String) {
        if latestCheckIn(.meal, value: value) != nil {
            removeTodayCheckIns(.meal, value: value, toastText: "\(mealName(value))已取消")
        } else {
            addCheckIn(.meal, value: value)
        }
    }

    private func toggleUniqueCheckIn(_ kind: CheckIn.Kind) {
        if latestCheckIn(kind) != nil {
            removeTodayCheckIns(kind, toastText: "\(kind.label)已取消")
        } else {
            addCheckIn(kind)
        }
    }

    private func removeLatestCheckIn(_ kind: CheckIn.Kind, value: String? = nil) {
        guard let existing = latestCheckIn(kind, value: value) else { return }
        removeCheckIn(existing, toastText: "\(kind.label)已取消")
    }

    private func latestCheckIn(_ kind: CheckIn.Kind, value: String? = nil) -> CheckIn? {
        todayCheckIns.first { checkIn in
            checkIn.kind == kind && (value == nil || checkIn.value == value)
        }
    }

    private func removeCheckIn(_ checkIn: CheckIn, toastText: String) {
        checkIn.typeRaw = "__deleted__"
        modelContext.delete(checkIn)
        try? modelContext.save()
        toast = ToastState(text: toastText, undo: nil)
    }

    private func removeTodayCheckIns(_ kind: CheckIn.Kind, value: String? = nil, toastText: String) {
        let targets = todayCheckIns.filter { checkIn in
            checkIn.kind == kind && (value == nil || checkIn.value == value)
        }
        guard !targets.isEmpty else { return }
        for checkIn in targets {
            checkIn.typeRaw = "__deleted__"
            modelContext.delete(checkIn)
        }
        try? modelContext.save()
        toast = ToastState(text: toastText, undo: nil)
    }

    private func mealName(_ value: String) -> String {
        switch value {
        case "早": return "早饭"
        case "午": return "午饭"
        case "晚": return "晚饭"
        case "加": return "加餐"
        default: return "吃饭"
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
        SeenWidgetSnapshotStore.save(SeenWidgetSnapshot(
            updatedAt: healthSnapshot.lastUpdated ?? .now,
            headline: widgetHeadline,
            sleepHours: healthSnapshot.sleepHours,
            hrv: healthSnapshot.hrv,
            restingHeartRate: healthSnapshot.heartRate
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
        case 5..<11:  return "早上好，Username"
        case 11..<14: return "中午好，Username"
        case 14..<18: return "下午好，Username"
        default:      return "晚上好，Username"
        }
    }
    private var subGreeting: String {
        "AIname 刚刚看过你的状态"
    }
    private var widgetHeadline: String {
        if healthSnapshot.sleepHours == nil { return "昨晚没有睡眠数据" }
        if let sleep = healthSnapshot.sleepHours, sleep < 6 { return "今天记得早点休息" }
        if let hrv = healthSnapshot.hrv, hrv < 35 { return "今天少消耗一点" }
        if let mood = todayMood?.moodScore, mood <= 4 { return "今天对自己温柔一点" }
        return "今天也要照顾好自己"
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
        // 评分按 Username 定的 Seen 公式: 时长50 + 规律30 + 中断20 + HRV恢复参考(0..8), 封顶100.
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
            .background(background.opacity(0.7))
            .clipShape(Capsule())
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
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(type.main)
                    .frame(width: 32, height: 32)
                    .background(type.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.gCaption)
                    .foregroundColor(.gTextBody)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 27, weight: .semibold))
                .foregroundColor(.gTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(type.main)
                Text(detail)
                    .foregroundColor(.gTextSecondary)
            }
            .font(.system(size: 11, weight: .regular))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .padding(16)
        .background(SeenCardSurface())
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .seenCardElevation()
    }
}

private struct ActivityActionTile: View {
    let type: DataType
    let title: String
    let value: String
    let detail: String
    var done: Bool = false
    var cancelTitle: String? = nil
    var cancelAction: (() -> Void)? = nil
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(type.main)
                    .frame(width: 32, height: 32)
                    .background(type.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.gCaption)
                    .foregroundColor(.gTextBody)
                Spacer()
                Button(action: action) {
                    Image(systemName: done ? "checkmark" : "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(done ? .gSuccess : type.main)
                        .frame(width: 28, height: 28)
                        .background((done ? Color.dMoveBg : type.bg).opacity(0.85))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            Text(value)
                .font(.system(size: 27, weight: .semibold))
                .foregroundColor(.gTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Text(detail)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.gTextSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let cancelTitle, let cancelAction {
                    Button(action: cancelAction) {
                        Text(cancelTitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(type.main)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .padding(16)
        .background(SeenCardSurface())
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .seenCardElevation()
    }
}

private struct MealCheckButton: View {
    let title: String
    let icon: String
    let color: Color
    let background: Color
    let done: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: done ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(done ? .gSuccess : color)
                    .frame(width: 30, height: 30)
                    .background(done ? Color.dMoveBg : background)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.gH3)
                        .foregroundColor(.gTextPrimary)
                    Text(done ? "已记录 · 再点取消" : "点一下打卡")
                        .font(.gCaption)
                        .foregroundColor(.gTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                Spacer()
            }
            .padding(14)
            .background(SeenCardSurface())
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .seenCardElevation()
        }
        .buttonStyle(.plain)
    }
}

private struct SmallCheckTile: View {
    let type: DataType
    let title: String
    let value: String
    let detail: String
    let done: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: type.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(type.main)
                        .frame(width: 30, height: 30)
                        .background(type.bg)
                        .clipShape(Circle())
                    Spacer()
                    Image(systemName: done ? "checkmark" : "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(done ? .gSuccess : type.main)
                }
                Text(title)
                    .font(.gH3)
                    .foregroundColor(.gTextPrimary)
                Text(value)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(type.main)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(detail)
                    .font(.gCaption)
                    .foregroundColor(.gTextSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
            .padding(15)
            .background(SeenCardSurface())
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .seenCardElevation()
        }
        .buttonStyle(.plain)
    }
}

private struct ActivityRingMetricTile: View {
    let kcal: Double?
    let exerciseMinutes: Double?
    let standHours: Double?

    private var kcalText: String { kcal.map { "\(Int($0))" } ?? "--" }
    private var exerciseText: String { exerciseMinutes.map { "\(Int($0.rounded()))" } ?? "--" }
    private var standText: String { standHours.map { "\(Int($0.rounded()))" } ?? "--" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "circle.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.dMove)
                    .frame(width: 24, height: 24)
                    .background(Color.dMoveBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text("运动圆环")
                    .font(.gCaption)
                    .foregroundColor(.gTextSecondary)
                    .lineLimit(1)
            }
            HStack(alignment: .center, spacing: 12) {
                ActivityRings(kcal: kcal, exerciseMinutes: exerciseMinutes, standHours: standHours)
                    .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 2) {
                    RingMetricText(text: "\(kcalText)/300 千卡", color: .dEnergy)
                    RingMetricText(text: "\(exerciseText)/30 分钟", color: .dMove)
                    RingMetricText(text: "\(standText)/8 小时", color: .dSleep)
                }
            }
            Spacer(minLength: 0)
            Text("合上活动圆环")
                .font(.gCaption)
                .foregroundColor(.gTextWeak)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .padding(16)
        .background(SeenCardSurface())
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .seenCardElevation()
    }
}

private struct RingMetricText: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(color)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
    }
}

private struct ActivityRings: View {
    let kcal: Double?
    let exerciseMinutes: Double?
    let standHours: Double?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.gBg)
                .overlay(Circle().stroke(Color.gHairline, lineWidth: 1))
            // 线宽与半径差要一起控制：每层留出 4.5pt 空隙，三个数据不会粘成一团。
            Ring(progress: progress(kcal, goal: 300), color: .dEnergy, lineWidth: 5.5, inset: 0)
            Ring(progress: progress(exerciseMinutes, goal: 30), color: .dMove, lineWidth: 5.5, inset: 10)
            Ring(progress: progress(standHours, goal: 8), color: .dSleep, lineWidth: 5.5, inset: 20)
        }
        .padding(4)
    }

    private func progress(_ value: Double?, goal: Double) -> Double {
        guard let value else { return 0 }
        return min(max(value / goal, 0), 1)
    }
}

private struct Ring: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    let inset: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .inset(by: inset)
                .stroke(Color.gHairline, lineWidth: lineWidth)
            Circle()
                .inset(by: inset)
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct MiniTrendLine: View {
    let color: Color
    let background: Color

    private let points: [CGFloat] = [0.54, 0.42, 0.68, 0.50, 0.62, 0.57, 0.74]

    var body: some View {
        GeometryReader { proxy in
            let insetX: CGFloat = 10
            let insetY: CGFloat = 7
            let width = max(proxy.size.width - insetX * 2, 1)
            let height = max(proxy.size.height - insetY * 2, 1)
            let step = width / CGFloat(max(points.count - 1, 1))

            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(background.opacity(0.55))

                Path { path in
                    for index in points.indices {
                        let x = insetX + CGFloat(index) * step
                        let y = insetY + height - points[index] * height
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                ForEach(points.indices, id: \.self) { index in
                    let x = insetX + CGFloat(index) * step
                    let y = insetY + height - points[index] * height
                    Circle()
                        .fill(index == points.indices.last ? color : Color.gSurface)
                        .overlay(Circle().stroke(color, lineWidth: 2.5))
                        .frame(width: index == points.indices.last ? 8 : 7, height: index == points.indices.last ? 8 : 7)
                        .position(x: x, y: y)
                }
            }
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
            TextField("自己写一句给 AIname", text: $text)
                .font(.gBody)
                .foregroundColor(.gTextPrimary)
                .textInputAutocapitalization(.never)
                .submitLabel(.send)
                .onSubmit(onSubmit)
            Button(action: onSubmit) {
                Text("发送")
                    .font(.gCaption)
                    .foregroundColor(canSubmit ? .dAi : .gTextSecondary)
            }
            .disabled(!canSubmit)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(SeenCardSurface())
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .seenCardElevation()
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
