import Foundation
import HealthKit
import Combine
import SwiftData

@MainActor
class HealthManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined

    private let typesToRead: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
        HKObjectType.quantityType(forIdentifier: .appleStandTime)!,
        HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
        HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
        HKObjectType.quantityType(forIdentifier: .vo2Max)!,
        HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage)!,
        HKObjectType.categoryType(forIdentifier: .mindfulSession)!,
        HKObjectType.categoryType(forIdentifier: .menstrualFlow)!,
        HKObjectType.workoutType(),
    ]

    func requestAuthorization() async throws {
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        authorizationStatus = .sharingAuthorized
    }

    // MARK: - 第一档 · 首页状态卡片直接展示

    func fetchTodayHRV() async throws -> Double? {
        guard let t = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        let (start, end) = todayRange()
        let p = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .discreteAverage) { _, r, e in
                if let e = e { cont.resume(throwing: e); return }
                cont.resume(returning: r?.averageQuantity()?.doubleValue(for: HKUnit.secondUnit(with: .milli)))
            }
            self.healthStore.execute(q)
        }
    }

    /// 拉最近一夜睡眠总时长 (小时). 直接取 Apple Watch 记录的完整 sleep session, 不卡固定窗口 —
    /// AW 记了多长就是多长. 只过滤 Watch 来源, 取最近一个跨越午夜的 asleep 区段合并.
    func fetchLastNightSleep() async throws -> Double? {
        guard let t = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let cal = Calendar.current
        let now = Date()
        // 往前看 24 小时, 覆盖昨晚 + 凌晨醒来到现在
        let lookback = cal.date(byAdding: .hour, value: -24, to: now)!
        let p = HKQuery.predicateForSamples(withStart: lookback, end: now, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: t, predicate: p, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, e in
                if let e = e { cont.resume(throwing: e); return }
                guard let s = samples as? [HKCategorySample], !s.isEmpty else { cont.resume(returning: nil); return }
                // 睡眠只信 Apple Watch. 如果昨晚没戴表, 不回退到手机/第三方/手填样本,
                // 否则会把不可靠的睡眠时长同步给 Claude.
                let watch = s.filter { $0.sourceRevision.source.bundleIdentifier.contains("watch") }
                guard !watch.isEmpty else { cont.resume(returning: nil); return }
                let toUse = watch
                // 取 asleep 样本 (有细分用细分, 没有回退 unspecified)
                let detailed: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                ]
                let detailedSamples = toUse.filter { detailed.contains($0.value) }
                let asleep: [HKCategorySample]
                if detailedSamples.isEmpty {
                    asleep = toUse.filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue }
                } else {
                    asleep = detailedSamples
                }
                guard !asleep.isEmpty else { cont.resume(returning: nil); return }
                // 找最近一个睡眠段: 取最晚的 asleep 起点往前, 把所有与它时间相连 (gap < 1h) 的段并成一个连续 session
                let sorted = asleep.sorted { $0.startDate < $1.startDate }
                let lastStart = sorted.last!.startDate
                // 往前聚合所有 gap < 60min 的段 (一次起夜/短暂清醒不切断)
                var session: [(start: Date, end: Date)] = []
                for sample in sorted {
                    if let prev = session.last, sample.startDate.timeIntervalSince(prev.end) < 3600 {
                        session[session.count - 1].end = max(prev.end, sample.endDate)
                    } else {
                        session.append((sample.startDate, sample.endDate))
                    }
                }
                // 取包含 lastStart 的那个 session (最近一夜)
                guard let lastNight = session.last(where: { $0.start <= lastStart && $0.end >= lastStart }) ?? session.last else {
                    cont.resume(returning: nil); return
                }
                // 时长 = 落在这一夜区间内的 asleep 样本时长求和, 不含中间的清醒段.
                // (session.start/end 只是 asleep 样本的包围盒, 中间 <1h 的 awake 段不该算进睡眠.)
                let nightAsleep = asleep.filter { $0.startDate >= lastNight.start && $0.endDate <= lastNight.end }
                let totalSec = nightAsleep.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                let hours = totalSec / 3600.0
                cont.resume(returning: hours > 0 ? hours : nil)
            }
            self.healthStore.execute(q)
        }
    }

    /// 睡眠阶段细分 — 返回 (deep, core, rem, awake) 小时, 取最近一夜
    func fetchLastNightSleepStages() async throws -> (deep: Double, core: Double, rem: Double, awake: Double)? {
        guard let t = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let cal = Calendar.current
        let now = Date()
        let lookback = cal.date(byAdding: .hour, value: -24, to: now)!
        let p = HKQuery.predicateForSamples(withStart: lookback, end: now, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: t, predicate: p, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, e in
                if let e = e { cont.resume(throwing: e); return }
                guard let s = samples as? [HKCategorySample], !s.isEmpty else { cont.resume(returning: nil); return }
                let watch = s.filter { $0.sourceRevision.source.bundleIdentifier.contains("watch") }
                guard !watch.isEmpty else { cont.resume(returning: nil); return }
                let toUse = watch
                // 找最近一夜的 asleep 范围 (跟 fetchLastNightSleep 同逻辑)
                let asleepAll = toUse.filter { $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                    || $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                    || $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    || $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue }
                guard !asleepAll.isEmpty else { cont.resume(returning: nil); return }
                let sortedAsleep = asleepAll.sorted { $0.startDate < $1.startDate }
                let lastStart = sortedAsleep.last!.startDate
                var sess: [(Date, Date)] = []
                for sm in sortedAsleep {
                    if let p = sess.last, sm.startDate.timeIntervalSince(p.1) < 3600 {
                        sess[sess.count - 1] = (p.0, max(p.1, sm.endDate))
                    } else { sess.append((sm.startDate, sm.endDate)) }
                }
                guard let night = sess.last(where: { $0.0 <= lastStart && $0.1 >= lastStart }) ?? sess.last else {
                    cont.resume(returning: nil); return
                }
                // 只统计落在这一夜范围内的样本
                let inNight = toUse.filter { $0.startDate >= night.0 && $0.endDate <= night.1 }
                func hours(_ v: HKCategoryValueSleepAnalysis) -> Double {
                    inNight.filter { $0.value == v.rawValue }
                        .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 3600.0
                }
                cont.resume(returning: (deep: hours(.asleepDeep), core: hours(.asleepCore), rem: hours(.asleepREM), awake: hours(.awake)))
            }
            self.healthStore.execute(q)
        }
    }

    /// 最近一夜睡眠 + 评分明细. 评分按阿芸定的 Seen 公式:
    /// 时长(50) + 作息规律(30) + 中断(20) + HRV 恢复参考(0..+8), 封顶 100.
    /// 三块基线跟 Apple 结构一致 (AW 自己没暴露 score, HealthKit 只有 stages), 恢复参考是 Seen 自己加的.
    struct SleepNight {
        let start: Date
        let end: Date
        let deepHours: Double
        let coreHours: Double
        let remHours: Double
        let awakeHours: Double
        var asleepHours: Double { deepHours + coreHours + remHours }
    }

    struct SleepScoreBreakdown {
        let total: Int
        let duration: Int        // 满分 50
        let consistency: Int     // 满分 30
        let interruptions: Int   // 满分 20
        let recoveryBonus: Int   // 0..+8 (HRV 折算)
        let recoveryHRV: Double? // 供显示的原始 HRV
    }

    /// 拉最近 N 晚的睡眠详情 (每晚一个 SleepNight). 用做作息规律度.
    func fetchRecentNights(_ count: Int = 14) async -> [SleepNight] {
        guard let t = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .day, value: -count, to: end)!
        let p = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: t, predicate: p, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
                guard let s = samples as? [HKCategorySample], !s.isEmpty else { cont.resume(returning: []); return }
                let watch = s.filter { $0.sourceRevision.source.bundleIdentifier.contains("watch") }
                guard !watch.isEmpty else { cont.resume(returning: []); return }
                let toUse = watch
                let detailed: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                ]
                let detailedSamples = toUse.filter { detailed.contains($0.value) }
                let asleep: [HKCategorySample] = detailedSamples.isEmpty
                    ? toUse.filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue }
                    : detailedSamples
                let sorted = asleep.sorted { $0.startDate < $1.startDate }
                // 用 gap<1h 聚合成连续 session (一次起夜不切断)
                var sessions: [(start: Date, end: Date)] = []
                for sm in sorted {
                    if let last = sessions.last, sm.startDate.timeIntervalSince(last.end) < 3600 {
                        sessions[sessions.count - 1].end = max(last.end, sm.endDate)
                    } else {
                        sessions.append((sm.startDate, sm.endDate))
                    }
                }
                let nights: [SleepNight] = sessions.map { sess in
                    func hours(_ v: HKCategoryValueSleepAnalysis) -> Double {
                        toUse.filter { $0.value == v.rawValue && $0.startDate >= sess.start && $0.endDate <= sess.end }
                            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 3600.0
                    }
                    return SleepNight(start: sess.start, end: sess.end,
                                      deepHours: hours(.asleepDeep),
                                      coreHours: hours(.asleepCore),
                                      remHours: hours(.asleepREM),
                                      awakeHours: hours(.awake))
                }
                cont.resume(returning: nights)
            }
            self.healthStore.execute(q)
        }
    }

    func fetchSleepScoreBreakdown() async -> SleepScoreBreakdown? {
        let nights = await fetchRecentNights(14)
        guard let last = nights.last, last.asleepHours > 0 else { return nil }

        // 1) 时长分 (50) — 分段线性, 贴 Apple 的曲线
        let h = last.asleepHours
        let dur: Double
        switch h {
        case 7...:        dur = 50
        case 6..<7:       dur = 38 + 12 * (h - 6)
        case 5..<6:       dur = 22 + 16 * (h - 5)
        case 3..<5:       dur = 8 + 14 * ((h - 3) / 2)
        default:          dur = 8 * max(0, h / 3)
        }

        // 2) 作息规律分 (30) — 最近多晚就寝时间的规律度 + 今晚离典型就寝的偏离
        let cons: Double
        if nights.count < 3 {
            cons = 15  // 历史不够, 给中性的部分分
        } else {
            let cal = Calendar.current
            let bedtimes = nights.map { night -> Double in
                let c = cal.dateComponents([.hour, .minute], from: night.start)
                return Double((c.hour ?? 0) * 60 + (c.minute ?? 0))
            }
            // 圆周统计 (就寝时间跨午夜, 线性均值会错)
            var sumSin = 0.0, sumCos = 0.0
            for b in bedtimes {
                let r = b / 60.0 * .pi / 12
                sumSin += sin(r); sumCos += cos(r)
            }
            let meanRad = atan2(sumSin, sumCos)
            var meanMin = meanRad * 12 / .pi * 60
            meanMin = meanMin.truncatingRemainder(dividingBy: 1440)
            func circDist(_ a: Double, _ b: Double) -> Double {
                var d = abs(a - b).truncatingRemainder(dividingBy: 1440)
                if d > 720 { d = 1440 - d }
                return d
            }
            let devs = bedtimes.map { circDist($0, meanMin) }
            let meanDev = devs.reduce(0, +) / Double(devs.count)
            let regularity = max(0, 1 - meanDev / 90)          // 平均偏离 >90min 规律性归零
            let tonightDev = circDist(bedtimes.last!, meanMin)
            let tonightClose = max(0, 1 - tonightDev / 90)
            cons = 30 * (0.6 * regularity + 0.4 * tonightClose)
        }

        // 3) 中断分 (20) — 床上清醒占比越低越高
        let bedTotal = last.asleepHours + last.awakeHours
        let awakeRatio = bedTotal > 0 ? last.awakeHours / bedTotal : 0
        let inter = 20.0 * max(0, 1 - awakeRatio / 0.25)       // 清醒占 25%+ 归零

        // 4) 恢复参考 (+0..8) — HRV 折算, 只回血不倒扣
        let hrv = try? await fetchTodayHRV()
        let recBonus: Double
        switch hrv ?? 0 {
        case 60...: recBonus = 8
        case 45...: recBonus = 5
        case 30...: recBonus = 2
        default:    recBonus = 0
        }

        let base = dur + cons + inter + recBonus
        let total = max(0, min(100, Int(base.rounded())))
        return SleepScoreBreakdown(
            total: total,
            duration: Int(dur.rounded()),
            consistency: Int(cons.rounded()),
            interruptions: Int(inter.rounded()),
            recoveryBonus: Int(recBonus.rounded()),
            recoveryHRV: hrv
        )
    }

    func fetchTodaySteps() async throws -> Double? {
        guard let t = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        let (start, end) = todayRange()
        let p = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .cumulativeSum) { _, r, e in
                if let e = e { cont.resume(throwing: e); return }
                cont.resume(returning: r?.sumQuantity()?.doubleValue(for: HKUnit.count()))
            }
            self.healthStore.execute(q)
        }
    }

    func fetchTodayRestingHeartRate() async throws -> Double? {
        guard let t = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) ?? HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        let (start, end) = todayRange()
        let p = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .discreteAverage) { _, r, e in
                if let e = e { cont.resume(throwing: e); return }
                cont.resume(returning: r?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min")))
            }
            self.healthStore.execute(q)
        }
    }

    func fetchLatestHeartRate() async throws -> Double? {
        guard let t = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
        let p = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return try await fetchLatestQuantity(t, predicate: p, unit: HKUnit(from: "count/min"))
    }

    func fetchTodayActiveEnergy() async throws -> Double? {
        guard let t = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return nil }
        let (start, end) = todayRange()
        let p = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .cumulativeSum) { _, r, e in
                if let e = e { cont.resume(throwing: e); return }
                cont.resume(returning: r?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()))
            }
            self.healthStore.execute(q)
        }
    }

    func fetchTodayExerciseMinutes() async throws -> Double? {
        guard let t = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else { return nil }
        let (start, end) = todayRange()
        let p = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .cumulativeSum) { _, r, e in
                if let e = e { cont.resume(throwing: e); return }
                cont.resume(returning: r?.sumQuantity()?.doubleValue(for: .minute()))
            }
            self.healthStore.execute(q)
        }
    }

    // MARK: - 第二档 · 趋势页可看

    func fetchTodayStandTime() async throws -> Double? {
        guard let t = HKQuantityType.quantityType(forIdentifier: .appleStandTime) else { return nil }
        let (start, end) = todayRange()
        let p = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .cumulativeSum) { _, r, e in
                if let e = e { cont.resume(throwing: e); return }
                cont.resume(returning: r?.sumQuantity()?.doubleValue(for: .hour()))
            }
            self.healthStore.execute(q)
        }
    }

    func fetchTodayFlightsClimbed() async throws -> Double? {
        guard let t = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) else { return nil }
        let (start, end) = todayRange()
        let p = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .cumulativeSum) { _, r, e in
                if let e = e { cont.resume(throwing: e); return }
                cont.resume(returning: r?.sumQuantity()?.doubleValue(for: HKUnit.count()))
            }
            self.healthStore.execute(q)
        }
    }

    func fetchTodayBloodOxygen() async throws -> Double? {
        guard let t = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else { return nil }
        let (start, end) = todayRange()
        let p = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .discreteAverage) { _, r, e in
                if let e = e { cont.resume(throwing: e); return }
                cont.resume(returning: r?.averageQuantity()?.doubleValue(for: HKUnit.percent()))
            }
            self.healthStore.execute(q)
        }
    }

    func fetchLatestVO2Max() async throws -> Double? {
        guard let t = HKQuantityType.quantityType(forIdentifier: .vo2Max) else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -365, to: Date())!
        let p = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return try await fetchLatestQuantity(t, predicate: p, unit: HKUnit(from: "mL/kg*min"))
    }

    func fetchLatestWristTemperature() async throws -> Double? {
        guard let t = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let p = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return try await fetchLatestQuantity(t, predicate: p, unit: .degreeCelsius())
    }

    func fetchLastNightSleepHeartRate() async throws -> Double? {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
              let heartType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        let cal = Calendar.current
        let now = Date()
        let lookback = cal.date(byAdding: .hour, value: -24, to: now)!
        let p = HKQuery.predicateForSamples(withStart: lookback, end: now, options: .strictStartDate)
        let sleepWindow: (Date, Date)? = try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: sleepType, predicate: p, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, e in
                if let e = e { cont.resume(throwing: e); return }
                guard let s = samples as? [HKCategorySample], !s.isEmpty else { cont.resume(returning: nil); return }
                let watch = s.filter { $0.sourceRevision.source.bundleIdentifier.contains("watch") }
                guard !watch.isEmpty else { cont.resume(returning: nil); return }
                let asleep = watch.filter { $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                    || $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                    || $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    || $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue }
                guard !asleep.isEmpty else { cont.resume(returning: nil); return }
                var sessions: [(Date, Date)] = []
                for sm in asleep.sorted(by: { $0.startDate < $1.startDate }) {
                    if let last = sessions.last, sm.startDate.timeIntervalSince(last.1) < 3600 {
                        sessions[sessions.count - 1] = (last.0, max(last.1, sm.endDate))
                    } else {
                        sessions.append((sm.startDate, sm.endDate))
                    }
                }
                cont.resume(returning: sessions.last)
            }
            self.healthStore.execute(q)
        }
        guard let sleepWindow else { return nil }
        let heartPredicate = HKQuery.predicateForSamples(withStart: sleepWindow.0, end: sleepWindow.1, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(quantityType: heartType, quantitySamplePredicate: heartPredicate, options: .discreteAverage) { _, r, e in
                if let e = e { cont.resume(throwing: e); return }
                cont.resume(returning: r?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min")))
            }
            self.healthStore.execute(q)
        }
    }

    func fetchTodayMindfulMinutes() async throws -> Double? {
        guard let t = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else { return nil }
        let (start, end) = todayRange()
        let p = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: t, predicate: p, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, e in
                if let e = e { cont.resume(throwing: e); return }
                guard let s = samples else { cont.resume(returning: nil); return }
                let total = s.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                cont.resume(returning: total / 60.0)  // 分钟
            }
            self.healthStore.execute(q)
        }
    }

    /// 今日环境音量暴露 (分贝, A 加权 SPL). Apple Watch 周期性采样.
    func fetchTodayAudioExposure() async throws -> Double? {
        guard let t = HKQuantityType.quantityType(forIdentifier: .environmentalAudioExposure) else { return nil }
        let (start, end) = todayRange()
        let p = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .discreteAverage) { _, r, e in
                if let e = e { cont.resume(throwing: e); return }
                cont.resume(returning: r?.averageQuantity()?.doubleValue(for: HKUnit.decibelAWeightedSoundPressureLevel()))
            }
            self.healthStore.execute(q)
        }
    }

    private func fetchLatestQuantity(_ type: HKQuantityType, predicate: NSPredicate, unit: HKUnit) async throws -> Double? {
        try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, e in
                if let e = e { cont.resume(throwing: e); return }
                let sample = (samples as? [HKQuantitySample])?.first
                cont.resume(returning: sample?.quantity.doubleValue(for: unit))
            }
            self.healthStore.execute(q)
        }
    }

    // MARK: - 经期

    /// 最近一次经期开始日, nil 表示 HealthKit 无数据
    /// 最近一次真实经期开始日 (只取实际来潮样本, 排除预测).
    /// Apple Health 的预测样本 value 是 .unspecified, 真实来潮用户/AW 会标 .light/.medium/.heavy.
    func fetchLastPeriodStart() async throws -> Date? {
        guard let t = HKCategoryType.categoryType(forIdentifier: .menstrualFlow) else { return nil }
        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .day, value: -90, to: end)!
        let p = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: t, predicate: p, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, e in
                if let e = e { cont.resume(throwing: e); return }
                guard let s = samples as? [HKCategorySample], !s.isEmpty else { cont.resume(returning: nil); return }
                // 只取真实来潮样本 — 排除 .unspecified (那是预测) 和 .none (结束标记)
                let actual = s.filter { sample in
                    let v = sample.value
                    return v != HKCategoryValueMenstrualFlow.unspecified.rawValue
                        && v != HKCategoryValueMenstrualFlow.none.rawValue
                }
                guard !actual.isEmpty else { cont.resume(returning: nil); return }
                // 找最近一次经期的起点: 取最晚的样本, 往前聚合相邻/相邻+1天的样本为一个经期
                let sorted = actual.sorted { $0.startDate < $1.startDate }
                let lastStart = sorted.last!.startDate
                var periodStart = lastStart
                for sample in sorted.reversed() {
                    if cal.isDate(sample.startDate, inSameDayAs: periodStart) ||
                       cal.isDate(sample.startDate, inSameDayAs: cal.date(byAdding: .day, value: -1, to: periodStart)!) {
                        periodStart = sample.startDate
                    } else {
                        break
                    }
                }
                cont.resume(returning: cal.startOfDay(for: periodStart))
            }
            self.healthStore.execute(q)
        }
    }

    // MARK: - Workout 自动同步进 SwiftData

    /// 拉最近 N 天的 Workout, 写进 modelContext (去重: 同 HK UUID 不重写)
    func syncWorkouts(into context: ModelContext, days: Int = 7) async throws {
        let workoutType = HKObjectType.workoutType()
        _ = try await healthStore.requestAuthorization(toShare: [], read: [workoutType])

        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .day, value: -days, to: end)!
        let p = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: workoutType, predicate: p, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: nil) { _, samples, e in
                if let e = e { cont.resume(throwing: e); return }
                cont.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            self.healthStore.execute(q)
        }

        let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let existingExternalIds = Set(existing.compactMap(\.externalId))

        for w in workouts {
            let day = Calendar.current.startOfDay(for: w.startDate)
            let hkId = w.uuid.uuidString
            if existingExternalIds.contains(hkId) { continue }

            // 旧数据没有 externalId，用日期/类型/时长做一次兼容去重。
            let sameWorkout = existing.contains { $0.source == .healthkit &&
                Calendar.current.isDate($0.date, inSameDayAs: day) &&
                $0.typeRaw == WorkoutSession.WorkoutType.fromHealthKit(w.workoutActivityType.rawValue).rawValue &&
                $0.durationMinutes == Int(w.duration / 60)
            }
            if sameWorkout { continue }

            let session = WorkoutSession(date: w.startDate,
                                         type: WorkoutSession.WorkoutType.fromHealthKit(w.workoutActivityType.rawValue),
                                         source: .healthkit)
            session.externalId = hkId
            session.durationMinutes = Int(w.duration / 60)
            session.recomputeOvertime()
            session.activeEnergyKcal = w.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie())
            session.averageHeartRate = nil  // 需要额外 query, 先空着
            context.insert(session)
        }
        try context.save()
    }

    // MARK: - Helpers

    private func todayRange() -> (Date, Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = Date()
        return (start, end)
    }
}
