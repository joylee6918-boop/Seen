import SwiftUI
import HealthKit

struct BodyView: View {
    @EnvironmentObject var healthManager: HealthManager
    @State private var snapshot = BodySnapshot()
    @State private var loading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gBg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerCard
                        bodySection
                        activitySection
                        environmentSection
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("身体")
            .navigationBarTitleDisplayMode(.large)
            .task { await refresh() }
            .refreshable { await refresh() }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(statusTitle)
                    .font(.gH2)
                    .foregroundColor(.gTextPrimary)
                Spacer()
                if loading { ProgressView() }
            }
            Text(statusDetail)
                .font(.gBody)
                .foregroundColor(.gTextBody)
            Text(snapshot.updatedAt.map { "数据更新于 \(clock($0))" } ?? "正在读取 HealthKit")
                .font(.gCaption)
                .foregroundColor(.gTextSecondary)
        }
        .gleanCard()
    }

    private var bodySection: some View {
        MetricSection(title: "身体") {
            BodyMetricTile(type: .sleep, title: "睡眠",
                           value: snapshot.sleepHours.map { String(format: "%.1f h", $0) } ?? "未戴表",
                           detail: snapshot.sleepHours == nil ? "Apple Watch 无睡眠样本" : sleepDetail)
            BodyMetricTile(type: .hrv, title: "HRV 恢复",
                           value: snapshot.hrv.map { "\(Int($0)) ms" } ?? "无数据",
                           detail: snapshot.hrv.map(hrvLabel) ?? "今日暂无样本")
            BodyMetricTile(type: .heart, title: "静息心率",
                           value: snapshot.heartRate.map { "\(Int($0)) bpm" } ?? "无数据",
                           detail: "HealthKit 今日平均")
            BodyMetricTile(type: .oxygen, title: "血氧",
                           value: snapshot.bloodOxygen.map { "\(Int(($0 * 100).rounded()))%" } ?? "无数据",
                           detail: "HealthKit 今日平均")
        }
    }

    private var activitySection: some View {
        MetricSection(title: "日常活动") {
            BodyMetricTile(type: .move, title: "步数",
                           value: snapshot.steps.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "0",
                           detail: "今日累计")
            BodyMetricTile(type: .energy, title: "活动能量",
                           value: snapshot.activeKcal.map { "\(Int($0)) kcal" } ?? "无数据",
                           detail: "今日累计")
            BodyMetricTile(type: .habit, title: "站立",
                           value: snapshot.standHours.map { "\(Int($0.rounded())) h" } ?? "无数据",
                           detail: "Apple Stand Time")
            BodyMetricTile(type: .floors, title: "楼层",
                           value: snapshot.floors.map { "\(Int($0)) 层" } ?? "无数据",
                           detail: "今日累计")
        }
    }

    private var environmentSection: some View {
        MetricSection(title: "环境") {
            BodyMetricTile(type: .sound, title: "环境音量",
                           value: snapshot.audioDb.map { "\(Int($0.rounded())) dB" } ?? "无数据",
                           detail: snapshot.audioDb.map(dbLabel) ?? "今日暂无样本")
        }
    }

    private func refresh() async {
        loading = true
        if healthManager.authorizationStatus != .sharingAuthorized {
            try? await healthManager.requestAuthorization()
        }
        snapshot.hrv = try? await healthManager.fetchTodayHRV()
        snapshot.sleepHours = try? await healthManager.fetchLastNightSleep()
        snapshot.sleepStages = try? await healthManager.fetchLastNightSleepStages()
        snapshot.sleepScore = await healthManager.fetchSleepScoreBreakdown()
        snapshot.heartRate = try? await healthManager.fetchTodayRestingHeartRate()
        snapshot.steps = try? await healthManager.fetchTodaySteps()
        snapshot.activeKcal = try? await healthManager.fetchTodayActiveEnergy()
        snapshot.standHours = try? await healthManager.fetchTodayStandTime()
        snapshot.floors = try? await healthManager.fetchTodayFlightsClimbed()
        snapshot.bloodOxygen = try? await healthManager.fetchTodayBloodOxygen()
        snapshot.audioDb = try? await healthManager.fetchTodayAudioExposure()
        snapshot.updatedAt = Date()
        loading = false
    }

    private var statusTitle: String {
        if snapshot.sleepHours == nil { return "昨晚没有手表睡眠数据" }
        if let hrv = snapshot.hrv, hrv < 30 { return "恢复状态偏低" }
        return "今天的身体数据在这里"
    }

    private var statusDetail: String {
        if snapshot.sleepHours == nil {
            return "Seen 不会用其它来源替你猜睡眠。没有 Apple Watch 样本时，睡眠会明确显示未戴表。"
        }
        return "这些是当前从 HealthKit 读取到的数据，用来给依安解释你的状态。"
    }

    private var sleepDetail: String {
        if let score = snapshot.sleepScore, let stages = snapshot.sleepStages {
            return "评分 \(score.total) · 深睡 \(formatHours(stages.deep))"
        }
        return "Apple Watch 睡眠样本"
    }

    private func hrvLabel(_ v: Double) -> String { v < 30 ? "偏低" : (v < 60 ? "正常" : "良好") }
    private func dbLabel(_ db: Double) -> String { db < 60 ? "安静" : (db < 80 ? "正常" : "偏吵") }
    private func clock(_ date: Date) -> String { date.formatted(.dateTime.hour().minute()) }
    private func formatHours(_ h: Double) -> String {
        let mins = Int(h * 60)
        return mins >= 60 ? String(format: "%.1fh", h) : "\(mins)min"
    }
}

private struct MetricSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.gH3)
                .foregroundColor(.gTextPrimary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                content
            }
        }
    }
}

private struct BodyMetricTile: View {
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
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.gTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.gCaption)
                .foregroundColor(.gTextWeak)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(13)
        .background(Color.gSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.gHairline, lineWidth: 1))
    }
}

private struct BodySnapshot {
    var hrv: Double?
    var sleepHours: Double?
    var sleepStages: (deep: Double, core: Double, rem: Double, awake: Double)?
    var sleepScore: HealthManager.SleepScoreBreakdown?
    var heartRate: Double?
    var steps: Double?
    var activeKcal: Double?
    var standHours: Double?
    var floors: Double?
    var bloodOxygen: Double?
    var audioDb: Double?
    var updatedAt: Date?
}
