import SwiftUI
import SwiftData
import UIKit

// 我的页 — 个人区 + 回顾/AI陪伴/数据与安全 分组
struct MoreView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var messageStore: MessageStore
    @Query private var moods: [DailyMood]
    @Query private var habits: [Habit]
    @Query private var inspirations: [Inspiration]
    @Query private var workouts: [WorkoutSession]
    @Query private var checkIns: [CheckIn]
    @AppStorage(CloudSync.baseURLKey) private var cloudBaseURL = ""
    @AppStorage(CloudSync.tokenKey) private var cloudToken = ""
    @AppStorage(CloudSync.uploadsEnabledKey) private var cloudUploadsEnabled = true

    private var cloudConfigured: Bool {
        CloudSync.isConfigured
    }

    @State private var isSyncing = false
    @State private var syncMessage = ""
    @State private var lastManualSyncAt: Date? = nil
    @State private var showAlert = false
    @State private var showExport = false
    @State private var showPrivacy = false

    var body: some View {
        NavigationStack {
            ZStack {
                SeenBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        profileHeader
                        groupReview
                        groupAI
                        groupData
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.large)
            .alert("同步结果", isPresented: $showAlert) {
                Button("好的", role: .cancel) {}
            } message: { Text(syncMessage) }
            .sheet(isPresented: $showExport) { ExportView() }
            .sheet(isPresented: $showPrivacy) { PrivacyView() }
        }
    }

    // MARK: - 个人区
    private var profileHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 56)).foregroundColor(.dAi)
            Text("阿芸").font(.gH2)
            Text("你过日子，我看着你")
                .font(.gCaption).foregroundColor(.gTextSecondary)
            HStack(spacing: 24) {
                StatBadge(value: "\(moods.count)", label: "心情")
                StatBadge(value: "\(workouts.count)", label: "运动")
                StatBadge(value: "\(checkIns.count)", label: "打卡")
                StatBadge(value: "\(inspirations.count)", label: "灵感")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .gleanCard()
    }

    // MARK: - 回顾
    private var groupReview: some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupHeader(title: "回顾")
            NavigationLink {
                CalendarView()
            } label: { Row(icon: "calendar", color: .dMood, title: "月历视图") }
            NavigationLink {
                TrendView()
            } label: { Row(icon: "chart.xyaxis.line", color: .dSleep, title: "趋势统计") }
            NavigationLink {
                WorkoutHistoryView()
            } label: { Row(icon: "dumbbell.fill", color: .dAi, title: "训练记录") }
            NavigationLink {
                RecordView()
            } label: { Row(icon: "plus.circle", color: .dMood, title: "记录此刻") }
        }
        .gleanCard(padding: 0)
    }

    // MARK: - AI 陪伴
    private var groupAI: some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupHeader(title: "AI 陪伴")
            NavigationLink {
                AIView()
            } label: { Row(icon: "sparkles", color: .dAi, title: "关心") }
            Button {
                Task { await syncAll() }
            } label: {
                Row(icon: "arrow.triangle.2.circlepath", color: .dAi,
                    title: "立即同步", trailing: isSyncing ? "正在送过去…" : nil)
            }
            .buttonStyle(.plain)
            NavigationLink {
                InspirationListView()
            } label: { Row(icon: "list.clipboard", color: .dIdea, title: "洞悉") }
        }
        .gleanCard(padding: 0)
    }

    // MARK: - 数据与安全
    private var groupData: some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupHeader(title: "数据与安全")
            Button {
                Task { await syncAll() }
            } label: {
                Row(icon: "icloud.and.arrow.up", color: cloudUploadsEnabled ? .gSuccess : .gTextSecondary,
                    title: "云端同步", trailing: isSyncing ? "正在送过去…" : syncTrailingText)
            }
            .buttonStyle(.plain)
            Button {
                showExport = true
            } label: {
                Row(icon: "square.and.arrow.up", color: .dSleep, title: "导出与备份")
            }
            .buttonStyle(.plain)
            Button {
                showPrivacy = true
            } label: {
                Row(icon: "lock.shield", color: .gWarning, title: "隐私与安全")
            }
            .buttonStyle(.plain)
        }
        .gleanCard(padding: 0)
    }

    // MARK: - 动作
    private func syncAll() async {
        isSyncing = true
        guard cloudUploadsEnabled else {
            isSyncing = false
            syncMessage = "云端上传已关闭。"
            showAlert = true
            return
        }
        guard cloudConfigured else {
            isSyncing = false
            syncMessage = "还没有配置云端 URL 和 token。请到隐私与安全里填写。"
            showAlert = true
            return
        }
        let result = await CloudSync.shared.syncAll(moods: moods, habits: habits, inspirations: inspirations,
                                                    workouts: workouts, checkIns: checkIns)
        await messageStore.syncFromServer()
        lastManualSyncAt = Date()
        isSyncing = false
        let total = moods.count + workouts.count + checkIns.count + inspirations.count + habits.count
        if result.failed == 0 {
            let time = Date().formatted(.dateTime.hour().minute().second())
            syncMessage = "同步完成：\(total) 条数据已上传。\n回信状态已刷新。\n完成时间：\(time)"
        } else {
            let time = Date().formatted(.dateTime.hour().minute().second())
            syncMessage = "同步完成：成功 \(result.succeeded) 条，失败 \(result.failed) 条。\n回信状态已刷新。\n完成时间：\(time)"
        }
        showAlert = true
    }

    private var syncTrailingText: String {
        if !cloudConfigured { return "未配置" }
        if let lastManualSyncAt {
            return "上次 \(lastManualSyncAt.formatted(.dateTime.hour().minute()))"
        }
        return cloudUploadsEnabled ? "已开启" : "已关闭"
    }
}

// MARK: - 训练记录
private struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workouts: [WorkoutSession]

    var body: some View {
        List {
            if workouts.isEmpty {
                ContentUnavailableView("还没有训练记录", systemImage: "dumbbell")
            } else {
                ForEach(workouts) { workout in
                    NavigationLink {
                        WorkoutEditorView(workout: workout)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text("\(workout.type.emoji) \(workout.typeRaw)")
                                    .font(.gBody.weight(.semibold))
                                Spacer()
                                Text(workout.date.formatted(.dateTime.year().month().day()))
                                    .font(.gCaption)
                                    .foregroundColor(.gTextSecondary)
                            }
                            Text(workoutSummary(workout))
                                .font(.gCaption)
                                .foregroundColor(.gTextSecondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        let workout = workouts[index]
                        let id = workout.id
                        modelContext.delete(workout)
                        Task { try? await CloudSync.shared.deleteWorkout(id) }
                    }
                    try? modelContext.save()
                }
            }
        }
        .navigationTitle("训练记录")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func workoutSummary(_ workout: WorkoutSession) -> String {
        let exercises = workout.exercises.map { "\($0.exerciseName) \($0.setCount)组" }.joined(separator: " · ")
        if !exercises.isEmpty { return exercises }
        if let minutes = workout.durationMinutes { return "\(minutes) 分钟" }
        return workout.note ?? "训练已记录"
    }
}

private struct WorkoutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var messageStore: MessageStore
    let workout: WorkoutSession

    @State private var type: WorkoutSession.WorkoutType
    @State private var minutes: String
    @State private var note: String
    @State private var exercises: [ExerciseEntry]

    init(workout: WorkoutSession) {
        self.workout = workout
        _type = State(initialValue: workout.type)
        _minutes = State(initialValue: workout.durationMinutes.map(String.init) ?? "")
        _note = State(initialValue: workout.note ?? "")
        _exercises = State(initialValue: workout.exercises.sorted { $0.order < $1.order })
    }

    var body: some View {
        Form {
            Section("训练") {
                Picker("类型", selection: $type) {
                    ForEach(WorkoutSession.WorkoutType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                TextField("时长（分钟，可留空）", text: $minutes)
                    .keyboardType(.numberPad)
                TextField("训练备注", text: $note, axis: .vertical)
            }
            Section("动作与组数") {
                ForEach(exercises.indices, id: \.self) { index in
                    VStack(alignment: .leading) {
                        TextField("动作名称", text: $exercises[index].exerciseName)
                        Stepper("\(exercises[index].setCount) 组", value: $exercises[index].setCount, in: 1...30)
                        if let reps = exercises[index].reps { Text("\(reps) 次").font(.gCaption).foregroundColor(.gTextSecondary) }
                        if let weight = exercises[index].weightKg { Text("\(weight, specifier: "%.1f") kg").font(.gCaption).foregroundColor(.gTextSecondary) }
                    }
                    .swipeActions {
                        Button(role: .destructive) { exercises.remove(at: index) } label: { Label("删除", systemImage: "trash") }
                    }
                }
                Button("添加动作", systemImage: "plus") {
                    exercises.append(ExerciseEntry(exerciseName: "新动作", setCount: 1, order: exercises.count))
                }
            }
        }
        .navigationTitle("编辑训练")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
            }
        }
    }

    private func save() {
        workout.type = type
        workout.durationMinutes = Int(minutes).flatMap { $0 > 0 ? $0 : nil }
        workout.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
        for index in exercises.indices { exercises[index].order = index }
        workout.exercises = exercises
        workout.recomputeOvertime()
        try? modelContext.save()
        Task {
            if let result = try? await CloudSync.shared.syncWorkout(workout) {
                messageStore.apply(result)
            }
        }
        dismiss()
    }
}

private struct GroupHeader: View {
    let title: String
    var body: some View {
        Text(title).font(.gCaption).foregroundColor(.gTextSecondary)
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)
    }
}

private struct Row: View {
    let icon: String
    let color: Color
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title).font(.gBody).foregroundColor(.gTextPrimary)
            Spacer()
            if let t = trailing {
                Text(t).font(.gCaption).foregroundColor(.gTextSecondary)
            }
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.gTextSecondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .overlay(Divider().frame(maxHeight: 0.5).padding(.leading, 58), alignment: .bottom)
    }
}

private struct StatBadge: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 18, weight: .semibold)).foregroundColor(.gTextPrimary)
            Text(label).font(.gCaption).foregroundColor(.gTextSecondary)
        }
    }
}

// MARK: - 灵感清单子页
struct InspirationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Inspiration.createdAt, order: .reverse) private var inspirations: [Inspiration]
    @EnvironmentObject var messageStore: MessageStore
    @State private var newText = ""
    @State private var selectedPriority: Inspiration.Priority = .normal
    @State private var selectedCategory: Inspiration.Category = .spark
    @State private var showCompleted = false
    @FocusState private var isInputFocused: Bool

    private var pending: [Inspiration] { inspirations.filter { !$0.isCompleted } }
    private var completed: [Inspiration] { inspirations.filter { $0.isCompleted } }
    private func pending(_ category: Inspiration.Category) -> [Inspiration] {
        pending.filter { $0.category == category }
    }

    var body: some View {
        ZStack {
            Color.gBg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    insightHeader
                    inputCard
                    ForEach(Inspiration.Category.allCases, id: \.self) { category in
                        let items = pending(category)
                        if !items.isEmpty {
                            sectionHeader(category.rawValue, count: items.count)
                            ForEach(items) { item in
                                InspirationRow(item: item) { completeItem(item) } onDelete: { deleteItem(item) }
                            }
                        }
                    }
                    if !completed.isEmpty {
                        Button {
                            withAnimation(.spring()) { showCompleted.toggle() }
                        } label: {
                            HStack {
                                sectionHeader("已完成", count: completed.count)
                                Spacer()
                                Image(systemName: showCompleted ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.gTextSecondary).font(.gCaption)
                            }
                        }
                        .buttonStyle(.plain)
                        if showCompleted {
                            ForEach(completed) { item in
                                InspirationRow(item: item) { undoItem(item) } onDelete: { deleteItem(item) }
                            }
                        }
                    }
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 20).padding(.top, 10)
            }
        }
        .navigationTitle("洞悉")
        .navigationBarTitleDisplayMode(.large)
    }

    private var insightHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.dIdea)
                .frame(width: 46, height: 46)
                .background(Color.dIdeaBg)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("洞悉收纳箱")
                    .font(.gH2)
                    .foregroundColor(.gTextPrimary)
                Text("\(pending.count) 条待处理 · \(completed.count) 条已完成")
                    .font(.gCaption)
                    .foregroundColor(.gTextSecondary)
            }
            Spacer()
        }
        .padding(18)
        .background(SeenCardSurface())
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .seenCardElevation()
    }

    private var inputCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                TextField("突然想到…", text: $newText, axis: .vertical)
                    .focused($isInputFocused).lineLimit(1...4).font(.gBody)
                    .padding(12).background(Color.gBg).clipShape(RoundedRectangle(cornerRadius: 14))
                Button {
                    addItem()
                } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 32))
                        .foregroundColor(newText.isEmpty ? .gTextSecondary.opacity(0.3) : .dIdea)
                }
                .disabled(newText.isEmpty)
            }
            HStack(spacing: 8) {
                ForEach(Inspiration.Category.allCases, id: \.self) { c in
                    Button {
                        selectedCategory = c
                    } label: {
                        Label(c.rawValue, systemImage: c.icon)
                            .font(.gCaption)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(selectedCategory == c ? c.color.bg : Color.gSurface)
                            .foregroundColor(selectedCategory == c ? c.color.main : .gTextSecondary)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(selectedCategory == c ? c.color.main.opacity(0.28) : Color.gHairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                ForEach(Inspiration.Priority.allCases, id: \.self) { p in
                    Button {
                        selectedPriority = p
                    } label: {
                        HStack(spacing: 4) {
                            Text(p.emoji); Text(p.rawValue).font(.gCaption)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(selectedPriority == p ? p.backgroundColor : Color.gSurface)
                        .foregroundColor(selectedPriority == p ? p.color : .gTextSecondary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(selectedPriority == p ? p.color.opacity(0.28) : Color.clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(SeenCardSurface())
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .seenCardElevation()
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.gH3).foregroundColor(.gTextPrimary)
            Text("\(count)").font(.gCaption)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Color.dSleepBg).foregroundColor(.dSleep)
                .clipShape(Capsule())
        }
    }

    private func addItem() {
        guard !newText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let item = Inspiration(content: newText.trimmingCharacters(in: .whitespaces), priority: selectedPriority, category: selectedCategory)
        modelContext.insert(item)
        try? modelContext.save()
        Task { if let r = try? await CloudSync.shared.syncInspiration(item) { messageStore.apply(r) } }
        newText = ""; isInputFocused = false
    }
    private func completeItem(_ item: Inspiration) {
        withAnimation(.spring()) {
            item.isCompleted = true; item.completedAt = Date()
            showCompleted = true
        }
        try? modelContext.save()
        Task { if let r = try? await CloudSync.shared.syncInspiration(item) { messageStore.apply(r) } }
    }
    private func undoItem(_ item: Inspiration) {
        item.isCompleted = false; item.completedAt = nil
        try? modelContext.save()
        Task { if let r = try? await CloudSync.shared.syncInspiration(item) { messageStore.apply(r) } }
    }
    private func deleteItem(_ item: Inspiration) {
        Task { try? await CloudSync.shared.deleteInspiration(item.id) }
        modelContext.delete(item)
        try? modelContext.save()
    }
}

private struct InspirationRow: View {
    let item: Inspiration
    let onToggle: () -> Void
    let onDelete: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { onToggle() } label: {
                ZStack {
                    if item.isCompleted {
                        Circle()
                            .fill(item.category.color.main)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .stroke(Color.gHairline, lineWidth: 1.5)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .buttonStyle(.plain).padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.content).font(.gBody)
                    .strikethrough(item.isCompleted, color: .gTextSecondary)
                    .foregroundColor(item.isCompleted ? .gTextSecondary : .gTextPrimary)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Label(item.category.rawValue, systemImage: item.category.icon)
                        .font(.gCaption)
                        .foregroundColor(item.category.color.main)
                    Text(item.priority.emoji + " " + item.priority.rawValue).font(.gCaption).foregroundColor(item.priority.color)
                    Text(item.createdAt.formatted(.dateTime.month().day())).font(.gCaption).foregroundColor(.gTextSecondary)
                }
            }
            Spacer()
        }
        .padding(15)
        .background(SeenCardSurface())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(item.category.color.main.opacity(0.16), lineWidth: 1)
        )
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { onDelete() } label: { Label("删除", systemImage: "trash") }
        }
    }
}

private extension Inspiration.Priority {
    var color: Color {
        switch self {
        case .normal: return .dSleep
        case .important: return .dIdea
        case .urgent: return .dHeart
        }
    }

    var backgroundColor: Color {
        switch self {
        case .normal: return .dSleepBg
        case .important: return .dIdeaBg
        case .urgent: return .dHeartBg
        }
    }
}

// MARK: - 导出与备份
struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var moods: [DailyMood]
    @Query private var workouts: [WorkoutSession]
    @Query private var checkIns: [CheckIn]
    @Query private var habits: [Habit]
    @Query private var inspirations: [Inspiration]
    @State private var exported = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gBg.ignoresSafeArea()
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 60)).foregroundColor(.dSleep)
                    Text("导出与备份").font(.gH2)
                    Text("把你的所有记录导出成 JSON 文件，可以备份到任意位置。")
                        .font(.gBody).foregroundColor(.gTextSecondary)
                        .multilineTextAlignment(.center).padding(.horizontal)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• 心情记录 \(moods.count) 条").font(.gBody)
                        Text("• 运动记录 \(workouts.count) 条").font(.gBody)
                        Text("• 快捷打卡 \(checkIns.count) 条").font(.gBody)
                        Text("• 习惯 \(habits.count) 个").font(.gBody)
                        Text("• 灵感 \(inspirations.count) 条").font(.gBody)
                    }
                    .padding().gleanCard()
                    Button {
                        exportJSON()
                    } label: {
                        Text("导出 JSON").font(.gH3).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.dSleep).clipShape(Capsule())
                    }
                    .buttonStyle(.plain).padding(.horizontal)
                    if exported {
                        Text("已复制到剪贴板").font(.gCaption).foregroundColor(.gSuccess)
                    }
                    Spacer()
                }
            }
        .navigationTitle("导出与备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
    }

    private func exportJSON() {
        var dict: [String: Any] = [:]
        let fmt = ISO8601DateFormatter()
        dict["exportedAt"] = fmt.string(from: Date())
        dict["moods"] = moods.map { mood in
            var item: [String: Any] = [
                "id": mood.id.uuidString,
                "date": fmt.string(from: mood.date),
                "moodScore": mood.moodScore,
                "weather": mood.weatherRaw,
                "tags": mood.tags
            ]
            if let scent = mood.bodyScent { item["bodyScent"] = scent }
            if let hrv = mood.hrv { item["hrv"] = hrv }
            if let hours = mood.sleepHours { item["sleepHours"] = hours }
            if let quality = mood.sleepQuality { item["sleepQuality"] = quality }
            if let note = mood.note { item["note"] = note }
            if let photo = mood.photo { item["photoBase64"] = photo.base64EncodedString() }
            return item
        }
        dict["workouts"] = workouts.map { workout in
            var item: [String: Any] = [
                "id": workout.id.uuidString,
                "date": fmt.string(from: workout.date),
                "type": workout.typeRaw,
                "source": workout.sourceRaw,
                "isOvertime": workout.isOvertime,
                "exercises": workout.exercises.map { entry in
                    var entryDict: [String: Any] = [
                        "id": entry.id.uuidString,
                        "name": entry.exerciseName,
                        "sets": entry.setCount,
                        "order": entry.order
                    ]
                    if let reps = entry.reps { entryDict["reps"] = reps }
                    if let weight = entry.weightKg { entryDict["weightKg"] = weight }
                    return entryDict
                }
            ]
            if let externalId = workout.externalId { item["externalId"] = externalId }
            if let minutes = workout.durationMinutes { item["durationMinutes"] = minutes }
            if let kcal = workout.activeEnergyKcal { item["activeEnergyKcal"] = kcal }
            if let hr = workout.averageHeartRate { item["averageHeartRate"] = hr }
            if let note = workout.note { item["note"] = note }
            return item
        }
        dict["checkIns"] = checkIns.map { checkIn in
            var item: [String: Any] = [
                "id": checkIn.id.uuidString,
                "type": checkIn.typeRaw,
                "value": checkIn.value,
                "ts": fmt.string(from: checkIn.ts)
            ]
            if let note = checkIn.note { item["note"] = note }
            return item
        }
        dict["habits"] = habits.map { habit in
            [
                "id": habit.id.uuidString,
                "name": habit.name,
                "emoji": habit.emoji,
                "targetDays": habit.targetDays,
                "records": habit.records.map { fmt.string(from: $0) },
                "createdAt": fmt.string(from: habit.createdAt)
            ] as [String: Any]
        }
        dict["inspirations"] = inspirations.map { item in
            var exported: [String: Any] = [
                "id": item.id.uuidString,
                "content": item.content,
                "isCompleted": item.isCompleted,
                "createdAt": fmt.string(from: item.createdAt),
                "priority": item.priorityRaw,
                "category": item.categoryRaw
            ]
            if let completedAt = item.completedAt { exported["completedAt"] = fmt.string(from: completedAt) }
            return exported
        }
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            UIPasteboard.general.string = str
            exported = true
        }
    }
}

// MARK: - 隐私与安全
struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(CloudSync.baseURLKey) private var cloudBaseURL = ""
    @AppStorage(CloudSync.tokenKey) private var cloudToken = ""
    @AppStorage(CloudSync.uploadsEnabledKey) private var cloudUploadsEnabled = true
    @State private var appLock = false
    @State private var biometricEnabled = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gBg.ignoresSafeArea()
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        GroupHeader(title: "数据安全")
                        Toggle(isOn: $appLock) {
                            Label("应用锁 (Face ID)", systemImage: "faceid")
                                .font(.gBody)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        Divider().padding(.leading, 16)
                        Toggle(isOn: $biometricEnabled) {
                            Label("生物识别解锁", systemImage: "touchid")
                                .font(.gBody)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        Divider().padding(.leading, 16)
                        Toggle(isOn: $cloudUploadsEnabled) {
                            Label("云端上传", systemImage: "icloud.and.arrow.up")
                                .font(.gBody)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                    .gleanCard(padding: 0)

                    VStack(alignment: .leading, spacing: 10) {
                        GroupHeader(title: "云端配置")
                        TextField("https://example.com/purr", text: $cloudBaseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .font(.gBody)
                            .padding(12)
                            .background(Color.gBg)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        SecureField("Bearer token", text: $cloudToken)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.gBody)
                            .padding(12)
                            .background(Color.gBg)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        if CloudSync.isConfigured {
                            Divider()
                            Text("快捷指令配置")
                                .font(.gCaption)
                                .foregroundColor(.gTextSecondary)
                            Button {
                                UIPasteboard.general.string = CloudSync.shortcutRecordsURL
                            } label: {
                                Label("复制 /records 地址", systemImage: "link")
                                    .font(.gBody)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Button {
                                UIPasteboard.general.string = CloudSync.shortcutAuthorization
                            } label: {
                                Label("复制快捷指令鉴权", systemImage: "key.fill")
                                    .font(.gBody)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Text("复制后直接粘贴到快捷指令；鉴权内容请勿分享。")
                                .font(.gCaption)
                                .foregroundColor(.gTextSecondary)
                        }
                    }
                    .gleanCard()

                    VStack(alignment: .leading, spacing: 8) {
                        GroupHeader(title: "数据存储说明")
                        Text("• 所有数据存储在你本机 SwiftData + 硅谷 VPS")
                            .font(.gBody).foregroundColor(.gTextSecondary)
                        Text("• 今日 HealthKit 摘要会上传给 AI 读取")
                            .font(.gBody).foregroundColor(.gTextSecondary)
                        Text("• 手动记录 (心情/打卡/灵感/运动) 会推送到云端")
                            .font(.gBody).foregroundColor(.gTextSecondary)
                        Text("• 关闭云端上传后，不再推送新增/删除数据")
                            .font(.gBody).foregroundColor(.gTextSecondary)
                        Text("• 云端 URL/token 只保存在本机，不写进源码")
                            .font(.gBody).foregroundColor(.gTextSecondary)
                    }
                    .gleanCard()
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.top, 10)
            }
            .navigationTitle("隐私与安全")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
    }
}
