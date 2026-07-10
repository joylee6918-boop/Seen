import SwiftUI
import SwiftData
import Charts

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyMood.date, order: .reverse) private var moods: [DailyMood]
    @Query(sort: \CheckIn.ts, order: .reverse) private var checkIns: [CheckIn]

    @State private var selectedMonth = Date()
    @State private var selectedMood: DailyMood?

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ZStack {
                SeenBackground()

                ScrollView {
                    VStack(spacing: 20) {

                        // 月份选择器
                        monthPicker

                        // 月历网格
                        monthGrid

                        // 本月统计
                        if !currentMonthMoods.isEmpty {
                            monthStats
                        }

                        // HRV 趋势图
                        if !currentMonthMoods.isEmpty && currentMonthMoods.contains(where: { $0.hrv != nil }) {
                            hrvChart
                        }

                        // 睡眠趋势图
                        if !currentMonthMoods.isEmpty && currentMonthMoods.contains(where: { $0.sleepHours != nil }) {
                            sleepChart
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
            .navigationTitle("月历回顾")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedMood) { mood in
                RecordView(editingMood: mood)
            }
        }
    }

    // MARK: - 月份选择器
    private var monthPicker: some View {
        HStack {
            Button {
                withAnimation { selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth)! }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.dAi)
            }

            Spacer()

            Text(selectedMonth.formatted(.dateTime.year().month(.wide)))
                .font(.title2.bold())

            Spacer()

            Button {
                withAnimation { selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth)! }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.dAi)
            }
            .disabled(calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(SeenCardSurface())
        .cornerRadius(16)
        .seenCardElevation()
    }

    // MARK: - 月历网格
    private var monthGrid: some View {
        VStack(spacing: 8) {
            // 星期标题
            HStack(spacing: 0) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .foregroundColor(.gTextSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 日期网格
            let days = daysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        DayCell(date: date, mood: moodFor(date: date), checkInCount: checkInCount(for: date))
                            .onTapGesture {
                                if let mood = moodFor(date: date) {
                                    selectedMood = mood
                                }
                            }
                    } else {
                        Color.clear
                            .frame(height: 50)
                    }
                }
            }
        }
        .padding(16)
        .background(SeenCardSurface())
        .cornerRadius(18)
        .seenCardElevation()
    }

    // MARK: - 本月统计
    private var monthStats: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("本月统计")
                .font(.headline)

            HStack(spacing: 16) {
                StatCard(
                    icon: "📝",
                    label: "记录天数",
                    value: "\(currentMonthMoods.count)",
                    color: .dMood
                )

                StatCard(
                    icon: "😊",
                    label: "平均心情",
                    value: String(format: "%.1f", averageMood),
                    color: .dHrv
                )

                if let avgHRV = averageHRV {
                    StatCard(
                        icon: "❤️",
                        label: "平均HRV",
                        value: String(format: "%.0f", avgHRV),
                        color: .dHrv
                    )
                }
            }
        }
        .padding(16)
        .background(SeenCardSurface())
        .cornerRadius(18)
        .seenCardElevation()
    }

    // MARK: - 睡眠趋势图
    private var sleepChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("睡眠趋势")
                .font(.headline)

            let data = currentMonthMoods
                .filter { $0.sleepHours != nil }
                .sorted { $0.date < $1.date }

            Chart(data) { mood in
                BarMark(
                    x: .value("日期", mood.date),
                    y: .value("睡眠", mood.sleepHours ?? 0)
                )
                .foregroundStyle(Color.dSleep.opacity(0.7).gradient)
                .cornerRadius(4)
            }
            .frame(height: 160)
            .chartYAxis {
                AxisMarks(values: [0, 4, 6, 8, 10]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let h = value.as(Double.self) {
                            Text("\(Int(h))h")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day(), centered: true)
                }
            }
        }
        .padding(16)
        .background(SeenCardSurface())
        .cornerRadius(18)
        .seenCardElevation()
    }

    // MARK: - HRV 趋势图
    private var hrvChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HRV 趋势")
                .font(.headline)

            let data = currentMonthMoods
                .filter { $0.hrv != nil }
                .sorted { $0.date < $1.date }

            Chart(data) { mood in
                LineMark(
                    x: .value("日期", mood.date),
                    y: .value("HRV", mood.hrv ?? 0)
                )
                .foregroundStyle(Color.dHrv.gradient)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("日期", mood.date),
                    y: .value("HRV", mood.hrv ?? 0)
                )
                .foregroundStyle(Color.dHrv)
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day(), centered: true)
                }
            }
        }
        .padding(16)
        .background(SeenCardSurface())
        .cornerRadius(18)
        .seenCardElevation()
    }

    // MARK: - 辅助方法
    private var currentMonthMoods: [DailyMood] {
        moods.filter { calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
    }

    private var averageMood: Double {
        let scored = currentMonthMoods.filter { $0.moodScore > 0 }
        guard !scored.isEmpty else { return 0 }
        return Double(scored.map { $0.moodScore }.reduce(0, +)) / Double(scored.count)
    }

    private var averageHRV: Double? {
        let hrvs = currentMonthMoods.compactMap { $0.hrv }
        guard !hrvs.isEmpty else { return nil }
        return hrvs.reduce(0, +) / Double(hrvs.count)
    }

    private func daysInMonth() -> [Date?] {
        let interval = calendar.dateInterval(of: .month, for: selectedMonth)!
        let firstDay = interval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1

        var days: [Date?] = Array(repeating: nil, count: firstWeekday)

        var current = firstDay
        while calendar.isDate(current, equalTo: selectedMonth, toGranularity: .month) {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        return days
    }

    private func moodFor(date: Date) -> DailyMood? {
        moods.first { calendar.isDate($0.date, inSameDayAs: date) && $0.moodScore > 0 }
    }

    private func checkInCount(for date: Date) -> Int {
        checkIns.filter { calendar.isDate($0.ts, inSameDayAs: date) }.count
    }
}

// MARK: - 日期单元格
struct DayCell: View {
    let date: Date
    let mood: DailyMood?
    let checkInCount: Int

    var body: some View {
        VStack(spacing: 2) {
            Text(date.formatted(.dateTime.day()))
                .font(.caption2)
                .foregroundColor(Calendar.current.isDateInToday(date) ? .dAi : .gTextPrimary)

            if let mood = mood {
                Circle().fill(moodColor(mood.moodScore)).frame(width: 6, height: 6)
            } else if checkInCount > 0 {
                Circle().fill(Color.dHabit).frame(width: 6, height: 6)
            } else {
                Circle().fill(Color.gHairline).frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(mood != nil ? moodColor(mood!.moodScore).opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Calendar.current.isDateInToday(date) ? Color.dAi : Color.clear, lineWidth: 1.5)
        )
    }

    private func moodColor(_ score: Int) -> Color {
        switch score {
        case 1...3: return .dHrv
        case 4...5: return .dHabit
        case 6...7: return .dSleep
        case 8...10: return .dMood
        default: return .gHairline
        }
    }
}

// MARK: - 统计卡片
struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(icon)
                .font(.title2)
            Text(value)
                .font(.title3.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
}
