import SwiftUI
import SwiftData
import PhotosUI

// "记录此刻" — 重录入页, 也能编辑已有 mood.
// 心情(1-10+天气+标签+气味+照片) / 睡眠 / HRV / 运动(类型+时长+动作详情) / 习惯(勾选+添加+7天历史) / 想法.
struct RecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    enum Field { case sleep, hrv, note, scent, workoutMin, workoutNote, tagInput }

    @Query private var habits: [Habit]
    @Query(sort: \CheckIn.ts, order: .reverse) private var checkIns: [CheckIn]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workouts: [WorkoutSession]
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var messageStore: MessageStore

    // 编辑已有 mood 时传入; 新建时 nil
    var editingMood: DailyMood? = nil

    @State private var moodScore: Int = 5
    @State private var weather: DailyMood.Weather = .sunny
    @State private var sleepHoursText: String = ""
    @State private var sleepQuality: String = "良好"
    @State private var hrvText: String = ""
    @State private var bodyScent: String = ""
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var noteText: String = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil

    @State private var workoutType: WorkoutSession.WorkoutType = .strength
    @State private var workoutMinutesText: String = ""
    @State private var exercises: [ExerciseEntry] = []
    @State private var workoutNote: String = ""
    @State private var showExercisePicker = false

    @State private var habitTicks: [UUID: Bool] = [:]
    @State private var showAddHabit = false

    @State private var periodEntryDate: Date = Date()
    @State private var periodFlow: String = "中"
    @State private var periodSymptoms: Set<String> = []
    @State private var periodNote: String = ""

    @State private var saving = false
    @State private var savedTick: String? = nil

    private let sleepQualities = ["一般", "良好", "很好"]
    private let presetTags = ["疲惫", "轻盈", "充满能量", "焦虑", "平静", "开心", "难过", "专注", "发呆", "充实"]
    private var todayHabits: [Habit] {
        let weekday = Calendar.current.component(.weekday, from: Date()) - 1
        return habits.filter { $0.targetDays.contains(weekday) }
    }
    private var allTags: [String] {
        let custom = tags.filter { !presetTags.contains($0) }
        return presetTags + custom
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SeenBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        dateHeader
                        moodSection
                        weatherSection
                        tagsSection
                        scentSection
                        sleepSection
                        hrvSection
                        workoutSection
                        periodSection
                        if !todayHabits.isEmpty { habitSection }
                        noteSection
                        photoSection
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                if let tick = savedTick {
                    VStack {
                        Spacer()
                        HStack(alignment: .top, spacing: 8) {
                            Rectangle()
                                .fill(Color.dAi.opacity(0.7))
                                .frame(width: 2, height: 38)
                                .clipShape(Capsule())
                            Text(tick)
                                .font(.gBody)
                                .foregroundColor(.gTextPrimary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gCompanionSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gHairline, lineWidth: 1))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 92)
                        .transition(.opacity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: savedTick)
            .navigationTitle(editingMood == nil ? "记录" : "编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { Task { await save() } }
                        .disabled(saving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { dismissKeyboard() }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { name in
                    exercises.append(ExerciseEntry(exerciseName: name, order: exercises.count))
                    showExercisePicker = false
                }
            }
            .sheet(isPresented: $showAddHabit) {
                AddHabitView()
            }
            .onAppear { loadExisting() }
        }
    }

    // MARK: - 日期头
    private var dateHeader: some View {
        Text(Date().formatted(.dateTime.month().day().weekday()))
            .font(.gCaption).foregroundColor(.gTextSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 心情
    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(type: .mood, title: "现在心情几分？")
            HStack(spacing: 0) {
                ForEach(1...10, id: \.self) { i in
                    Button {
                        moodScore = i
                    } label: {
                        Text("\(i)")
                            .font(.system(size: 14, weight: moodScore == i ? .bold : .regular))
                            .frame(width: 28, height: 36)
                            .foregroundColor(moodScore == i ? .white : .gTextSecondary)
                            .background(moodScore == i ? Color.dMood : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    if i != 10 { Spacer(minLength: 0) }
                }
            }
            Text(moodLabel(moodScore))
                .font(.gCaption).foregroundColor(.dMood)
        }
        .nativeGroup()
    }

    // MARK: - 天气
    private var weatherSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(type: .mood, title: "今天天气")
            Picker("天气", selection: $weather) {
                ForEach(DailyMood.Weather.allCases, id: \.self) { w in
                    Text("\(w.emoji) \(String(w.rawValue.dropFirst(3)))").tag(w)
                }
            }
            .pickerStyle(.segmented)
        }
        .nativeGroup()
    }

    // MARK: - 标签
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(type: .mood, title: "身体哪里在提醒你？")
            FlowLayout(spacing: 8) {
                ForEach(allTags, id: \.self) { tag in
                    tagButton(tag)
                }
            }
            HStack {
                TextField("添加自定义标签", text: $newTag).font(.gBody)
                Button {
                    let t = newTag.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty, !tags.contains(t) else { return }
                    tags.append(t); newTag = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(newTag.isEmpty ? .gTextSecondary.opacity(0.3) : .dMood)
                }
                .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(10).background(Color.gBg).clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .nativeGroup()
    }

    @ViewBuilder
    private func tagButton(_ tag: String) -> some View {
        let isSelected = tags.contains(tag)
        let isCustom = !presetTags.contains(tag)
        Button {
            if isCustom { tags.removeAll { $0 == tag } }
            else { toggleTag(tag) }
        } label: {
            HStack(spacing: 4) {
                Text(tag).font(.gBody)
                if isCustom { Image(systemName: "xmark").font(.gCaption) }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(isSelected ? Color.dMoodBg : Color.gBg)
            .foregroundColor(isSelected ? .dMood : .gTextPrimary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.dMood : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 气味
    private var scentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(type: .mood, title: "今天有什么气味？")
            TextField("今天自己闻起来是什么感觉？", text: $bodyScent, axis: .vertical)
                .font(.gBody).lineLimit(1...3)
                .padding(10).background(Color.gBg).clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .nativeGroup()
    }

    // MARK: - 睡眠
    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(type: .sleep, title: "睡眠")
            HStack {
                TextField("时长 (h)", text: $sleepHoursText)
                    .keyboardType(.decimalPad).frame(width: 80)
                Spacer()
                Picker("质量", selection: $sleepQuality) {
                    ForEach(sleepQualities, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 200)
            }
        }
        .nativeGroup()
    }

    // MARK: - HRV
    private var hrvSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(type: .hrv, title: "HRV / 恢复")
            HStack {
                TextField("ms", text: $hrvText)
                    .keyboardType(.numberPad).frame(width: 80)
                Spacer()
                Button("从 HealthKit 拉取") {
                    Task {
                        if let v = try? await healthManager.fetchTodayHRV() {
                            hrvText = String(format: "%.0f", v)
                        }
                    }
                }
                .font(.gCaption).foregroundColor(.dHrv)
            }
        }
        .nativeGroup()
    }

    // MARK: - 运动 (含动作详情)
    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(type: .move, title: "运动")
            Picker("类型", selection: $workoutType) {
                ForEach(WorkoutSession.WorkoutType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            HStack {
                TextField("时长 (分钟)", text: $workoutMinutesText)
                    .keyboardType(.numberPad).frame(width: 120)
                Spacer()
                if let m = Int(workoutMinutesText), m > 0 {
                    StatusPill(text: m > 40 ? "超时" : "达标", kind: m > 40 ? .warning : .success)
                }
            }
            Divider().background(Color.gHairline)
            // 动作详情
            HStack {
                Text("动作记录").font(.gCaption).foregroundColor(.gTextSecondary)
                Spacer()
                Button {
                    showExercisePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus"); Text("添加动作")
                    }
                    .font(.gCaption).foregroundColor(.dMove)
                }
            }
            if !exercises.isEmpty {
                ForEach($exercises) { $entry in
                    ExerciseEntryRow(entry: $entry, onDelete: {
                        exercises.removeAll { $0.id == entry.id }
                    })
                }
            }
            TextField("训练备注", text: $workoutNote, axis: .vertical)
                .font(.gBody).lineLimit(1...3)
                .padding(10).background(Color.gBg).clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .nativeGroup()
    }

    // MARK: - 经期
    // 每天可记一条: 日期(可补前面的天数) + 流量 + 症状 + 备注.
    // 天数从"最近一个未结束的来潮起点"算, 选历史日期会自动按那天计入周期.
    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(type: .period, title: "经期记录")
                Spacer()
                if let d = currentPeriodDay {
                    Text("第 \(d) 天").font(.gCaption.bold()).foregroundColor(.dMood)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.dMoodBg).clipShape(Capsule())
                }
            }

            // 日期 — 默认今天, 可以往前选, 用来补记
            HStack(spacing: 10) {
                Text("日期").font(.gCaption).foregroundColor(.gTextSecondary).frame(width: 36, alignment: .leading)
                DatePicker("", selection: $periodEntryDate, displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                Spacer()
            }

            // 流量
            HStack(spacing: 8) {
                Text("流量").font(.gCaption).foregroundColor(.gTextSecondary).frame(width: 36, alignment: .leading)
                ForEach(["轻", "中", "重", "无"], id: \.self) { v in
                    Button {
                        periodFlow = v
                    } label: {
                        Text(v).font(.gBody)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(periodFlow == v ? Color.dMood : Color.gBg)
                            .foregroundColor(periodFlow == v ? .white : .gTextPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(periodFlow == v ? Color.clear : Color.gHairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            // 症状
            VStack(alignment: .leading, spacing: 8) {
                Text("症状").font(.gCaption).foregroundColor(.gTextSecondary)
                FlowLayout(spacing: 8) {
                    ForEach(periodSymptomOptions, id: \.self) { s in
                        let on = periodSymptoms.contains(s)
                        Button {
                            if on { periodSymptoms.remove(s) } else { periodSymptoms.insert(s) }
                        } label: {
                            Text(s).font(.gBody)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(on ? Color.dMoodBg : Color.gBg)
                                .foregroundColor(on ? .dMood : .gTextPrimary)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(on ? Color.dMood : Color.clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 备注
            TextField("备注（用药/情绪/其他）", text: $periodNote, axis: .vertical)
                .font(.gBody).lineLimit(1...3)
                .padding(10).background(Color.gBg).clipShape(RoundedRectangle(cornerRadius: 10))

            // 保存 + 结束本期
            HStack(spacing: 10) {
                Button {
                    savePeriod()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text(periodFlow == "无" ? "记这条" : "记录")
                    }
                    .font(.gCaption).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.dMood).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                if currentPeriodDay != nil {
                    Button {
                        endPeriod()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle")
                            Text("结束本期")
                        }
                        .font(.gCaption).foregroundColor(.dMood)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color.dMoodBg).clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dMood.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            // 本期已记录的条目
            if !currentPeriodEntries.isEmpty {
                Divider().background(Color.gHairline)
                VStack(alignment: .leading, spacing: 6) {
                    Text("本期记录").font(.gCaption).foregroundColor(.gTextSecondary)
                    ForEach(currentPeriodEntries) { c in
                        HStack {
                            Text(c.ts.formatted(.dateTime.month().day())).font(.gCaption)
                            if !c.value.isEmpty {
                                Text("·\(c.value)").font(.gCaption).foregroundColor(.dMood)
                            }
                            if let n = c.note, !n.isEmpty {
                                Text("·\(n)").font(.gCaption).foregroundColor(.gTextSecondary).lineLimit(1)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .nativeGroup()
    }

    // MARK: - 习惯
    private var habitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(type: .habit, title: "今日习惯")
                Spacer()
                Button {
                    showAddHabit = true
                } label: {
                    Image(systemName: "plus.circle").font(.gBody).foregroundColor(.dHabit)
                }
            }
            ForEach(todayHabits) { h in
                VStack(spacing: 6) {
                    HStack {
                        Text("\(h.emoji) \(h.name)").font(.gBody)
                        Spacer()
                        Image(systemName: habitTicks[h.id, default: false] ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(habitTicks[h.id, default: false] ? .dHabit : .gTextSecondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { habitTicks[h.id, default: false].toggle() }
                    // 7天历史
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { offset in
                            let d = Calendar.current.date(byAdding: .day, value: -6 + offset, to: Date())!
                            let done = h.isCompletedOn(d)
                            VStack(spacing: 2) {
                                Text(d.formatted(.dateTime.weekday(.narrow)))
                                    .font(.system(size: 9)).foregroundColor(.gTextSecondary)
                                Circle().fill(done ? Color.dHabit : Color.gHairline)
                                    .frame(width: 6, height: 6)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .nativeGroup()
    }

    // MARK: - 想法
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(type: .idea, title: "想补一句吗？")
            TextEditor(text: $noteText)
                .frame(minHeight: 80)
                .padding(8).background(Color.gBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gHairline, lineWidth: 1))
            HStack { Spacer(); Text("\(noteText.count)").font(.gCaption).foregroundColor(.gTextSecondary) }
        }
        .nativeGroup()
    }

    // MARK: - 照片
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(type: .mood, title: "今日一照")
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text(photoData == nil ? "选一张代表今天的照片" : "换一张照片")
                }
                .font(.gBody).foregroundColor(.dMood)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Color.dMoodBg).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if let data = photoData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(maxWidth: .infinity).frame(height: 160).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .nativeGroup()
    }

    // MARK: - 保存
    private func savePeriod() {
        // 同一天同流量重复记就跳过 (避免误触)
        let day = Calendar.current.startOfDay(for: periodEntryDate)
        if checkIns.contains(where: { $0.kind == .period
            && Calendar.current.isDate($0.ts, inSameDayAs: day)
            && $0.value == periodFlow }) {
            return
        }
        // note 里拼症状 + 自由备注
        var noteParts: [String] = []
        if !periodSymptoms.isEmpty { noteParts.append(periodSymptoms.sorted().joined(separator: " ")) }
        if !periodNote.isEmpty { noteParts.append(periodNote) }
        let c = CheckIn(kind: .period, value: periodFlow, note: noteParts.isEmpty ? nil : noteParts.joined(separator: "｜"), ts: periodEntryDate)
        modelContext.insert(c)
        try? modelContext.save()
        Task {
            if let r = try? await CloudSync.shared.syncCheckIn(c) {
                messageStore.apply(r)
            }
        }
        savedTick = "经期已记录"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { if savedTick == "经期已记录" { savedTick = nil } }
        periodSymptoms.removeAll()
        periodNote = ""
    }

    private func endPeriod() {
        let c = CheckIn(kind: .period, value: "结束", note: nil, ts: Date())
        modelContext.insert(c)
        try? modelContext.save()
        Task {
            if let r = try? await CloudSync.shared.syncCheckIn(c) {
                messageStore.apply(r)
            }
        }
        savedTick = "本期已结束"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { if savedTick == "本期已结束" { savedTick = nil } }
    }

    private var periodSymptomOptions: [String] {
        ["痛经", "胸胀", "腰酸", "头痛", "疲劳", "情绪波动", "腹胀", "失眠"]
    }

    // 当前经期第几天 (跟 TodayView/AIView 同算法)
    private var currentPeriodDay: Int? {
        let today = Calendar.current.startOfDay(for: Date())
        var start: Date? = nil
        for c in checkIns.sorted(by: { $0.ts < $1.ts }) where c.kind == .period {
            if c.value == "结束" { start = nil }
            else if c.value != "无" {
                if let s = start {
                    let gap = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: s), to: Calendar.current.startOfDay(for: c.ts)).day ?? 0
                    if gap > 7 { start = c.ts }
                } else {
                    start = c.ts
                }
            }
        }
        guard let s = start else { return nil }
        let gap = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: s), to: today).day ?? 0
        if gap < 0 || gap > 7 { return nil }
        return gap + 1
    }

    // 当前这一期的经期打卡 (从起点到现在)
    private var currentPeriodEntries: [CheckIn] {
        var start: Date? = nil
        for c in checkIns.sorted(by: { $0.ts < $1.ts }) where c.kind == .period {
            if c.value == "结束" { start = nil }
            else if c.value != "无" {
                if let s = start {
                    let gap = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: s), to: Calendar.current.startOfDay(for: c.ts)).day ?? 0
                    if gap > 7 { start = c.ts }
                } else {
                    start = c.ts
                }
            }
        }
        guard let s = start else { return [] }
        return checkIns.filter { $0.kind == .period && $0.ts >= s }.sorted { $0.ts > $1.ts }
    }

    private func save() async {
        saving = true
        let today = Calendar.current.startOfDay(for: Date())
        let mood: DailyMood
        if let existing = editingMood {
            mood = existing
        } else if let existing = (try? modelContext.fetch(FetchDescriptor<DailyMood>()))?
            .first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            mood = existing
        } else {
            mood = DailyMood(date: today)
            modelContext.insert(mood)
        }
        mood.moodScore = moodScore
        mood.weather = weather
        if let h = Double(sleepHoursText) { mood.sleepHours = h }
        mood.sleepQuality = Int(sleepQualities.firstIndex(of: sleepQuality).map { $0 + 1 } ?? 2)
        if let v = Double(hrvText) { mood.hrv = v }
        mood.bodyScent = bodyScent.isEmpty ? nil : bodyScent
        mood.tags = tags
        mood.note = noteText.isEmpty ? nil : noteText

        // 照片
        if let item = selectedPhoto,
           let data = try? await item.loadTransferable(type: Data.self) {
            mood.photo = data
        }

        // 运动
        if let m = Int(workoutMinutesText), m > 0 {
            let w: WorkoutSession
            if let existing = workouts.first(where: {
                $0.source == .manual && Calendar.current.isDate($0.date, inSameDayAs: today)
            }) {
                w = existing
            } else {
                w = WorkoutSession(date: today, type: workoutType, source: .manual)
                modelContext.insert(w)
            }
            w.date = today
            w.type = workoutType
            w.durationMinutes = m
            w.recomputeOvertime()
            for i in exercises.indices { exercises[i].order = i }
            w.exercises = exercises
            w.note = workoutNote.isEmpty ? nil : workoutNote
            Task {
                if let r = try? await CloudSync.shared.syncWorkout(w) {
                    messageStore.apply(r)
                }
            }
        }

        // 习惯
        for h in todayHabits {
            let ticked = habitTicks[h.id, default: false]
            let already = h.isCompletedOn(today)
            if ticked != already {
                h.toggle(on: today)
                Task {
                    if let r = try? await CloudSync.shared.syncHabit(h) {
                        messageStore.apply(r)
                    }
                }
            }
        }

        try? modelContext.save()
        Task {
            if let r = try? await CloudSync.shared.syncMood(mood) {
                messageStore.apply(r)
            }
        }
        saving = false
        // reaction 浮层会给出反馈; 这里再补一个本地轻提示, 离线也能确认.
        let reply = localCompanionReply(for: mood)
        savedTick = reply
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if savedTick == reply { savedTick = nil }
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - 加载已有
    private func loadExisting() {
        let today = Calendar.current.startOfDay(for: Date())
        let mood = editingMood ?? (try? modelContext.fetch(FetchDescriptor<DailyMood>()))?
            .first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) })
        if let mood = mood {
            moodScore = mood.moodScore > 0 ? mood.moodScore : 5
            weather = mood.weather
            if let h = mood.sleepHours { sleepHoursText = String(format: "%.1f", h) }
            if let q = mood.sleepQuality, (1...3).contains(q) {
                sleepQuality = sleepQualities[q - 1]
            }
            if let v = mood.hrv { hrvText = String(format: "%.0f", v) }
            bodyScent = mood.bodyScent ?? ""
            tags = mood.tags
            noteText = mood.note ?? ""
            photoData = mood.photo
        }
        if let workout = workouts.first(where: { $0.source == .manual && Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            workoutType = workout.type
            if let minutes = workout.durationMinutes { workoutMinutesText = "\(minutes)" }
            exercises = workout.exercises.sorted { $0.order < $1.order }
            workoutNote = workout.note ?? ""
        }
        for h in habits { habitTicks[h.id] = h.isCompletedOn(today) }
    }

    private func toggleTag(_ tag: String) {
        if let i = tags.firstIndex(of: tag) { tags.remove(at: i) }
        else { tags.append(tag) }
    }
    private func moodLabel(_ s: Int) -> String {
        ["很糟糕","有点低","还好啦","不错","超级棒"][max(0, min(s-1, 4))]
    }
    private func localCompanionReply(for mood: DailyMood) -> String {
        if mood.moodScore <= 4 || mood.tags.contains("疲惫") {
            return "依安看到了，今晚我们慢一点。"
        }
        return "依安看到了，今晚我们慢一点。"
    }
}

// MARK: - 区块头
private struct SectionHeader: View {
    let type: DataType
    let title: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: type.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(type.main)
                .frame(width: 28, height: 28)
                .background(type.bg)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title).font(.headline)
            Spacer()
        }
    }
}

// MARK: - 动作行
struct ExerciseEntryRow: View {
    @Binding var entry: ExerciseEntry
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(entry.exerciseName).font(.gBody.bold())
                Spacer()
                Button(role: .destructive) { onDelete() } label: {
                    Image(systemName: "trash").font(.gCaption).foregroundColor(.gError.opacity(0.6))
                }
            }
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("重量(kg)").font(.system(size: 10)).foregroundColor(.gTextSecondary)
                    TextField("--", value: $entry.weightKg, format: .number)
                        .keyboardType(.decimalPad).multilineTextAlignment(.center)
                        .font(.gH3).frame(height: 36).frame(maxWidth: .infinity)
                        .background(Color.gBg).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(spacing: 4) {
                    Text("每组次数").font(.system(size: 10)).foregroundColor(.gTextSecondary)
                    TextField("--", value: $entry.reps, format: .number)
                        .keyboardType(.numberPad).multilineTextAlignment(.center)
                        .font(.gH3).frame(height: 36).frame(maxWidth: .infinity)
                        .background(Color.gBg).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(spacing: 4) {
                    Text("组数").font(.system(size: 10)).foregroundColor(.gTextSecondary)
                    HStack(spacing: 8) {
                        Button { if entry.setCount > 1 { entry.setCount -= 1 } } label: {
                            Image(systemName: "minus").font(.gCaption.bold()).foregroundColor(.dMove)
                        }
                        Text("\(entry.setCount)").font(.gH3).frame(minWidth: 20)
                        Button { entry.setCount += 1 } label: {
                            Image(systemName: "plus").font(.gCaption.bold()).foregroundColor(.dMove)
                        }
                    }
                    .frame(height: 36).frame(maxWidth: .infinity)
                    .background(Color.gBg).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(12).background(Color.gBg.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 动作选择器
struct ExercisePickerView: View {
    let onSelect: (String) -> Void
    @State private var searchText = ""
    @State private var customExercises: [String] = UserDefaults.standard.stringArray(forKey: "customExercises") ?? []
    @State private var newCustomName = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [(String, [String])] {
        var all = ExerciseLibrary.categories
        if !customExercises.isEmpty { all.append(("我的动作", customExercises)) }
        if searchText.isEmpty { return all }
        return all.compactMap { (cat, exs) in
            let m = exs.filter { $0.contains(searchText) }
            return m.isEmpty ? nil : (cat, m)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("添加自定义动作")) {
                    HStack {
                        TextField("输入动作名称", text: $newCustomName)
                        Button {
                            let n = newCustomName.trimmingCharacters(in: .whitespaces)
                            guard !n.isEmpty, !ExerciseLibrary.all.contains(n), !customExercises.contains(n) else { return }
                            customExercises.append(n)
                            UserDefaults.standard.set(customExercises, forKey: "customExercises")
                            newCustomName = ""
                        } label: {
                            Image(systemName: "plus.circle.fill").foregroundColor(.dMove)
                        }
                        .disabled(newCustomName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                ForEach(filtered, id: \.0) { category, exs in
                    Section(header: Text(category)) {
                        ForEach(exs, id: \.self) { name in
                            Button { onSelect(name) } label: { Text(name).foregroundColor(.gTextPrimary) }
                        }
                        .onDelete(perform: category == "我的动作" ? { idx in
                            customExercises.remove(atOffsets: idx)
                            UserDefaults.standard.set(customExercises, forKey: "customExercises")
                        } : nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "搜索动作")
            .navigationTitle("选择动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
    }
}

// MARK: - 添加习惯
struct AddHabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "💧"
    @State private var selectedDays: Set<Int> = [1,2,3,4,5,6,0]
    private let emojiOptions = ["💧", "🏃", "📖", "🧘", "🥗", "☕️", "🎨", "💪", "🌙", "✍️"]
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("习惯名称").font(.gH3)
                        TextField("例如：喝水、运动、冥想", text: $name)
                            .padding(12).background(Color.gBg)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选个图标").font(.gH3)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(emojiOptions, id: \.self) { e in
                                    Button { emoji = e } label: {
                                        Text(e).font(.system(size: 36)).padding(8)
                                            .background(emoji == e ? Color.dHabitBg : Color.gBg)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(RoundedRectangle(cornerRadius: 12)
                                                .stroke(emoji == e ? Color.dHabit : Color.clear, lineWidth: 2))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("每周哪几天？").font(.gH3)
                        HStack(spacing: 10) {
                            ForEach(0..<7, id: \.self) { day in
                                Button {
                                    if selectedDays.contains(day) { selectedDays.remove(day) }
                                    else { selectedDays.insert(day) }
                                } label: {
                                    Text(weekdays[day]).font(.gBody)
                                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                                        .background(selectedDays.contains(day) ? Color.dHabitBg : Color.gBg)
                                        .foregroundColor(selectedDays.contains(day) ? .dHabit : .gTextPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedDays.contains(day) ? Color.dHabit : Color.clear, lineWidth: 1.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.gBg.ignoresSafeArea())
            .navigationTitle("添加习惯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .foregroundColor(.dHabit)
                        .disabled(name.isEmpty || selectedDays.isEmpty)
                }
            }
        }
    }

    private func save() {
        let h = Habit(name: name, emoji: emoji, targetDays: Array(selectedDays).sorted())
        modelContext.insert(h)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - 流式布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let h = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }.reduce(0, +)
            + CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: proposal.width ?? 0, height: h)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rh = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for view in row {
                let s = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += rh + spacing
        }
    }
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        let maxW = proposal.width ?? 0
        for view in subviews {
            let w = view.sizeThatFits(.unspecified).width
            if x + w > maxW && !rows[rows.count - 1].isEmpty { rows.append([]); x = 0 }
            rows[rows.count - 1].append(view)
            x += w + spacing
        }
        return rows
    }
}
