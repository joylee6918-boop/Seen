import SwiftUI
import SwiftData
import HealthKit

// 回信页 — 小纸条 + 今天/更早的依安回复
struct AIView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyMood.date, order: .reverse) private var moods: [DailyMood]
    @Query(sort: \CheckIn.ts, order: .reverse) private var checkIns: [CheckIn]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workouts: [WorkoutSession]
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var messageStore: MessageStore
    @State private var loading = false
    @State private var hrv: Double?
    @State private var sleepHours: Double?
    @State private var sleepStages: (deep: Double, core: Double, rem: Double, awake: Double)?

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        tonightNoteCard
                        todayRepliesSection
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("回信")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private var tonightNoteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("今晚的小纸条")
                    .font(.gCaption)
                    .foregroundColor(.dMood)
                Spacer()
                if loading { ProgressView() }
            }
            Text("今晚先别硬撑")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.gTextPrimary)
            Text(noteReason)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.gTextBody)
                .lineLimit(2)
            FlowLayout(spacing: 8) {
                ReplyEvidenceChip(text: sleepEvidence, foreground: .dSleep, background: .dSleepBg)
                ReplyEvidenceChip(text: deepSleepEvidence, foreground: .dSleep, background: .dSleepBg)
                ReplyEvidenceChip(text: hrvEvidence, foreground: .dHrv, background: .gWarmApricotBg)
                ReplyEvidenceChip(text: moodEvidence, foreground: .dMood, background: .gSelectedBg)
            }
            if !noteDetail.isEmpty {
                Text(noteDetail)
                    .font(.gCaption)
                    .foregroundColor(.gTextSecondary)
                    .lineLimit(1)
            }
        }
        .padding(18)
        .background(Color.gCompanionSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gNoteBorder, lineWidth: 1))
        .shadow(color: Color.gTextPrimary.opacity(0.03), radius: 8, x: 0, y: 3)
    }

    private var todayRepliesSection: some View {
        ReplySection(title: "今天收到的回信", messages: todayMessages)
    }

    private var todayMessages: [MessageData] {
        messageStore.history.filter { msg in
            guard let date = parsedDate(msg.createdAt) else { return false }
            return calendar.isDateInToday(date)
        }
    }

    private func parsedDate(_ iso: String?) -> Date? {
        guard let iso = iso else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        return fractional.date(from: iso) ?? plain.date(from: iso)
    }

    private struct ReplySection: View {
        let title: String
        let messages: [MessageData]

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.gCaption)
                    .foregroundColor(.gTextSecondary)
                    .padding(.leading, 2)
                if messages.isEmpty {
                    Text("还没有新的回信。等你记录一点，依安会在这里回应你。")
                        .font(.gCaption)
                        .foregroundColor(.gTextBody)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.gSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gHairline, lineWidth: 1))
                } else {
                    ForEach(messages.prefix(8)) { msg in
                        ReplyCard(msg: msg)
                    }
                }
            }
        }
    }

    private struct ReplyCard: View {
        let msg: MessageData
        @State private var expanded = false

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gWarmApricot.opacity(0.55))
                    .frame(width: 2)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(triggerLabel)
                            .font(.gCaption)
                            .foregroundColor(.dMood)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.gSelectedBg)
                            .clipShape(Capsule())
                        Spacer(minLength: 8)
                        Text(formatTime(msg.createdAt))
                            .font(.gCaption)
                            .foregroundColor(.gTextSecondary)
                    }
                    Text(msg.text)
                        .font(.gBody)
                        .foregroundColor(.gTextPrimary)
                        .lineSpacing(3)
                        .lineLimit(shouldCollapse && !expanded ? 2 : nil)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if shouldCollapse {
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                expanded.toggle()
                            }
                        } label: {
                            Text(expanded ? "收起" : "展开完整回信")
                                .font(.gCaption)
                                .foregroundColor(.dMood)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(Color.gSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gHairline, lineWidth: 1))
        }

        private var shouldCollapse: Bool {
            msg.text.count > 56 || msg.text.contains("\n")
        }

        private func formatTime(_ iso: String?) -> String {
            guard let iso = iso else { return "刚刚" }
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            guard let date = fractional.date(from: iso) ?? plain.date(from: iso) else { return iso }
            return date.formatted(.dateTime.month().day().hour().minute())
        }

        private var triggerLabel: String {
            let text = msg.text
            if text.contains("咖啡") { return "你记录了：咖啡" }
            if text.contains("疲惫") || text.contains("累") { return "你记录了：疲惫" }
            if text.contains("睡") { return "你记录了：睡眠" }
            if text.contains("HRV") || text.contains("恢复") { return "你记录了：恢复状态" }
            return "你记录了：此刻"
        }
    }

    private func load() async {
        loading = true
        await messageStore.syncFromServer()
        // 自己也拉一份健康数据 + 拼摘要, 这样直接进 AI 页也能看到内容, 不用先去首页.
        await regenerateSummary()
        loading = false
    }

    private var companionSummary: String {
        if let summary = messageStore.todaySummary, !summary.isEmpty {
            return summary
        }
        return "我会把今天的记录慢慢串起来：睡得怎么样、身体累不累、有没有好好吃饭。先不用完整，留下一点点也算数。"
    }

    private func regenerateSummary() async {
        if healthManager.authorizationStatus != .sharingAuthorized {
            try? await healthManager.requestAuthorization()
        }
        let hrv = try? await healthManager.fetchTodayHRV()
        let sleepHours = try? await healthManager.fetchLastNightSleep()
        let stages = try? await healthManager.fetchLastNightSleepStages()
        self.hrv = hrv
        self.sleepHours = sleepHours
        self.sleepStages = stages
        let hr = try? await healthManager.fetchTodayRestingHeartRate()
        let steps = try? await healthManager.fetchTodaySteps()
        let kcal = try? await healthManager.fetchTodayActiveEnergy()
        let today = calendar.startOfDay(for: Date())
        let mood = moods.first { calendar.isDate($0.date, inSameDayAs: today) && $0.moodScore > 0 }
        let workout = workouts.first { calendar.isDate($0.date, inSameDayAs: today) }
        let todayCheckIns = checkIns.filter { calendar.isDate($0.ts, inSameDayAs: today) }
        let periodDay = computePeriodDay()
        messageStore.todaySummary = SummaryBuilder.build(SummaryInput(
            mood: mood, sleepHours: sleepHours, sleepStages: stages,
            hrv: hrv, heartRate: hr, steps: steps, activeKcal: kcal,
            workout: workout, checkIns: todayCheckIns, periodDay: periodDay
        ))
    }

    private var noteReason: String {
        if (sleepHours ?? 8) < 6.5 || (hrv ?? 60) < 35 {
            return "你今天睡得不太够，恢复信号也偏低。"
        }
        return "我看见你今天已经放下了一些东西。"
    }

    private var sleepEvidence: String {
        sleepHours.map { "睡眠 \(String(format: "%.1fh", $0))" } ?? "睡眠 --"
    }

    private var deepSleepEvidence: String {
        guard let stages = sleepStages else { return "深睡 --" }
        let total = stages.deep + stages.core + stages.rem
        guard total > 0 else { return "深睡 --" }
        let percent = Int((stages.deep / total * 100).rounded())
        return "深睡 \(percent)%"
    }

    private var hrvEvidence: String {
        hrv.map { "HRV \(Int($0))" } ?? "HRV --"
    }

    private var moodEvidence: String {
        let today = calendar.startOfDay(for: Date())
        if let mood = moods.first(where: { calendar.isDate($0.date, inSameDayAs: today) && $0.moodScore > 0 }) {
            return "心情 \(mood.moodScore)/10"
        }
        return "心情 --"
    }

    private var noteDetail: String {
        let today = calendar.startOfDay(for: Date())
        let todays = checkIns.filter { calendar.isDate($0.ts, inSameDayAs: today) }
        var parts: [String] = []
        if todays.contains(where: { $0.kind == .coffee }) { parts.append("咖啡 1 杯") }
        if todays.contains(where: { $0.kind == .meal }) { parts.append("吃饭已记录") }
        return parts.isEmpty ? "" : parts.joined(separator: "，") + "。"
    }

    // 跟 TodayView 一致的经期天数算法
    private func computePeriodDay() -> Int? {
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
}

private struct ReplyEvidenceChip: View {
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

private struct TimelineRow: View {
    let icon: String
    let color: Color
    let title: String
    let time: Date?
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(color)
            Text(title).font(.gBody)
            Spacer()
            if let t = time {
                Text(t.formatted(.dateTime.hour().minute()))
                    .font(.gCaption).foregroundColor(.gTextSecondary)
            } else {
                StatusPill(text: "等待", kind: .warning)
            }
        }
    }
}
