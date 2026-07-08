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
                        deeperMetricsSection
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

    private var deeperMetricsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("身体指标")
                    .font(.gH2)
                    .foregroundColor(.gTextPrimary)
                Spacer()
                Text("编辑")
                    .font(.gBody)
                    .foregroundColor(.gTextSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gTextSecondary)
            }
            BodyMetricRow(type: .oxygen,
                          title: "血氧",
                          value: snapshot.bloodOxygen.map { "\(Int(($0 * 100).rounded()))" } ?? "--",
                          unit: "%",
                          status: snapshot.bloodOxygen == nil ? "无数据" : "正常",
                          comparison: "HealthKit 今日平均",
                          dateText: "今天")
            BodyMetricRow(type: .temperature,
                          title: "手腕温度",
                          value: snapshot.wristTemperature.map { String(format: "%.1f", $0) } ?? "--",
                          unit: "℃",
                          status: snapshot.wristTemperature == nil ? "无数据" : "已记录",
                          comparison: "最近 30 天最新睡眠样本",
                          dateText: "最近")
            BodyMetricRow(type: .vo2,
                          title: "最大摄氧量",
                          value: snapshot.vo2Max.map { String(format: "%.1f", $0) } ?? "--",
                          unit: "mL/kg/min",
                          status: snapshot.vo2Max == nil ? "无数据" : "已记录",
                          comparison: "最近一年最新样本",
                          dateText: "最近")
            BodyMetricRow(type: .sleepHeart,
                          title: "睡眠时心率",
                          value: snapshot.sleepHeartRate.map { "\(Int($0.rounded()))" } ?? "--",
                          unit: "bpm",
                          status: snapshot.sleepHeartRate == nil ? "无数据" : "正常",
                          comparison: snapshot.sleepHeartRate == nil ? "需要昨晚 Apple Watch 睡眠样本" : "昨晚睡眠区间平均",
                          dateText: "昨晚")
            BodyMetricRow(type: .hrv,
                          title: "HRV",
                          value: snapshot.hrv.map { "\(Int($0))" } ?? "--",
                          unit: "ms",
                          status: snapshot.hrv.map(hrvLabel) ?? "无数据",
                          comparison: "今日恢复参考",
                          dateText: "今天")
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
        snapshot.bloodOxygen = try? await healthManager.fetchTodayBloodOxygen()
        snapshot.wristTemperature = try? await healthManager.fetchLatestWristTemperature()
        snapshot.vo2Max = try? await healthManager.fetchLatestVO2Max()
        snapshot.sleepHeartRate = try? await healthManager.fetchLastNightSleepHeartRate()
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

private struct BodyMetricRow: View {
    let type: DataType
    let title: String
    let value: String
    let unit: String
    let status: String
    let comparison: String
    let dateText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: type.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(type.main)
                        .frame(width: 28, height: 28)
                        .background(type.bg)
                        .clipShape(Circle())
                    Text(title)
                        .font(.gH3)
                        .foregroundColor(.gTextPrimary)
                }
                Spacer()
                Text(dateText)
                    .font(.gBody)
                    .foregroundColor(.gTextSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gTextSecondary)
            }
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value)
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundColor(.gTextPrimary)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text(unit)
                            .font(.gH3)
                            .foregroundColor(.gTextPrimary)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: status == "无数据" ? "questionmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(status == "无数据" ? .gTextSecondary : .gSuccess)
                        Text(status)
                            .font(.gBody)
                            .foregroundColor(status == "无数据" ? .gTextSecondary : .gSuccess)
                    }
                    Text(comparison)
                        .font(.gBody)
                        .foregroundColor(.gTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                MiniTrend(color: type.main, background: type.bg)
                    .frame(width: 132, height: 44)
            }
        }
        .padding(18)
        .background(Color.gSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.gHairline, lineWidth: 1))
        .shadow(color: Color.gTextPrimary.opacity(0.04), radius: 12, x: 0, y: 5)
    }
}

private struct MiniTrend: View {
    let color: Color
    let background: Color

    var body: some View {
        GeometryReader { geo in
            let points: [CGFloat] = [0.35, 0.42, 0.32, 0.50, 0.44, 0.48, 0.40]
            let step = geo.size.width / CGFloat(points.count - 1)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(background.opacity(0.55))
                Path { path in
                    for index in points.indices {
                        let x = CGFloat(index) * step
                        let y = geo.size.height * points[index]
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                ForEach(points.indices, id: \.self) { index in
                    Circle()
                        .fill(index == points.indices.last ? color : Color.gSurface)
                        .overlay(Circle().stroke(color, lineWidth: 3))
                        .frame(width: 12, height: 12)
                        .position(x: CGFloat(index) * step, y: geo.size.height * points[index])
                }
            }
        }
    }
}

private struct BodySnapshot {
    var hrv: Double?
    var sleepHours: Double?
    var sleepStages: (deep: Double, core: Double, rem: Double, awake: Double)?
    var sleepScore: HealthManager.SleepScoreBreakdown?
    var heartRate: Double?
    var bloodOxygen: Double?
    var wristTemperature: Double?
    var vo2Max: Double?
    var sleepHeartRate: Double?
    var updatedAt: Date?
}
