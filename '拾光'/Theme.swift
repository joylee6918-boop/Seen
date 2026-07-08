import SwiftUI

// MARK: - Seen 设计系统 · 清爽健康数据 + AI 关心
// 全 app 只用这套 token, 别写裸 Color.white / .pink / .indigo.

extension Color {
    // MARK: 基础色
    /// 清爽浅灰页面背景
    static let gBg       = Color(red: 0xF3/255, green: 0xF5/255, blue: 0xF8/255)
    /// 普通卡片底
    static let gSurface  = Color.white
    /// AI/重点卡片底
    static let gCompanionSurface = Color(red: 0xF7/255, green: 0xFB/255, blue: 0xFF/255)
    /// 极浅描边 / 分割线
    static let gHairline = Color(red: 0xE4/255, green: 0xE7/255, blue: 0xF2/255)
    /// 主卡描边 (#EADFD8)
    static let gNoteBorder = Color(red: 0xDD/255, green: 0xE3/255, blue: 0xF6/255)
    /// 主文字
    static let gTextPrimary   = Color(red: 0x13/255, green: 0x1A/255, blue: 0x4A/255)
    /// 正文文字
    static let gTextBody      = Color(red: 0x58/255, green: 0x5D/255, blue: 0x80/255)
    /// 次级文字
    static let gTextSecondary = Color(red: 0x8C/255, green: 0x92/255, blue: 0xA3/255)
    /// 弱文字
    static let gTextWeak      = Color(red: 0xB9/255, green: 0xC0/255, blue: 0xCC/255)
    /// 选中底色
    static let gSelectedBg    = Color(red: 0xE8/255, green: 0xF2/255, blue: 0xFF/255)
    /// 辅助暖黄
    static let gWarmApricot   = Color(red: 0xF3/255, green: 0xBE/255, blue: 0x3F/255)
    /// 暖黄淡底
    static let gWarmApricotBg = Color(red: 0xFF/255, green: 0xF7/255, blue: 0xDA/255)

    // MARK: 数据语义色 — 每种数据类型固定一色
    // 心情 · 柔玫瑰
    static let dMoodBg   = Color(red: 0xFF/255, green: 0xEE/255, blue: 0xF2/255)
    static let dMood     = Color(red: 0xDF/255, green: 0x6D/255, blue: 0x82/255)
    // 睡眠 · 蓝
    static let dSleepBg  = Color(red: 0xEA/255, green: 0xF2/255, blue: 0xFF/255)
    static let dSleep    = Color(red: 0x4C/255, green: 0x9B/255, blue: 0xE8/255)
    // HRV / 恢复 · 靛蓝
    static let dHrvBg    = Color(red: 0xEE/255, green: 0xF1/255, blue: 0xFF/255)
    static let dHrv      = Color(red: 0x66/255, green: 0x78/255, blue: 0xD8/255)
    // 心率 · 红
    static let dHeartBg  = Color(red: 0xFF/255, green: 0xEA/255, blue: 0xEA/255)
    static let dHeart    = Color(red: 0xF5/255, green: 0x4D/255, blue: 0x58/255)
    // 血氧 · 青蓝
    static let dOxygenBg  = Color(red: 0xE8/255, green: 0xF8/255, blue: 0xFF/255)
    static let dOxygen    = Color(red: 0x43/255, green: 0xA7/255, blue: 0xE8/255)
    // 体温 · 蜜桃
    static let dTempBg    = Color(red: 0xFF/255, green: 0xEF/255, blue: 0xE7/255)
    static let dTemp      = Color(red: 0xF0/255, green: 0x8A/255, blue: 0x5B/255)
    // 摄氧量 · 紫
    static let dVo2Bg     = Color(red: 0xF0/255, green: 0xEC/255, blue: 0xFF/255)
    static let dVo2       = Color(red: 0x86/255, green: 0x65/255, blue: 0xFF/255)
    // 睡眠心率 · 粉红
    static let dSleepHeartBg = Color(red: 0xFF/255, green: 0xEE/255, blue: 0xF2/255)
    static let dSleepHeart   = Color(red: 0xD9/255, green: 0x64/255, blue: 0x7A/255)
    // 运动 · 绿
    static let dMoveBg   = Color(red: 0xE6/255, green: 0xFA/255, blue: 0xEF/255)
    static let dMove     = Color(red: 0x25/255, green: 0xD0/255, blue: 0x66/255)
    // 能量 · 珊瑚红
    static let dEnergyBg = Color(red: 0xFF/255, green: 0xEE/255, blue: 0xEA/255)
    static let dEnergy   = Color(red: 0xF0/255, green: 0x5B/255, blue: 0x50/255)
    // 习惯 · 黄
    static let dHabitBg  = Color(red: 0xFF/255, green: 0xF7/255, blue: 0xD8/255)
    static let dHabit    = gWarmApricot
    // 咖啡 · 棕金
    static let dCoffeeBg = Color(red: 0xF7/255, green: 0xEF/255, blue: 0xE7/255)
    static let dCoffee   = Color(red: 0xA8/255, green: 0x71/255, blue: 0x42/255)
    // 灵感 · 琥珀
    static let dIdeaBg   = Color(red: 0xFF/255, green: 0xF3/255, blue: 0xD8/255)
    static let dIdea     = Color(red: 0xD8/255, green: 0x9A/255, blue: 0x23/255)
    // AI 陪伴 / 同步 · 清蓝
    static let dAiBg     = gSelectedBg
    static let dAi       = dSleep
    // 分贝 / 声音 · 灰蓝
    static let dSoundBg  = Color(red: 0xEE/255, green: 0xF2/255, blue: 0xF6/255)
    static let dSound    = Color(red: 0x6B/255, green: 0x7B/255, blue: 0x8F/255)

    // MARK: 状态色
    static let gSuccess  = Color(red: 0x43/255, green: 0xB8/255, blue: 0x83/255)
    static let gWarning  = Color(red: 0xFF/255, green: 0xB0/255, blue: 0x20/255)
    static let gError    = Color(red: 0xFF/255, green: 0x4D/255, blue: 0x4F/255)

    // MARK: 兼容旧名 — 重构期间老视图引用不报错, 逐个改完删掉
    static let gRose = dMood
    static let gSage = dSleep
    static let gClay = dHrv
}

// MARK: - 数据类型 → 语义色 映射
enum DataType {
    case mood, sleep, hrv, heart, move, energy, floors, oxygen, temperature, vo2, sleepHeart, sound, habit, coffee, idea, ai, period

    var main: Color {
        switch self {
        case .mood:    return .dMood
        case .sleep:   return .dSleep
        case .hrv:     return .dHrv
        case .heart:   return .dHeart
        case .move:    return .dMove
        case .energy:  return .dEnergy
        case .floors:  return .dMove
        case .oxygen:  return .dOxygen
        case .temperature: return .dTemp
        case .vo2:     return .dVo2
        case .sleepHeart: return .dSleepHeart
        case .sound:   return .dSound
        case .habit:   return .dHabit
        case .coffee:  return .dCoffee
        case .idea:    return .dIdea
        case .ai:      return .dAi
        case .period:  return .dMood
        }
    }
    var bg: Color {
        switch self {
        case .mood:    return .dMoodBg
        case .sleep:   return .dSleepBg
        case .hrv:     return .dHrvBg
        case .heart:   return .dHeartBg
        case .move:    return .dMoveBg
        case .energy:  return .dEnergyBg
        case .floors:  return .dMoveBg
        case .oxygen:  return .dOxygenBg
        case .temperature: return .dTempBg
        case .vo2:     return .dVo2Bg
        case .sleepHeart: return .dSleepHeartBg
        case .sound:   return .dSoundBg
        case .habit:   return .dHabitBg
        case .coffee:  return .dCoffeeBg
        case .idea:    return .dIdeaBg
        case .ai:      return .dAiBg
        case .period:  return .dMoodBg
        }
    }
    /// SF Symbol 名称 (线性图标)
    var icon: String {
        switch self {
        case .mood:    return "heart"
        case .sleep:   return "moon"
        case .hrv:     return "heart.text.square"
        case .heart:   return "heart.fill"
        case .move:    return "figure.walk"
        case .energy:  return "flame"
        case .floors:  return "stairs"
        case .oxygen:  return "lungs"
        case .temperature: return "thermometer.medium"
        case .vo2:     return "waveform.path.ecg"
        case .sleepHeart: return "bed.double.fill"
        case .sound:   return "speaker.wave.2"
        case .habit:   return "checkmark.circle"
        case .coffee:  return "cup.and.saucer.fill"
        case .idea:    return "lightbulb"
        case .ai:      return "sparkles"
        case .period:  return "drop.fill"
        }
    }
    var label: String {
        switch self {
        case .mood:    return "心情"
        case .sleep:   return "睡眠"
        case .hrv:     return "HRV"
        case .heart:   return "心率"
        case .move:    return "运动"
        case .energy:  return "活动"
        case .floors:  return "楼层"
        case .oxygen:  return "血氧"
        case .temperature: return "体温"
        case .vo2:     return "摄氧量"
        case .sleepHeart: return "睡眠心率"
        case .sound:   return "分贝"
        case .habit:   return "习惯"
        case .coffee:  return "咖啡"
        case .idea:    return "灵感"
        case .ai:      return "AI"
        case .period:  return "经期"
        }
    }
}

// MARK: - 字号 token
extension Font {
    static let gH1     = Font.system(size: 28, weight: .semibold)
    static let gH2     = Font.system(size: 20, weight: .semibold)
    static let gH3     = Font.system(size: 16, weight: .medium)
    static let gBody   = Font.system(size: 14, weight: .regular)
    static let gCaption = Font.system(size: 12, weight: .regular)
    static let gNumber = Font.system(size: 24, weight: .semibold)
}

// MARK: - 统一卡片
// 白底 + 极浅描边 + 极轻阴影. 圆角 18, padding 默认 16.
struct GleanCard: ViewModifier {
    var cornerRadius: CGFloat = 18
    var padding: CGFloat? = 16

    func body(content: Content) -> some View {
        content
            .padding(padding ?? 0)
            .background(Color.gSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.gHairline, lineWidth: 1)
            )
            .shadow(color: Color.gTextPrimary.opacity(0.08), radius: 16, x: 0, y: 7)
    }
}

extension View {
    func gleanCard(cornerRadius: CGFloat = 18, padding: CGFloat? = 16) -> some View {
        modifier(GleanCard(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - 主按钮 / 次按钮
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.gH3)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.dAi)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.gH3)
            .foregroundColor(.gTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.gSurface)
            .overlay(Capsule().stroke(Color.gHairline, lineWidth: 1))
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

// MARK: - 状态标签 pill
struct StatusPill: View {
    let text: String
    let kind: Kind

    enum Kind {
        case success, warning, error, neutral, ai
        var color: Color {
            switch self {
            case .success: return .gSuccess
            case .warning: return .gWarning
            case .error:   return .gError
            case .neutral: return .gTextSecondary
            case .ai:      return .dAi
            }
        }
        var bg: Color {
            switch self {
            case .success: return .gSuccess.opacity(0.10)
            case .warning: return .gWarning.opacity(0.12)
            case .error:   return .gError.opacity(0.10)
            case .neutral: return .gHairline.opacity(0.50)
            case .ai:      return .dAiBg
            }
        }
    }

    var body: some View {
        Text(text)
            .font(.gCaption)
            .foregroundColor(kind.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(kind.bg)
            .clipShape(Capsule())
    }
}

// MARK: - 数据 icon 小底 (浅色圆角底 + 线性图标)
struct DataIcon: View {
    let type: DataType
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: type.icon)
            .font(.system(size: size * 0.45, weight: .regular))
            .foregroundColor(type.main)
            .frame(width: size, height: size)
            .background(type.bg)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}
