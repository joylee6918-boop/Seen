import SwiftUI
import SwiftData
import Charts

// 趋势页 — 多指标多色趋势图
// 周/月/年 切换, 心情/睡眠/HRV/运动 4 张单项卡.
struct TrendView: View {
    @Query(sort: \DailyMood.date, order: .reverse) private var moods: [DailyMood]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workouts: [WorkoutSession]

    @State private var range: Range = .week

    enum Range: String, CaseIterable {
        case week = "周", month = "月", year = "年"
        var days: Int { self == .week ? 7 : (self == .month ? 30 : 365) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SeenBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        rangePicker
                        moodTrendCard
                        sleepTrendCard
                        hrvTrendCard
                        workoutTrendCard
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("最近的你")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var rangePicker: some View {
        Picker("范围", selection: $range) {
            ForEach(Range.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    private var dateRange: [DailyMood] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -range.days, to: Date())!
        return moods.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    private var workoutRange: [WorkoutSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -range.days, to: Date())!
        return workouts.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    // MARK: - 心情
    private var moodTrendCard: some View {
        let data = dateRange.filter { $0.moodScore > 0 }
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(type: .mood, title: "心情的起伏")
            if !data.isEmpty {
                let avg = Double(data.map(\.moodScore).reduce(0, +)) / Double(data.count)
                Text(moodInsight(data))
                    .font(.gBody).foregroundColor(.gTextPrimary)
                Text("近\(range.rawValue)平均 \(String(format: "%.1f", avg))")
                    .font(.gCaption).foregroundColor(.gTextSecondary)
                Chart(data) { m in
                    LineMark(x: .value("日期", m.date), y: .value("心情", m.moodScore))
                        .foregroundStyle(Color.dMood)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("日期", m.date), y: .value("心情", m.moodScore))
                        .foregroundStyle(Color.dMood)
                }
                .frame(height: 140)
                .chartYScale(domain: 0...10)
                .softChartAxes()
            } else {
                EmptyHint(text: "暂无心情数据")
            }
        }
        .gleanCard()
    }

    // MARK: - 睡眠
    private var sleepTrendCard: some View {
        let data = dateRange.filter { $0.sleepHours != nil }
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(type: .sleep, title: "睡眠节奏")
            if !data.isEmpty {
                let avg = data.compactMap { $0.sleepHours }.reduce(0, +) / Double(data.count)
                Text(sleepInsight(data))
                    .font(.gBody).foregroundColor(.gTextPrimary)
                Text("平均 \(String(format: "%.1f", avg))h")
                    .font(.gCaption).foregroundColor(.gTextSecondary)
                Chart(data) { m in
                    BarMark(x: .value("日期", m.date), y: .value("睡眠", m.sleepHours ?? 0))
                        .foregroundStyle(Color.dSleep.opacity(0.7).gradient)
                        .cornerRadius(3)
                }
                .frame(height: 140)
                .softChartAxes()
            } else {
                EmptyHint(text: "暂无睡眠数据")
            }
        }
        .gleanCard()
    }

    // MARK: - HRV
    private var hrvTrendCard: some View {
        let data = dateRange.filter { $0.hrv != nil }
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(type: .hrv, title: "恢复状态")
            if !data.isEmpty {
                let avg = data.compactMap { $0.hrv }.reduce(0, +) / Double(data.count)
                Text(hrvInsight(avg))
                    .font(.gBody).foregroundColor(.gTextPrimary)
                Text("平均 \(String(format: "%.0f", avg))ms")
                    .font(.gCaption).foregroundColor(.gTextSecondary)
                Chart(data) { m in
                    LineMark(x: .value("日期", m.date), y: .value("HRV", m.hrv ?? 0))
                        .foregroundStyle(Color.dHrv.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("日期", m.date), y: .value("HRV", m.hrv ?? 0))
                        .foregroundStyle(Color.dHrv)
                }
                .frame(height: 140)
                .softChartAxes()
            } else {
                EmptyHint(text: "手表还没把你的心跳交给我")
            }
        }
        .gleanCard()
    }

    // MARK: - 运动
    private var workoutTrendCard: some View {
        let data = workoutRange
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(type: .move, title: "运动节奏")
            if !data.isEmpty {
                let totalMin = data.compactMap { $0.durationMinutes }.reduce(0, +)
                let overTime = data.filter { $0.isOvertime }.count
                Text(moveInsight(totalMin: totalMin, overTime: overTime))
                    .font(.gBody).foregroundColor(.gTextPrimary)
                Text("共\(totalMin)分钟 · 超时\(overTime)次")
                    .font(.gCaption).foregroundColor(.gTextSecondary)
                Chart(data) { w in
                    BarMark(x: .value("日期", w.date), y: .value("时长", w.durationMinutes ?? 0))
                        .foregroundStyle(w.isOvertime ? Color.gWarning.opacity(0.8).gradient : Color.dMove.opacity(0.7).gradient)
                        .cornerRadius(3)
                }
                .frame(height: 140)
                .softChartAxes()
            } else {
                EmptyHint(text: "暂无运动数据")
            }
        }
        .gleanCard()
    }

    private func moodInsight(_ data: [DailyMood]) -> String {
        guard let first = data.first?.moodScore, let last = data.last?.moodScore else {
            return "这一周，我先帮你把心情一点点接住。"
        }
        if last >= first { return "这周你的心情不是一直好，但我看见它在慢慢回来。" }
        return "这周你的情绪有些往下掉，先把要求放轻一点。"
    }

    private func sleepInsight(_ data: [DailyMood]) -> String {
        let hours = data.compactMap(\.sleepHours)
        guard !hours.isEmpty else { return "先把入睡时间守住，睡眠会慢慢稳下来。" }
        let avg = hours.reduce(0, +) / Double(hours.count)
        if avg < 6.5 { return "最近睡眠不太稳定，先守住入睡时间就好。" }
        return "最近睡眠还算撑住了，继续让晚上轻一点。"
    }

    private func hrvInsight(_ avg: Double) -> String {
        if avg < 35 { return "恢复状态偏低，今天适合少消耗一点。" }
        if avg < 50 { return "恢复状态一般，别急着把自己推太满。" }
        return "恢复状态还不错，可以温和地安排一点想做的事。"
    }

    private func moveInsight(totalMin: Int, overTime: Int) -> String {
        if overTime > 0 { return "你已经很努力了，运动后也要给身体留恢复时间。" }
        if totalMin == 0 { return "今天不用追数据，轻轻走一走也算照顾自己。" }
        return "身体有在动起来，保持这个舒服的节奏就好。"
    }
}

private struct SectionHeader: View {
    let type: DataType
    let title: String
    var body: some View {
        HStack(spacing: 8) {
            DataIcon(type: type, size: 28)
            Text(title).font(.gH3)
            Spacer()
        }
    }
}

private struct EmptyHint: View {
    let text: String
    var body: some View {
        Text(text).font(.gCaption).foregroundColor(.gTextSecondary)
            .frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

private extension View {
    func softChartAxes() -> some View {
        self
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6))
                        .foregroundStyle(Color.gHairline)
                    AxisTick(stroke: StrokeStyle(lineWidth: 0.6))
                        .foregroundStyle(Color.gHairline)
                    AxisValueLabel()
                        .foregroundStyle(Color.gTextWeak)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6))
                        .foregroundStyle(Color.gHairline)
                    AxisTick(stroke: StrokeStyle(lineWidth: 0.6))
                        .foregroundStyle(Color.gHairline)
                    AxisValueLabel()
                        .foregroundStyle(Color.gTextWeak)
                }
            }
    }
}
