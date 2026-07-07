import SwiftUI
import SwiftData

// 我的页 — 个人区 + 回顾/AI陪伴/数据与安全 分组
struct MoreView: View {
    @Environment(\.modelContext) private var modelContext
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
    @State private var showAlert = false
    @State private var showExport = false
    @State private var showPrivacy = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gBg.ignoresSafeArea()
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
            Text("记录生活，遇见更好的自己")
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
        }
        .gleanCard(padding: 0)
    }

    // MARK: - AI 陪伴
    private var groupAI: some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupHeader(title: "AI 陪伴")
            NavigationLink {
                AIView()
            } label: { Row(icon: "sparkles", color: .dAi, title: "回信") }
            Button {
                Task { await syncAll() }
            } label: {
                Row(icon: "arrow.triangle.2.circlepath", color: .dAi,
                    title: "立即同步", trailing: isSyncing ? "同步中..." : nil)
            }
            .buttonStyle(.plain)
            NavigationLink {
                InspirationListView()
            } label: { Row(icon: "list.clipboard", color: .dIdea, title: "灵感管理") }
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
                    title: "云端同步", trailing: isSyncing ? "同步中..." : syncTrailingText)
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
        isSyncing = false
        let total = moods.count + workouts.count + checkIns.count + inspirations.count + habits.count
        if result.failed == 0 {
            syncMessage = "同步完成：\(total) 条数据已上传。"
        } else {
            syncMessage = "同步完成：成功 \(result.succeeded) 条，失败 \(result.failed) 条。请稍后重试。"
        }
        showAlert = true
    }

    private var syncTrailingText: String {
        if !cloudConfigured { return "未配置" }
        return cloudUploadsEnabled ? "已开启" : "已关闭"
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
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
                .frame(width: 24)
            Text(title).font(.gBody).foregroundColor(.gTextPrimary)
            Spacer()
            if let t = trailing {
                Text(t).font(.gCaption).foregroundColor(.gTextSecondary)
            }
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.gTextSecondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .overlay(Divider().frame(maxHeight: 0.5).padding(.leading, 48), alignment: .bottom)
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
    @State private var showCompleted = false
    @FocusState private var isInputFocused: Bool

    private var pending: [Inspiration] { inspirations.filter { !$0.isCompleted } }
    private var completed: [Inspiration] { inspirations.filter { $0.isCompleted } }

    var body: some View {
        ZStack {
            Color.gBg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    inputCard
                    if !pending.isEmpty {
                        sectionHeader("还没做", count: pending.count)
                        ForEach(pending) { item in
                            InspirationRow(item: item) { completeItem(item) } onDelete: { deleteItem(item) }
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
        .navigationTitle("灵感清单")
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                TextField("突然想到…", text: $newText, axis: .vertical)
                    .focused($isInputFocused).lineLimit(1...4).font(.gBody)
                    .padding(12).background(Color.gSurface).clipShape(RoundedRectangle(cornerRadius: 12))
                Button {
                    addItem()
                } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 32))
                        .foregroundColor(newText.isEmpty ? .gTextSecondary.opacity(0.3) : .dIdea)
                }
                .disabled(newText.isEmpty)
            }
            HStack(spacing: 8) {
                ForEach(Inspiration.Priority.allCases, id: \.self) { p in
                    Button {
                        selectedPriority = p
                    } label: {
                        HStack(spacing: 4) {
                            Text(p.emoji); Text(p.rawValue).font(.gCaption)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(selectedPriority == p ? Color.dIdeaBg : Color.gSurface)
                        .foregroundColor(selectedPriority == p ? .dIdea : .gTextSecondary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(selectedPriority == p ? Color.dIdea : Color.clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
        .gleanCard()
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.gH3).foregroundColor(.gTextPrimary)
            Text("\(count)").font(.gCaption)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Color.dIdeaBg).foregroundColor(.dIdea)
                .clipShape(Capsule())
        }
    }

    private func addItem() {
        guard !newText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let item = Inspiration(content: newText.trimmingCharacters(in: .whitespaces), priority: selectedPriority)
        modelContext.insert(item)
        try? modelContext.save()
        Task { if let r = try? await CloudSync.shared.syncInspiration(item) { messageStore.apply(r) } }
        newText = ""; isInputFocused = false
    }
    private func completeItem(_ item: Inspiration) {
        item.isCompleted = true; item.completedAt = Date()
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
                    Circle().stroke(item.isCompleted ? Color.dIdea : Color.gHairline, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    if item.isCompleted {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.dIdea)
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
                    Text(item.priority.emoji + " " + item.priority.rawValue).font(.gCaption).foregroundColor(.gTextSecondary)
                    Text(item.createdAt.formatted(.dateTime.month().day())).font(.gCaption).foregroundColor(.gTextSecondary)
                }
            }
            Spacer()
        }
        .padding(14).background(Color.gSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gHairline, lineWidth: 1))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { onDelete() } label: { Label("删除", systemImage: "trash") }
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
                "priority": item.priorityRaw
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
